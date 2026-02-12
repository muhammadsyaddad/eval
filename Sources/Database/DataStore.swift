import Foundation
import GRDB

// MARK: - DataStore Protocol

/// Abstraction over the local data store. All database operations go through this protocol.
/// Concrete implementation uses GRDB/SQLite. Tests use an in-memory database.
protocol DataStoreProtocol {

    // MARK: - Captures

    /// Insert a capture record.
    func insertCapture(_ capture: CaptureRecord) throws

    /// Fetch captures in a date range, ordered by timestamp descending.
    func fetchCaptures(from startDate: Date, to endDate: Date) throws -> [CaptureRecord]

    /// Delete captures older than a given date. Returns the number of deleted rows.
    @discardableResult
    func deleteCaptures(olderThan date: Date) throws -> Int

    /// Count of all captures.
    func captureCount() throws -> Int

    // MARK: - Activity Entries

    /// Insert an activity entry.
    func insertActivityEntry(_ entry: ActivityEntryRecord) throws

    /// Fetch activity entries for a date range, ordered by timestamp descending.
    func fetchActivityEntries(from startDate: Date, to endDate: Date) throws -> [ActivityEntryRecord]

    /// Fetch activity entries for a specific day, ordered by timestamp ascending.
    func fetchActivityEntries(for date: Date) throws -> [ActivityEntryRecord]

    /// Delete activity entries older than a given date. Returns the number of deleted rows.
    @discardableResult
    func deleteActivityEntries(olderThan date: Date) throws -> Int

    // MARK: - Daily Summaries

    /// Insert or update a daily summary (upsert by date).
    func upsertDailySummary(_ summary: DailySummaryRecord) throws

    /// Fetch the daily summary for a specific date.
    func fetchDailySummary(for date: Date) throws -> DailySummaryRecord?

    /// Fetch all daily summaries in a date range, ordered by date descending.
    func fetchDailySummaries(from startDate: Date, to endDate: Date) throws -> [DailySummaryRecord]

    /// Fetch all daily summaries, ordered by date descending.
    func fetchAllDailySummaries() throws -> [DailySummaryRecord]

    /// Delete daily summaries older than a given date. Returns the number of deleted rows.
    @discardableResult
    func deleteDailySummaries(olderThan date: Date) throws -> Int

    // MARK: - App Usage

    /// Insert or update an app usage record (upsert by date + appName).
    func upsertAppUsage(_ usage: AppUsageRecord) throws

    /// Fetch app usage for a specific date, ordered by duration descending.
    func fetchAppUsage(for date: Date) throws -> [AppUsageRecord]

    /// Fetch top N apps by total duration in a date range.
    func fetchTopApps(from startDate: Date, to endDate: Date, limit: Int) throws -> [AppUsageRecord]

    /// Delete app usage older than a given date. Returns the number of deleted rows.
    @discardableResult
    func deleteAppUsage(olderThan date: Date) throws -> Int

    // MARK: - Aggregations

    /// Total screen time (seconds) for a specific date.
    func totalScreenTime(for date: Date) throws -> TimeInterval

    /// Total screen time (seconds) for a date range.
    func totalScreenTime(from startDate: Date, to endDate: Date) throws -> TimeInterval

    /// Category breakdown for a date range: category -> total duration (seconds).
    func categoryBreakdown(from startDate: Date, to endDate: Date) throws -> [String: Double]

    /// Daily screen time totals for a date range (for chart data).
    func dailyScreenTimeTotals(from startDate: Date, to endDate: Date) throws -> [(date: Date, totalSeconds: Double)]

    // MARK: - Full-Text Search

    /// Search captures by OCR text, app name, or window title.
    func searchCaptures(query: String, limit: Int) throws -> [CaptureRecord]

    /// Search activity entries by title or summary.
    func searchActivityEntries(query: String, limit: Int) throws -> [ActivityEntryRecord]

    /// Search daily summaries by AI summary text.
    func searchDailySummaries(query: String, limit: Int) throws -> [DailySummaryRecord]

    // MARK: - Storage

    /// Total number of rows across all tables (for diagnostics).
    func totalRowCount() throws -> Int

    /// Delete all data from all tables.
    func deleteAllData() throws
}

// MARK: - DataStore (GRDB Implementation)

/// Concrete DataStore backed by GRDB/SQLite.
final class DataStore: DataStoreProtocol {

    private let dbPool: DatabasePool

    init(databaseManager: DatabaseManager) {
        self.dbPool = databaseManager.dbPool
    }

    /// Create a DataStore directly from a DatabasePool (for testing).
    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    // MARK: - Captures

    func insertCapture(_ capture: CaptureRecord) throws {
        try dbPool.write { db in
            try capture.insert(db)
        }
    }

    func fetchCaptures(from startDate: Date, to endDate: Date) throws -> [CaptureRecord] {
        try dbPool.read { db in
            try CaptureRecord
                .filter(Column("timestamp") >= startDate && Column("timestamp") <= endDate)
                .order(Column("timestamp").desc)
                .fetchAll(db)
        }
    }

    @discardableResult
    func deleteCaptures(olderThan date: Date) throws -> Int {
        try dbPool.write { db in
            try CaptureRecord
                .filter(Column("timestamp") < date)
                .deleteAll(db)
        }
    }

    func captureCount() throws -> Int {
        try dbPool.read { db in
            try CaptureRecord.fetchCount(db)
        }
    }

    // MARK: - Activity Entries

    func insertActivityEntry(_ entry: ActivityEntryRecord) throws {
        try dbPool.write { db in
            try entry.insert(db)
        }
    }

    func fetchActivityEntries(from startDate: Date, to endDate: Date) throws -> [ActivityEntryRecord] {
        try dbPool.read { db in
            try ActivityEntryRecord
                .filter(Column("timestamp") >= startDate && Column("timestamp") <= endDate)
                .order(Column("timestamp").desc)
                .fetchAll(db)
        }
    }

    func fetchActivityEntries(for date: Date) throws -> [ActivityEntryRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return try dbPool.read { db in
            try ActivityEntryRecord
                .filter(Column("timestamp") >= startOfDay && Column("timestamp") < endOfDay)
                .order(Column("timestamp").asc)
                .fetchAll(db)
        }
    }

    @discardableResult
    func deleteActivityEntries(olderThan date: Date) throws -> Int {
        try dbPool.write { db in
            try ActivityEntryRecord
                .filter(Column("timestamp") < date)
                .deleteAll(db)
        }
    }

    // MARK: - Daily Summaries

    func upsertDailySummary(_ summary: DailySummaryRecord) throws {
        try dbPool.write { db in
            // Try to find existing summary for this date
            if let existing = try DailySummaryRecord
                .filter(Column("date") == summary.date)
                .fetchOne(db) {
                // Update the existing record
                var updated = summary
                // Use the existing id so the update targets the right row
                updated = DailySummaryRecord(
                    id: existing.id,
                    date: summary.date,
                    totalScreenTime: summary.totalScreenTime,
                    aiSummary: summary.aiSummary,
                    activityCount: summary.activityCount,
                    productivityScore: summary.productivityScore
                )
                try updated.update(db)
            } else {
                try summary.insert(db)
            }
        }
    }

    func fetchDailySummary(for date: Date) throws -> DailySummaryRecord? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return try dbPool.read { db in
            try DailySummaryRecord
                .filter(Column("date") == startOfDay)
                .fetchOne(db)
        }
    }

    func fetchDailySummaries(from startDate: Date, to endDate: Date) throws -> [DailySummaryRecord] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return try dbPool.read { db in
            try DailySummaryRecord
                .filter(Column("date") >= start && Column("date") <= end)
                .order(Column("date").desc)
                .fetchAll(db)
        }
    }

    func fetchAllDailySummaries() throws -> [DailySummaryRecord] {
        try dbPool.read { db in
            try DailySummaryRecord
                .order(Column("date").desc)
                .fetchAll(db)
        }
    }

    @discardableResult
    func deleteDailySummaries(olderThan date: Date) throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return try dbPool.write { db in
            try DailySummaryRecord
                .filter(Column("date") < startOfDay)
                .deleteAll(db)
        }
    }

    // MARK: - App Usage

    func upsertAppUsage(_ usage: AppUsageRecord) throws {
        try dbPool.write { db in
            if let existing = try AppUsageRecord
                .filter(Column("date") == usage.date && Column("appName") == usage.appName)
                .fetchOne(db) {
                // Accumulate duration
                var updated = AppUsageRecord(
                    id: existing.id,
                    date: usage.date,
                    appName: usage.appName,
                    appIcon: usage.appIcon,
                    duration: existing.duration + usage.duration,
                    category: usage.category
                )
                // Suppress unused variable warning — we need updated to be var for the pattern
                _ = updated
                updated = AppUsageRecord(
                    id: existing.id,
                    date: usage.date,
                    appName: usage.appName,
                    appIcon: usage.appIcon,
                    duration: existing.duration + usage.duration,
                    category: usage.category
                )
                try updated.update(db)
            } else {
                try usage.insert(db)
            }
        }
    }

    func fetchAppUsage(for date: Date) throws -> [AppUsageRecord] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return try dbPool.read { db in
            try AppUsageRecord
                .filter(Column("date") == startOfDay)
                .order(Column("duration").desc)
                .fetchAll(db)
        }
    }

    func fetchTopApps(from startDate: Date, to endDate: Date, limit: Int) throws -> [AppUsageRecord] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return try dbPool.read { db in
            // Aggregate app usage across days
            let rows = try Row.fetchAll(db, sql: """
                SELECT appName, appIcon, category, SUM(duration) as totalDuration
                FROM app_usage
                WHERE date >= ? AND date <= ?
                GROUP BY appName
                ORDER BY totalDuration DESC
                LIMIT ?
                """, arguments: [start, end, limit])

            return rows.map { row in
                AppUsageRecord(
                    date: start,
                    appName: row["appName"],
                    appIcon: row["appIcon"],
                    duration: row["totalDuration"],
                    category: row["category"]
                )
            }
        }
    }

    @discardableResult
    func deleteAppUsage(olderThan date: Date) throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return try dbPool.write { db in
            try AppUsageRecord
                .filter(Column("date") < startOfDay)
                .deleteAll(db)
        }
    }

    // MARK: - Aggregations

    func totalScreenTime(for date: Date) throws -> TimeInterval {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return try dbPool.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT COALESCE(SUM(duration), 0) as total
                FROM app_usage
                WHERE date = ?
                """, arguments: [startOfDay])
            return row?["total"] ?? 0
        }
    }

    func totalScreenTime(from startDate: Date, to endDate: Date) throws -> TimeInterval {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return try dbPool.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT COALESCE(SUM(duration), 0) as total
                FROM app_usage
                WHERE date >= ? AND date <= ?
                """, arguments: [start, end])
            return row?["total"] ?? 0
        }
    }

    func categoryBreakdown(from startDate: Date, to endDate: Date) throws -> [String: Double] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return try dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT category, SUM(duration) as totalDuration
                FROM app_usage
                WHERE date >= ? AND date <= ?
                GROUP BY category
                ORDER BY totalDuration DESC
                """, arguments: [start, end])

            var result: [String: Double] = [:]
            for row in rows {
                let category: String = row["category"]
                let duration: Double = row["totalDuration"]
                result[category] = duration
            }
            return result
        }
    }

    func dailyScreenTimeTotals(from startDate: Date, to endDate: Date) throws -> [(date: Date, totalSeconds: Double)] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return try dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT date, SUM(duration) as totalDuration
                FROM app_usage
                WHERE date >= ? AND date <= ?
                GROUP BY date
                ORDER BY date ASC
                """, arguments: [start, end])

            return rows.map { row in
                let date: Date = row["date"]
                let total: Double = row["totalDuration"]
                return (date: date, totalSeconds: total)
            }
        }
    }

    // MARK: - Full-Text Search

    func searchCaptures(query: String, limit: Int) throws -> [CaptureRecord] {
        let ftsQuery = sanitizeFTSQuery(query)
        guard !ftsQuery.isEmpty else { return [] }
        return try PerformanceLogger.shared.measure(.dbSearch, label: "fts_captures") {
            try dbPool.read { db in
                try CaptureRecord.fetchAll(db, sql: """
                    SELECT captures.*
                    FROM captures
                    JOIN captures_fts ON captures_fts.rowid = captures.rowid
                    WHERE captures_fts MATCH ?
                    ORDER BY rank
                    LIMIT ?
                    """, arguments: [ftsQuery, limit])
            }
        }
    }

    func searchActivityEntries(query: String, limit: Int) throws -> [ActivityEntryRecord] {
        let ftsQuery = sanitizeFTSQuery(query)
        guard !ftsQuery.isEmpty else { return [] }
        return try PerformanceLogger.shared.measure(.dbSearch, label: "fts_activity_entries") {
            try dbPool.read { db in
                try ActivityEntryRecord.fetchAll(db, sql: """
                    SELECT activity_entries.*
                    FROM activity_entries
                    JOIN activity_entries_fts ON activity_entries_fts.rowid = activity_entries.rowid
                    WHERE activity_entries_fts MATCH ?
                    ORDER BY rank
                    LIMIT ?
                    """, arguments: [ftsQuery, limit])
            }
        }
    }

    func searchDailySummaries(query: String, limit: Int) throws -> [DailySummaryRecord] {
        let ftsQuery = sanitizeFTSQuery(query)
        guard !ftsQuery.isEmpty else { return [] }
        return try PerformanceLogger.shared.measure(.dbSearch, label: "fts_daily_summaries") {
            try dbPool.read { db in
                try DailySummaryRecord.fetchAll(db, sql: """
                    SELECT daily_summaries.*
                    FROM daily_summaries
                    JOIN daily_summaries_fts ON daily_summaries_fts.rowid = daily_summaries.rowid
                    WHERE daily_summaries_fts MATCH ?
                    ORDER BY rank
                    LIMIT ?
                    """, arguments: [ftsQuery, limit])
            }
        }
    }

    // MARK: - Storage

    func totalRowCount() throws -> Int {
        try dbPool.read { db in
            let captures = try CaptureRecord.fetchCount(db)
            let activities = try ActivityEntryRecord.fetchCount(db)
            let summaries = try DailySummaryRecord.fetchCount(db)
            let appUsage = try AppUsageRecord.fetchCount(db)
            return captures + activities + summaries + appUsage
        }
    }

    func deleteAllData() throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM captures")
            try db.execute(sql: "DELETE FROM activity_entries")
            try db.execute(sql: "DELETE FROM daily_summaries")
            try db.execute(sql: "DELETE FROM app_usage")
        }
    }

    // MARK: - Private

    /// Sanitize user input for FTS5 queries. Wraps each word in quotes to prevent syntax errors.
    private func sanitizeFTSQuery(_ query: String) -> String {
        let words = query
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { "\"\($0)\"" }
        return words.joined(separator: " ")
    }
}
