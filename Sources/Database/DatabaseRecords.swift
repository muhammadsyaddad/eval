import Foundation
import GRDB

// MARK: - Capture Record

/// GRDB record type for the `captures` table.
/// Maps between the database row and the app's capture models.
///
/// PRIVACY AUDIT: This record contains the most sensitive fields:
/// - `windowTitle`: May reveal document names, email subjects, URLs (Medium sensitivity)
/// - `browserURL`: Reveals browsing history (High sensitivity)
/// - `imagePath`: Points to screenshot PNG on disk (High sensitivity)
/// - `ocrText`: Contains whatever text was visible on screen (High sensitivity)
/// All fields are stored locally and subject to user-configured retention policies.
struct CaptureRecord: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "captures"

    let id: String                    // UUID string
    let timestamp: Date
    let appName: String
    let bundleIdentifier: String
    let windowTitle: String
    let browserURL: String?
    let imagePath: String
    let ocrText: String?
    let ocrConfidence: Double?

    // MARK: - Conversion from CaptureResult

    /// Create a record from a CaptureResult + relative image path.
    init(from capture: CaptureResult, imagePath: String) {
        self.id = capture.id.uuidString
        self.timestamp = capture.timestamp
        self.appName = capture.metadata.appName
        self.bundleIdentifier = capture.metadata.bundleIdentifier
        self.windowTitle = capture.metadata.windowTitle
        self.browserURL = capture.metadata.browserURL
        self.imagePath = imagePath
        self.ocrText = capture.ocrResult?.fullText
        self.ocrConfidence = capture.ocrResult.map { Double($0.averageConfidence) }
    }

    /// Create a record from a StoredCapture.
    init(from stored: StoredCapture) {
        self.id = stored.id.uuidString
        self.timestamp = stored.timestamp
        self.appName = stored.metadata.appName
        self.bundleIdentifier = stored.metadata.bundleIdentifier
        self.windowTitle = stored.metadata.windowTitle
        self.browserURL = stored.metadata.browserURL
        self.imagePath = stored.imagePath
        self.ocrText = stored.ocrText
        self.ocrConfidence = stored.ocrConfidence.map { Double($0) }
    }

    /// Direct initializer for testing / manual construction.
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        appName: String,
        bundleIdentifier: String,
        windowTitle: String,
        browserURL: String? = nil,
        imagePath: String,
        ocrText: String? = nil,
        ocrConfidence: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.browserURL = browserURL
        self.imagePath = imagePath
        self.ocrText = ocrText
        self.ocrConfidence = ocrConfidence
    }

    // MARK: - Conversion to StoredCapture

    func toStoredCapture() -> StoredCapture {
        StoredCapture(
            id: UUID(uuidString: id) ?? UUID(),
            timestamp: timestamp,
            metadata: WindowMetadata(
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                windowTitle: windowTitle,
                browserURL: browserURL
            ),
            imagePath: imagePath,
            ocrText: ocrText,
            ocrConfidence: ocrConfidence.map { Float($0) }
        )
    }
}

// MARK: - Activity Entry Record

/// GRDB record type for the `activity_entries` table.
///
/// PRIVACY AUDIT: Contains AI-generated summaries that may describe user activity
/// in natural language. The `title` and `summary` fields are derived from window
/// titles and OCR text (Medium sensitivity). Subject to 90-day default retention.
struct ActivityEntryRecord: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "activity_entries"

    let id: String                    // UUID string
    let timestamp: Date
    let appName: String
    let appIcon: String
    let title: String
    let summary: String
    let category: String              // ActivityCategory.rawValue
    let duration: Double              // seconds

    // MARK: - Conversion from ActivityEntry

    init(from entry: ActivityEntry) {
        self.id = entry.id.uuidString
        self.timestamp = entry.timestamp
        self.appName = entry.appName
        self.appIcon = entry.appIcon
        self.title = entry.title
        self.summary = entry.summary
        self.category = entry.category.rawValue
        self.duration = entry.duration
    }

    /// Direct initializer.
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        appName: String,
        appIcon: String,
        title: String,
        summary: String,
        category: String,
        duration: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.appIcon = appIcon
        self.title = title
        self.summary = summary
        self.category = category
        self.duration = duration
    }

    // MARK: - Conversion to ActivityEntry

    func toActivityEntry() -> ActivityEntry {
        ActivityEntry(
            id: UUID(uuidString: id) ?? UUID(),
            timestamp: timestamp,
            appName: appName,
            appIcon: appIcon,
            title: title,
            summary: summary,
            category: ActivityCategory(rawValue: category) ?? .other,
            duration: duration
        )
    }
}

// MARK: - Daily Summary Record

/// GRDB record type for the `daily_summaries` table.
///
/// PRIVACY AUDIT: The `aiSummary` field contains a natural language description
/// of the user's day that may reference specific activities (Medium sensitivity).
/// Other fields are aggregate metrics (Low sensitivity). Subject to 365-day default retention.
struct DailySummaryRecord: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "daily_summaries"

    let id: String                    // UUID string
    let date: Date                    // Start-of-day date
    let totalScreenTime: Double       // seconds
    let aiSummary: String
    let activityCount: Int
    let productivityScore: Double     // 0.0 – 1.0

    // MARK: - Conversion from DaySummary

    init(from summary: DaySummary) {
        self.id = summary.id.uuidString
        self.date = Calendar.current.startOfDay(for: summary.date)
        self.totalScreenTime = summary.totalScreenTime
        self.aiSummary = summary.aiSummary
        self.activityCount = summary.activityCount
        self.productivityScore = summary.productivityScore
    }

    /// Direct initializer.
    init(
        id: String = UUID().uuidString,
        date: Date,
        totalScreenTime: Double,
        aiSummary: String,
        activityCount: Int,
        productivityScore: Double
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.totalScreenTime = totalScreenTime
        self.aiSummary = aiSummary
        self.activityCount = activityCount
        self.productivityScore = productivityScore
    }

    // MARK: - Conversion to DaySummary (requires top apps loaded separately)

    func toDaySummary(topApps: [AppUsage]) -> DaySummary {
        DaySummary(
            id: UUID(uuidString: id) ?? UUID(),
            date: date,
            totalScreenTime: totalScreenTime,
            topApps: topApps,
            aiSummary: aiSummary,
            activityCount: activityCount,
            productivityScore: productivityScore
        )
    }
}

// MARK: - App Usage Record

/// GRDB record type for the `app_usage` table.
///
/// PRIVACY AUDIT: Low sensitivity — only contains app names and usage durations
/// per day. No PII beyond which apps the user used. Subject to 365-day default retention.
struct AppUsageRecord: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "app_usage"

    let id: String                    // UUID string
    let date: Date                    // Start-of-day date
    let appName: String
    let appIcon: String
    let duration: Double              // seconds
    let category: String              // ActivityCategory.rawValue

    // MARK: - Conversion from AppUsage

    init(from usage: AppUsage, date: Date) {
        self.id = usage.id.uuidString
        self.date = Calendar.current.startOfDay(for: date)
        self.appName = usage.appName
        self.appIcon = usage.appIcon
        self.duration = usage.duration
        self.category = usage.category.rawValue
    }

    /// Direct initializer.
    init(
        id: String = UUID().uuidString,
        date: Date,
        appName: String,
        appIcon: String,
        duration: Double,
        category: String
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.appName = appName
        self.appIcon = appIcon
        self.duration = duration
        self.category = category
    }

    // MARK: - Conversion to AppUsage

    func toAppUsage() -> AppUsage {
        AppUsage(
            id: UUID(uuidString: id) ?? UUID(),
            appName: appName,
            appIcon: appIcon,
            duration: duration,
            category: ActivityCategory(rawValue: category) ?? .other
        )
    }
}
