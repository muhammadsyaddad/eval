import XCTest
@testable import Eval
import GRDB

// MARK: - Database Test Helpers

/// Creates a fresh in-memory DatabaseManager + DataStore for each test.
class DatabaseTestCase: XCTestCase {
    var dbManager: DatabaseManager!
    var dataStore: DataStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use a temporary file-based database (in-memory doesn't work with DatabasePool)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("eval_test_\(UUID().uuidString).db")
        dbManager = try DatabaseManager(databaseURL: tmpURL)
        dataStore = DataStore(databaseManager: dbManager)
    }

    override func tearDownWithError() throws {
        // Clean up temp file
        try? FileManager.default.removeItem(at: dbManager.databaseURL)
        dbManager = nil
        dataStore = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    func makeCapture(
        appName: String = "Xcode",
        bundleId: String = "com.apple.dt.Xcode",
        windowTitle: String = "Project.swift",
        ocrText: String? = nil,
        timestamp: Date = Date()
    ) -> CaptureRecord {
        CaptureRecord(
            timestamp: timestamp,
            appName: appName,
            bundleIdentifier: bundleId,
            windowTitle: windowTitle,
            imagePath: "2026-02-08/\(UUID().uuidString).png",
            ocrText: ocrText,
            ocrConfidence: ocrText != nil ? 0.95 : nil
        )
    }

    func makeActivity(
        appName: String = "Xcode",
        title: String = "Coding session",
        summary: String = "Worked on features",
        category: String = "Development",
        duration: Double = 3600,
        timestamp: Date = Date()
    ) -> ActivityEntryRecord {
        ActivityEntryRecord(
            timestamp: timestamp,
            appName: appName,
            appIcon: "hammer.fill",
            title: title,
            summary: summary,
            category: category,
            duration: duration
        )
    }

    func makeSummary(
        date: Date = Date(),
        screenTime: Double = 28800,
        aiSummary: String = "Productive development day",
        activityCount: Int = 8,
        productivityScore: Double = 0.85
    ) -> DailySummaryRecord {
        DailySummaryRecord(
            date: date,
            totalScreenTime: screenTime,
            aiSummary: aiSummary,
            activityCount: activityCount,
            productivityScore: productivityScore
        )
    }

    func makeAppUsage(
        date: Date = Date(),
        appName: String = "Xcode",
        duration: Double = 18000,
        category: String = "Development"
    ) -> AppUsageRecord {
        AppUsageRecord(
            date: date,
            appName: appName,
            appIcon: "hammer.fill",
            duration: duration,
            category: category
        )
    }
}

// MARK: - Schema / Migration Tests

final class DatabaseSchemaTests: DatabaseTestCase {

    func testDatabaseCreated() throws {
        // The database should exist after init
        XCTAssertNotNil(dbManager)
        XCTAssertNotNil(dataStore)
    }

    func testTablesExist() throws {
        try dbManager.dbPool.read { db in
            XCTAssertTrue(try db.tableExists("captures"))
            XCTAssertTrue(try db.tableExists("activity_entries"))
            XCTAssertTrue(try db.tableExists("daily_summaries"))
            XCTAssertTrue(try db.tableExists("app_usage"))
        }
    }

    func testFTSTablesExist() throws {
        try dbManager.dbPool.read { db in
            XCTAssertTrue(try db.tableExists("captures_fts"))
            XCTAssertTrue(try db.tableExists("activity_entries_fts"))
            XCTAssertTrue(try db.tableExists("daily_summaries_fts"))
        }
    }

    func testEmptyDatabaseRowCount() throws {
        let count = try dataStore.totalRowCount()
        XCTAssertEqual(count, 0)
    }
}

// MARK: - Capture CRUD Tests

final class CaptureCRUDTests: DatabaseTestCase {

    func testInsertCapture() throws {
        let capture = makeCapture()
        try dataStore.insertCapture(capture)
        let count = try dataStore.captureCount()
        XCTAssertEqual(count, 1)
    }

    func testFetchCapturesByDateRange() throws {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now)!

        try dataStore.insertCapture(makeCapture(timestamp: now))
        try dataStore.insertCapture(makeCapture(timestamp: yesterday))
        try dataStore.insertCapture(makeCapture(timestamp: twoDaysAgo))

        // Fetch only yesterday to today
        let results = try dataStore.fetchCaptures(from: yesterday, to: now)
        XCTAssertEqual(results.count, 2)

        // All results should be in descending order
        if results.count == 2 {
            XCTAssertTrue(results[0].timestamp >= results[1].timestamp)
        }
    }

    func testDeleteCapturesOlderThan() throws {
        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        try dataStore.insertCapture(makeCapture(timestamp: oldDate))
        try dataStore.insertCapture(makeCapture(timestamp: recentDate))
        try dataStore.insertCapture(makeCapture(timestamp: now))

        // Delete captures older than 5 days ago
        let cutoff = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        let deleted = try dataStore.deleteCaptures(olderThan: cutoff)
        XCTAssertEqual(deleted, 1)

        let remaining = try dataStore.captureCount()
        XCTAssertEqual(remaining, 2)
    }

    func testCaptureToStoredCaptureConversion() throws {
        let capture = makeCapture(
            appName: "Safari",
            bundleId: "com.apple.Safari",
            windowTitle: "Apple",
            ocrText: "Hello world"
        )

        let stored = capture.toStoredCapture()
        XCTAssertEqual(stored.metadata.appName, "Safari")
        XCTAssertEqual(stored.metadata.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(stored.ocrText, "Hello world")
        XCTAssertNotNil(stored.ocrConfidence)
    }
}

// MARK: - Activity Entry CRUD Tests

final class ActivityEntryCRUDTests: DatabaseTestCase {

    func testInsertActivityEntry() throws {
        let entry = makeActivity()
        try dataStore.insertActivityEntry(entry)

        let entries = try dataStore.fetchActivityEntries(for: Date())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.appName, "Xcode")
    }

    func testFetchActivityEntriesForDate() throws {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        try dataStore.insertActivityEntry(makeActivity(timestamp: now))
        try dataStore.insertActivityEntry(makeActivity(appName: "Safari", timestamp: now))
        try dataStore.insertActivityEntry(makeActivity(timestamp: yesterday))

        let todayEntries = try dataStore.fetchActivityEntries(for: now)
        XCTAssertEqual(todayEntries.count, 2)

        let yesterdayEntries = try dataStore.fetchActivityEntries(for: yesterday)
        XCTAssertEqual(yesterdayEntries.count, 1)
    }

    func testFetchActivityEntriesByDateRange() throws {
        let now = Date()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: now)!

        try dataStore.insertActivityEntry(makeActivity(timestamp: now))
        try dataStore.insertActivityEntry(makeActivity(timestamp: threeDaysAgo))
        try dataStore.insertActivityEntry(makeActivity(timestamp: fiveDaysAgo))

        let results = try dataStore.fetchActivityEntries(from: threeDaysAgo, to: now)
        XCTAssertEqual(results.count, 2)
    }

    func testActivityEntryConversion() {
        let record = ActivityEntryRecord(
            timestamp: Date(),
            appName: "Slack",
            appIcon: "bubble.fill",
            title: "Team chat",
            summary: "Discussed sprint",
            category: "Communication",
            duration: 1800
        )

        let entry = record.toActivityEntry()
        XCTAssertEqual(entry.appName, "Slack")
        XCTAssertEqual(entry.category, .communication)
        XCTAssertEqual(entry.duration, 1800)
    }

    func testDeleteActivityEntriesOlderThan() throws {
        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -100, to: now)!

        try dataStore.insertActivityEntry(makeActivity(timestamp: oldDate))
        try dataStore.insertActivityEntry(makeActivity(timestamp: now))

        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let deleted = try dataStore.deleteActivityEntries(olderThan: cutoff)
        XCTAssertEqual(deleted, 1)
    }
}

// MARK: - Daily Summary CRUD Tests

final class DailySummaryCRUDTests: DatabaseTestCase {

    func testInsertAndFetchDailySummary() throws {
        let summary = makeSummary()
        try dataStore.upsertDailySummary(summary)

        let fetched = try dataStore.fetchDailySummary(for: Date())
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.totalScreenTime, 28800)
        XCTAssertEqual(fetched?.productivityScore, 0.85)
    }

    func testUpsertDailySummaryUpdatesExisting() throws {
        let date = Date()
        let first = makeSummary(date: date, screenTime: 10000, aiSummary: "First version")
        try dataStore.upsertDailySummary(first)

        let second = makeSummary(date: date, screenTime: 20000, aiSummary: "Updated version")
        try dataStore.upsertDailySummary(second)

        let all = try dataStore.fetchAllDailySummaries()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.aiSummary, "Updated version")
        XCTAssertEqual(all.first?.totalScreenTime, 20000)
    }

    func testFetchAllDailySummariesDescending() throws {
        let now = Date()
        let cal = Calendar.current
        for i in 0..<5 {
            let date = cal.date(byAdding: .day, value: -i, to: now)!
            try dataStore.upsertDailySummary(makeSummary(date: date))
        }

        let all = try dataStore.fetchAllDailySummaries()
        XCTAssertEqual(all.count, 5)
        // Should be sorted descending by date
        for i in 0..<(all.count - 1) {
            XCTAssertTrue(all[i].date >= all[i+1].date)
        }
    }

    func testFetchDailySummariesByDateRange() throws {
        let now = Date()
        let cal = Calendar.current
        for i in 0..<10 {
            let date = cal.date(byAdding: .day, value: -i, to: now)!
            try dataStore.upsertDailySummary(makeSummary(date: date))
        }

        let start = cal.date(byAdding: .day, value: -4, to: now)!
        let results = try dataStore.fetchDailySummaries(from: start, to: now)
        XCTAssertEqual(results.count, 5)
    }

    func testDailySummaryToDaySummaryConversion() throws {
        let record = DailySummaryRecord(
            date: Date(),
            totalScreenTime: 28800,
            aiSummary: "Great day",
            activityCount: 10,
            productivityScore: 0.9
        )

        let apps = [
            AppUsage(appName: "Xcode", appIcon: "hammer.fill", duration: 18000, category: .development)
        ]
        let summary = record.toDaySummary(topApps: apps)
        XCTAssertEqual(summary.aiSummary, "Great day")
        XCTAssertEqual(summary.topApps.count, 1)
        XCTAssertEqual(summary.topApps.first?.appName, "Xcode")
    }
}

// MARK: - App Usage CRUD Tests

final class AppUsageCRUDTests: DatabaseTestCase {

    func testInsertAndFetchAppUsage() throws {
        let usage = makeAppUsage()
        try dataStore.upsertAppUsage(usage)

        let results = try dataStore.fetchAppUsage(for: Date())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.appName, "Xcode")
    }

    func testUpsertAccumulatesDuration() throws {
        let date = Date()
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Xcode", duration: 1000))
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Xcode", duration: 500))

        let results = try dataStore.fetchAppUsage(for: date)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.duration, 1500) // 1000 + 500
    }

    func testFetchTopApps() throws {
        let date = Date()
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Xcode", duration: 18000, category: "Development"))
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Safari", duration: 5000, category: "Browsing"))
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Slack", duration: 3000, category: "Communication"))

        let topApps = try dataStore.fetchTopApps(from: date, to: date, limit: 2)
        XCTAssertEqual(topApps.count, 2)
        XCTAssertEqual(topApps.first?.appName, "Xcode")
    }

    func testAppUsageSortedByDuration() throws {
        let date = Date()
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Mail", duration: 500))
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Xcode", duration: 18000))
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Safari", duration: 5000))

        let results = try dataStore.fetchAppUsage(for: date)
        XCTAssertEqual(results.count, 3)
        // Should be descending by duration
        XCTAssertEqual(results[0].appName, "Xcode")
        XCTAssertEqual(results[1].appName, "Safari")
        XCTAssertEqual(results[2].appName, "Mail")
    }
}

// MARK: - Aggregation Tests

final class AggregationTests: DatabaseTestCase {

    func testTotalScreenTimeForDate() throws {
        let date = Date()
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Xcode", duration: 10000))
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Safari", duration: 5000))

        let total = try dataStore.totalScreenTime(for: date)
        XCTAssertEqual(total, 15000)
    }

    func testTotalScreenTimeForDateRange() throws {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        try dataStore.upsertAppUsage(makeAppUsage(date: now, appName: "Xcode", duration: 10000))
        try dataStore.upsertAppUsage(makeAppUsage(date: yesterday, appName: "Xcode", duration: 8000))

        let total = try dataStore.totalScreenTime(from: yesterday, to: now)
        XCTAssertEqual(total, 18000)
    }

    func testCategoryBreakdown() throws {
        let date = Date()
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Xcode", duration: 18000, category: "Development"))
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Safari", duration: 5000, category: "Browsing"))
        try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Slack", duration: 3000, category: "Communication"))

        let breakdown = try dataStore.categoryBreakdown(from: date, to: date)
        XCTAssertEqual(breakdown["Development"], 18000)
        XCTAssertEqual(breakdown["Browsing"], 5000)
        XCTAssertEqual(breakdown["Communication"], 3000)
    }

    func testDailyScreenTimeTotals() throws {
        let now = Date()
        let cal = Calendar.current

        for i in 0..<3 {
            let date = cal.date(byAdding: .day, value: -i, to: now)!
            try dataStore.upsertAppUsage(makeAppUsage(date: date, appName: "Xcode", duration: Double(10000 + i * 1000)))
        }

        let start = cal.date(byAdding: .day, value: -2, to: now)!
        let totals = try dataStore.dailyScreenTimeTotals(from: start, to: now)
        XCTAssertEqual(totals.count, 3)
        // Should be ascending by date
        for i in 0..<(totals.count - 1) {
            XCTAssertTrue(totals[i].date <= totals[i+1].date)
        }
    }

    func testEmptyAggregations() throws {
        let total = try dataStore.totalScreenTime(for: Date())
        XCTAssertEqual(total, 0)

        let breakdown = try dataStore.categoryBreakdown(from: Date(), to: Date())
        XCTAssertTrue(breakdown.isEmpty)
    }
}

// MARK: - Full-Text Search Tests

final class FullTextSearchTests: DatabaseTestCase {

    func testSearchCaptures() throws {
        try dataStore.insertCapture(makeCapture(
            appName: "Xcode",
            windowTitle: "SwiftUI project",
            ocrText: "func viewDidLoad() { super.viewDidLoad() }"
        ))
        try dataStore.insertCapture(makeCapture(
            appName: "Safari",
            windowTitle: "Apple Developer",
            ocrText: "Welcome to the Apple Developer documentation"
        ))

        // Search by OCR text
        let results1 = try dataStore.searchCaptures(query: "viewDidLoad", limit: 10)
        XCTAssertEqual(results1.count, 1)
        XCTAssertEqual(results1.first?.appName, "Xcode")

        // Search by app name
        let results2 = try dataStore.searchCaptures(query: "Safari", limit: 10)
        XCTAssertEqual(results2.count, 1)

        // Search by window title
        let results3 = try dataStore.searchCaptures(query: "Developer", limit: 10)
        XCTAssertEqual(results3.count, 1)
    }

    func testSearchActivityEntries() throws {
        try dataStore.insertActivityEntry(makeActivity(
            title: "OCR pipeline implementation",
            summary: "Implemented VNRecognizeTextRequest handler"
        ))
        try dataStore.insertActivityEntry(makeActivity(
            title: "Team standup",
            summary: "Discussed sprint planning and backlog"
        ))

        let results = try dataStore.searchActivityEntries(query: "pipeline", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "OCR pipeline implementation")

        let results2 = try dataStore.searchActivityEntries(query: "sprint", limit: 10)
        XCTAssertEqual(results2.count, 1)
    }

    func testSearchDailySummaries() throws {
        try dataStore.upsertDailySummary(makeSummary(
            aiSummary: "Productive development day focused on Eval OCR pipeline"
        ))
        try dataStore.upsertDailySummary(makeSummary(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            aiSummary: "Meeting-heavy day with design reviews and sprint planning"
        ))

        let results = try dataStore.searchDailySummaries(query: "Eval", limit: 10)
        XCTAssertEqual(results.count, 1)

        let results2 = try dataStore.searchDailySummaries(query: "design", limit: 10)
        XCTAssertEqual(results2.count, 1)
    }

    func testSearchWithEmptyQuery() throws {
        try dataStore.insertCapture(makeCapture(ocrText: "Some text"))

        let results = try dataStore.searchCaptures(query: "", limit: 10)
        XCTAssertEqual(results.count, 0)

        let results2 = try dataStore.searchCaptures(query: "   ", limit: 10)
        XCTAssertEqual(results2.count, 0)
    }

    func testSearchWithLimit() throws {
        for i in 0..<10 {
            try dataStore.insertActivityEntry(makeActivity(
                title: "Task \(i): coding session",
                summary: "Worked on coding feature \(i)"
            ))
        }

        let results = try dataStore.searchActivityEntries(query: "coding", limit: 3)
        XCTAssertEqual(results.count, 3)
    }
}

// MARK: - Delete All Data Tests

final class DeleteAllDataTests: DatabaseTestCase {

    func testDeleteAllData() throws {
        // Insert data into all tables
        try dataStore.insertCapture(makeCapture())
        try dataStore.insertActivityEntry(makeActivity())
        try dataStore.upsertDailySummary(makeSummary())
        try dataStore.upsertAppUsage(makeAppUsage())

        let countBefore = try dataStore.totalRowCount()
        XCTAssertEqual(countBefore, 4)

        try dataStore.deleteAllData()

        let countAfter = try dataStore.totalRowCount()
        XCTAssertEqual(countAfter, 0)
    }
}

// MARK: - Export Service Tests

final class ExportServiceTests: DatabaseTestCase {

    var exportService: ExportService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        exportService = ExportService(dataStore: dataStore)
    }

    func testExportDailySummariesJSON() throws {
        let now = Date()
        try dataStore.upsertDailySummary(makeSummary(date: now, aiSummary: "Test day summary"))

        let data = try exportService.exportDailySummaries(
            from: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
            to: now,
            format: .json
        )

        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("Test day summary"))
        XCTAssertTrue(json.contains("totalScreenTimeSeconds"))
    }

    func testExportDailySummariesCSV() throws {
        let now = Date()
        try dataStore.upsertDailySummary(makeSummary(date: now, aiSummary: "CSV test"))

        let data = try exportService.exportDailySummaries(
            from: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
            to: now,
            format: .csv
        )

        let csv = String(data: data, encoding: .utf8)!
        XCTAssertTrue(csv.hasPrefix("date,"))
        XCTAssertTrue(csv.contains("CSV test"))
    }

    func testExportActivityEntriesJSON() throws {
        let now = Date()
        try dataStore.insertActivityEntry(makeActivity(title: "Exported task", timestamp: now))

        let data = try exportService.exportActivityEntries(
            from: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
            to: now,
            format: .json
        )

        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("Exported task"))
    }

    func testExportActivityEntriesCSV() throws {
        let now = Date()
        try dataStore.insertActivityEntry(makeActivity(title: "CSV activity", timestamp: now))

        let data = try exportService.exportActivityEntries(
            from: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
            to: now,
            format: .csv
        )

        let csv = String(data: data, encoding: .utf8)!
        XCTAssertTrue(csv.hasPrefix("timestamp,"))
        XCTAssertTrue(csv.contains("CSV activity"))
    }

    func testExportAll() throws {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        try dataStore.upsertDailySummary(makeSummary(date: now))
        try dataStore.insertActivityEntry(makeActivity(timestamp: now))
        try dataStore.upsertAppUsage(makeAppUsage(date: now))

        let data = try exportService.exportAll(from: yesterday, to: now)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("dailySummaries"))
        XCTAssertTrue(json.contains("activityEntries"))
        XCTAssertTrue(json.contains("appUsage"))
        XCTAssertTrue(json.contains("dateRange"))
    }

    func testExportEmptyData() throws {
        let now = Date()
        let data = try exportService.exportDailySummaries(
            from: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
            to: now,
            format: .json
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json.trimmingCharacters(in: .whitespacesAndNewlines), "[\n\n]")
    }

    func testCSVEscapingCommas() throws {
        let now = Date()
        try dataStore.insertActivityEntry(makeActivity(
            title: "Task with, comma",
            summary: "Has \"quotes\" and, commas",
            timestamp: now
        ))

        let data = try exportService.exportActivityEntries(
            from: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
            to: now,
            format: .csv
        )

        let csv = String(data: data, encoding: .utf8)!
        // CSV should escape the comma-containing fields with quotes
        XCTAssertTrue(csv.contains("\"Task with, comma\""))
    }
}

// MARK: - Retention Tests

final class DataRetentionTests: DatabaseTestCase {

    func testApplyRetentionDeletesOldCaptures() throws {
        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -60, to: now)!

        try dataStore.insertCapture(makeCapture(timestamp: oldDate))
        try dataStore.insertCapture(makeCapture(timestamp: now))

        let mockStorage = MockCaptureStorage()
        let retention = DataRetentionService(
            dataStore: dataStore,
            captureStorage: mockStorage,
            databaseManager: dbManager,
            policy: RetentionPolicy(captureRetentionDays: 30)
        )

        let result = try retention.applyRetention()
        XCTAssertEqual(result.capturesDeleted, 1)

        let remaining = try dataStore.captureCount()
        XCTAssertEqual(remaining, 1)
    }

    func testApplyRetentionDeletesOldActivities() throws {
        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -120, to: now)!

        try dataStore.insertActivityEntry(makeActivity(timestamp: oldDate))
        try dataStore.insertActivityEntry(makeActivity(timestamp: now))

        let mockStorage = MockCaptureStorage()
        let retention = DataRetentionService(
            dataStore: dataStore,
            captureStorage: mockStorage,
            databaseManager: dbManager,
            policy: RetentionPolicy(activityRetentionDays: 90)
        )

        let result = try retention.applyRetention()
        XCTAssertEqual(result.activityEntriesDeleted, 1)
    }

    func testApplyRetentionKeepsRecentData() throws {
        let now = Date()
        let recentDate = Calendar.current.date(byAdding: .day, value: -5, to: now)!

        try dataStore.insertCapture(makeCapture(timestamp: recentDate))
        try dataStore.insertCapture(makeCapture(timestamp: now))

        let mockStorage = MockCaptureStorage()
        let retention = DataRetentionService(
            dataStore: dataStore,
            captureStorage: mockStorage,
            databaseManager: dbManager,
            policy: RetentionPolicy(captureRetentionDays: 30)
        )

        let result = try retention.applyRetention()
        XCTAssertEqual(result.capturesDeleted, 0)
        XCTAssertEqual(result.totalDeleted, 0)
    }

    func testTotalStorageBytes() throws {
        let mockStorage = MockCaptureStorage()
        mockStorage.mockStorageBytes = 1000000

        let retention = DataRetentionService(
            dataStore: dataStore,
            captureStorage: mockStorage,
            databaseManager: dbManager
        )

        let total = retention.totalStorageBytes()
        // Should be DB size + capture storage size
        XCTAssertTrue(total >= 1000000)
    }
}

// MARK: - Record Conversion Tests

final class RecordConversionTests: XCTestCase {

    func testCaptureRecordFromCaptureResult() {
        let metadata = WindowMetadata(
            appName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: "main.swift",
            browserURL: nil
        )
        let ocrResult = OCRResult(
            fullText: "Hello world",
            observations: [],
            detectedLanguage: "en",
            processingTime: 0.5
        )
        let capture = CaptureResult(
            imageData: Data(),
            metadata: metadata,
            ocrResult: ocrResult
        )

        let record = CaptureRecord(from: capture, imagePath: "2026/test.png")
        XCTAssertEqual(record.appName, "Xcode")
        XCTAssertEqual(record.ocrText, "Hello world")
        XCTAssertEqual(record.imagePath, "2026/test.png")
    }

    func testActivityEntryRecordFromActivityEntry() {
        let entry = ActivityEntry(
            timestamp: Date(),
            appName: "Slack",
            appIcon: "bubble.fill",
            title: "Standup",
            summary: "Daily standup",
            category: .communication,
            duration: 1800
        )

        let record = ActivityEntryRecord(from: entry)
        XCTAssertEqual(record.appName, "Slack")
        XCTAssertEqual(record.category, "Communication")
        XCTAssertEqual(record.duration, 1800)

        let back = record.toActivityEntry()
        XCTAssertEqual(back.category, .communication)
        XCTAssertEqual(back.appName, "Slack")
    }

    func testDailySummaryRecordFromDaySummary() {
        let summary = DaySummary(
            date: Date(),
            totalScreenTime: 28800,
            topApps: [],
            aiSummary: "Good day",
            activityCount: 10,
            productivityScore: 0.85
        )

        let record = DailySummaryRecord(from: summary)
        XCTAssertEqual(record.totalScreenTime, 28800)
        XCTAssertEqual(record.aiSummary, "Good day")

        let back = record.toDaySummary(topApps: [])
        XCTAssertEqual(back.aiSummary, "Good day")
        XCTAssertEqual(back.productivityScore, 0.85)
    }

    func testAppUsageRecordFromAppUsage() {
        let usage = AppUsage(
            appName: "Xcode",
            appIcon: "hammer.fill",
            duration: 18000,
            category: .development
        )

        let record = AppUsageRecord(from: usage, date: Date())
        XCTAssertEqual(record.appName, "Xcode")
        XCTAssertEqual(record.category, "Development")

        let back = record.toAppUsage()
        XCTAssertEqual(back.category, .development)
    }
}

// MARK: - Mock Capture Storage (for retention tests)

final class MockCaptureStorage: CaptureStorageServiceProtocol {
    var mockStorageBytes: UInt64 = 0
    var deleteCalled = false

    func save(_ capture: CaptureResult) throws -> URL {
        URL(fileURLWithPath: "/tmp/mock.png")
    }

    func listCaptures(from: Date, to: Date) -> [StoredCapture] {
        []
    }

    func deleteCaptures(olderThan date: Date) throws {
        deleteCalled = true
    }

    func deleteAllCaptures() throws -> UInt64 {
        deleteCalled = true
        return mockStorageBytes
    }

    func totalStorageBytes() -> UInt64 {
        mockStorageBytes
    }
}
