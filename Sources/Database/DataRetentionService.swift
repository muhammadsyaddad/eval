import Foundation

// MARK: - Retention Policy

/// Configurable data retention policy.
/// Raw captures (screenshots + OCR) can have a different retention period than processed summaries.
struct RetentionPolicy {
    /// Number of days to keep raw captures (screenshots + OCR text). Default: 30 days.
    var captureRetentionDays: Int = 30

    /// Number of days to keep activity entries. Default: 90 days.
    var activityRetentionDays: Int = 90

    /// Number of days to keep daily summaries and app usage. Default: 365 days.
    var summaryRetentionDays: Int = 365

    /// Maximum total storage in bytes (database + captures on disk). 0 = unlimited.
    var storageLimitBytes: UInt64 = 5 * 1024 * 1024 * 1024 // 5 GB default
}

// MARK: - Data Retention Service Protocol

protocol DataRetentionServiceProtocol {
    /// Apply the retention policy: delete data older than the configured thresholds.
    /// Returns a summary of how many rows were deleted per table.
    func applyRetention() throws -> RetentionResult

    /// Enforce the storage limit by deleting oldest data until under the limit.
    /// Returns how many bytes were freed.
    func enforceStorageLimit() throws -> UInt64

    /// Calculate total storage used (database + capture files on disk).
    func totalStorageBytes() -> UInt64

    /// The current retention policy.
    var policy: RetentionPolicy { get set }
}

/// Summary of a retention pass.
struct RetentionResult {
    let capturesDeleted: Int
    let activityEntriesDeleted: Int
    let dailySummariesDeleted: Int
    let appUsageDeleted: Int
    let captureFilesDeleted: Int

    var totalDeleted: Int {
        capturesDeleted + activityEntriesDeleted + dailySummariesDeleted + appUsageDeleted
    }
}

// MARK: - Data Retention Service

final class DataRetentionService: DataRetentionServiceProtocol {

    private let dataStore: DataStoreProtocol
    private let captureStorage: CaptureStorageServiceProtocol
    private let databaseManager: DatabaseManager

    var policy: RetentionPolicy

    init(
        dataStore: DataStoreProtocol,
        captureStorage: CaptureStorageServiceProtocol,
        databaseManager: DatabaseManager,
        policy: RetentionPolicy = RetentionPolicy()
    ) {
        self.dataStore = dataStore
        self.captureStorage = captureStorage
        self.databaseManager = databaseManager
        self.policy = policy
    }

    func applyRetention() throws -> RetentionResult {
        let now = Date()
        let calendar = Calendar.current

        // Calculate cutoff dates
        let captureCutoff = calendar.date(byAdding: .day, value: -policy.captureRetentionDays, to: now)!
        let activityCutoff = calendar.date(byAdding: .day, value: -policy.activityRetentionDays, to: now)!
        let summaryCutoff = calendar.date(byAdding: .day, value: -policy.summaryRetentionDays, to: now)!

        // Delete old database records
        let capturesDeleted = try dataStore.deleteCaptures(olderThan: captureCutoff)
        let activitiesDeleted = try dataStore.deleteActivityEntries(olderThan: activityCutoff)
        let summariesDeleted = try dataStore.deleteDailySummaries(olderThan: summaryCutoff)
        let appUsageDeleted = try dataStore.deleteAppUsage(olderThan: summaryCutoff)

        // Delete old capture files from disk
        var filesDeleted = 0
        do {
            try captureStorage.deleteCaptures(olderThan: captureCutoff)
            filesDeleted = capturesDeleted // approximate — matches DB deletes
        } catch {
            // File deletion failure is non-fatal
        }

        return RetentionResult(
            capturesDeleted: capturesDeleted,
            activityEntriesDeleted: activitiesDeleted,
            dailySummariesDeleted: summariesDeleted,
            appUsageDeleted: appUsageDeleted,
            captureFilesDeleted: filesDeleted
        )
    }

    func enforceStorageLimit() throws -> UInt64 {
        guard policy.storageLimitBytes > 0 else { return 0 }

        let currentSize = totalStorageBytes()
        guard currentSize > policy.storageLimitBytes else { return 0 }

        var freedBytes: UInt64 = 0
        let targetSize = policy.storageLimitBytes
        let calendar = Calendar.current

        // Progressively delete oldest data in 7-day increments until under limit
        var daysBack = max(policy.captureRetentionDays, policy.summaryRetentionDays)

        while totalStorageBytes() > targetSize && daysBack > 7 {
            daysBack -= 7
            let cutoff = calendar.date(byAdding: .day, value: -daysBack, to: Date())!

            try dataStore.deleteCaptures(olderThan: cutoff)
            try captureStorage.deleteCaptures(olderThan: cutoff)

            let newSize = totalStorageBytes()
            freedBytes = currentSize - newSize
        }

        // If still over limit, delete activity entries and summaries too
        if totalStorageBytes() > targetSize {
            daysBack = max(policy.activityRetentionDays, policy.summaryRetentionDays)
            while totalStorageBytes() > targetSize && daysBack > 7 {
                daysBack -= 7
                let cutoff = calendar.date(byAdding: .day, value: -daysBack, to: Date())!

                try dataStore.deleteActivityEntries(olderThan: cutoff)
                try dataStore.deleteDailySummaries(olderThan: cutoff)
                try dataStore.deleteAppUsage(olderThan: cutoff)
            }
            let newSize = totalStorageBytes()
            freedBytes = currentSize - newSize
        }

        return freedBytes
    }

    func totalStorageBytes() -> UInt64 {
        let dbSize = databaseManager.databaseSizeBytes()
        let captureSize = captureStorage.totalStorageBytes()
        return dbSize + captureSize
    }
}
