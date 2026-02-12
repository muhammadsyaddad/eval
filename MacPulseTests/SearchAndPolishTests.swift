import XCTest
@testable import MacPulse

// MARK: - SearchResult Model Tests

final class SearchResultModelTests: XCTestCase {

    func testSearchResultCreationWithDefaults() {
        let date = Date()
        let result = SearchResult(
            date: date,
            title: "Test Title",
            snippet: "Some snippet",
            matchedField: "summary",
            source: .activityEntry
        )

        XCTAssertEqual(result.title, "Test Title")
        XCTAssertEqual(result.snippet, "Some snippet")
        XCTAssertEqual(result.matchedField, "summary")
        XCTAssertEqual(result.source, .activityEntry)
        XCTAssertEqual(result.date, date)
        XCTAssertNil(result.appName)
        XCTAssertNil(result.appIcon)
        XCTAssertNil(result.category)
    }

    func testSearchResultCreationWithAllFields() {
        let date = Date()
        let id = UUID()
        let result = SearchResult(
            id: id,
            date: date,
            title: "Xcode Session",
            snippet: "Worked on SwiftUI views",
            matchedField: "title",
            source: .activityEntry,
            appName: "Xcode",
            appIcon: "hammer.fill",
            category: .development
        )

        XCTAssertEqual(result.id, id)
        XCTAssertEqual(result.appName, "Xcode")
        XCTAssertEqual(result.appIcon, "hammer.fill")
        XCTAssertEqual(result.category, .development)
    }

    func testSearchResultDailySummarySource() {
        let result = SearchResult(
            date: Date(),
            title: "Daily Summary",
            snippet: "Productive day with 6h screen time",
            matchedField: "aiSummary",
            source: .dailySummary
        )

        XCTAssertEqual(result.source, .dailySummary)
        XCTAssertNil(result.appName)
        XCTAssertNil(result.category)
    }

    func testSearchResultCaptureSource() {
        let result = SearchResult(
            date: Date(),
            title: "Browser Window",
            snippet: "SwiftUI documentation page",
            matchedField: "ocrText",
            source: .capture,
            appName: "Safari"
        )

        XCTAssertEqual(result.source, .capture)
        XCTAssertEqual(result.appName, "Safari")
        XCTAssertEqual(result.matchedField, "ocrText")
    }
}

// MARK: - SearchResultSource Tests

final class SearchResultSourceTests: XCTestCase {

    func testActivityEntryRawValue() {
        XCTAssertEqual(SearchResultSource.activityEntry.rawValue, "Activity")
    }

    func testDailySummaryRawValue() {
        XCTAssertEqual(SearchResultSource.dailySummary.rawValue, "Daily Summary")
    }

    func testCaptureRawValue() {
        XCTAssertEqual(SearchResultSource.capture.rawValue, "Capture")
    }

    func testActivityEntryIcon() {
        XCTAssertEqual(SearchResultSource.activityEntry.icon, "text.badge.checkmark")
    }

    func testDailySummaryIcon() {
        XCTAssertEqual(SearchResultSource.dailySummary.icon, "calendar")
    }

    func testCaptureIcon() {
        XCTAssertEqual(SearchResultSource.capture.icon, "camera.fill")
    }
}

// MARK: - AppError Model Tests

final class AppErrorModelTests: XCTestCase {

    func testAppErrorCreationWithDefaults() {
        let error = AppError(title: "Test Error", message: "Something went wrong")

        XCTAssertEqual(error.title, "Test Error")
        XCTAssertEqual(error.message, "Something went wrong")
        XCTAssertEqual(error.severity, .warning) // Default severity
        XCTAssertNotNil(error.id)
        XCTAssertNotNil(error.timestamp)
    }

    func testAppErrorCreationWithCustomSeverity() {
        let error = AppError(title: "Fatal", message: "Disk full", severity: .error)
        XCTAssertEqual(error.severity, .error)
    }

    func testAppErrorInfoSeverity() {
        let error = AppError(title: "Info", message: "Capture started", severity: .info)
        XCTAssertEqual(error.severity, .info)
    }

    func testAppErrorCustomTimestamp() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let error = AppError(title: "Old", message: "Past error", timestamp: date)
        XCTAssertEqual(error.timestamp, date)
    }

    func testAppErrorCustomId() {
        let id = UUID()
        let error = AppError(id: id, title: "Test", message: "Test")
        XCTAssertEqual(error.id, id)
    }
}

// MARK: - ErrorSeverity Tests

final class ErrorSeverityTests: XCTestCase {

    func testInfoRawValue() {
        XCTAssertEqual(ErrorSeverity.info.rawValue, "Info")
    }

    func testWarningRawValue() {
        XCTAssertEqual(ErrorSeverity.warning.rawValue, "Warning")
    }

    func testErrorRawValue() {
        XCTAssertEqual(ErrorSeverity.error.rawValue, "Error")
    }
}

// MARK: - AppState Error Handling Tests

final class AppStateErrorTests: XCTestCase {

    func testShowErrorSetsCurrentError() {
        let appState = AppState()
        XCTAssertNil(appState.currentError)

        appState.showError(title: "Permission Denied", message: "Screen Recording not granted")

        XCTAssertNotNil(appState.currentError)
        XCTAssertEqual(appState.currentError?.title, "Permission Denied")
        XCTAssertEqual(appState.currentError?.message, "Screen Recording not granted")
        XCTAssertEqual(appState.currentError?.severity, .warning)
    }

    func testShowErrorWithSeverity() {
        let appState = AppState()
        appState.showError(title: "Disk Full", message: "No space left", severity: .error)

        XCTAssertEqual(appState.currentError?.severity, .error)
    }

    func testDismissErrorClearsCurrentError() {
        let appState = AppState()
        appState.showError(title: "Test", message: "Test")
        XCTAssertNotNil(appState.currentError)

        appState.dismissError()
        XCTAssertNil(appState.currentError)
    }

    func testShowErrorReplacesExisting() {
        let appState = AppState()
        appState.showError(title: "First", message: "First error")
        XCTAssertEqual(appState.currentError?.title, "First")

        appState.showError(title: "Second", message: "Second error")
        XCTAssertEqual(appState.currentError?.title, "Second")
    }
}

// MARK: - AppState Search Tests

final class AppStateSearchTests: XCTestCase {

    func testInitialSearchState() {
        let appState = AppState()
        XCTAssertTrue(appState.searchResults.isEmpty)
        XCTAssertFalse(appState.isSearching)
    }

    func testClearSearchResetsState() {
        let appState = AppState()
        // Manually set some state to verify clear works
        appState.isSearching = true
        appState.clearSearch()

        XCTAssertTrue(appState.searchResults.isEmpty)
        XCTAssertFalse(appState.isSearching)
    }

    func testPerformSearchWithEmptyQuery() {
        let appState = AppState()
        appState.performSearch(query: "")

        XCTAssertTrue(appState.searchResults.isEmpty)
        XCTAssertFalse(appState.isSearching)
    }

    func testPerformSearchWithWhitespaceQuery() {
        let appState = AppState()
        appState.performSearch(query: "   ")

        XCTAssertTrue(appState.searchResults.isEmpty)
        XCTAssertFalse(appState.isSearching)
    }
}

// MARK: - AppState Onboarding Tests

final class AppStateOnboardingTests: XCTestCase {

    override func tearDown() {
        // Clean up UserDefaults key after each test
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        super.tearDown()
    }

    func testCompleteOnboardingSetsFlag() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        let appState = AppState()
        XCTAssertFalse(appState.hasCompletedOnboarding)

        appState.completeOnboarding()

        XCTAssertTrue(appState.hasCompletedOnboarding)
    }

    func testCompleteOnboardingPersistsToUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        let appState = AppState()
        appState.completeOnboarding()

        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }

    func testOnboardingStateReadsFromUserDefaults() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        let appState = AppState()

        XCTAssertTrue(appState.hasCompletedOnboarding)
    }
}

// MARK: - FTS5 Search Integration Tests

/// Tests that performSearch actually queries the DataStore and returns unified results.
final class FTSSearchIntegrationTests: DatabaseTestCase {

    func testSearchActivityEntriesReturnsResults() throws {
        // Insert test data
        let activity = makeActivity(
            appName: "Xcode",
            title: "Building SwiftUI views",
            summary: "Worked on the new settings panel with SwiftUI",
            category: "Development"
        )
        try dataStore.insertActivityEntry(activity)

        // Verify FTS5 search works
        let results = try dataStore.searchActivityEntries(query: "SwiftUI", limit: 50)
        XCTAssertFalse(results.isEmpty, "FTS5 should find 'SwiftUI' in activity entries")
        XCTAssertEqual(results.first?.appName, "Xcode")
    }

    func testSearchDailySummariesReturnsResults() throws {
        let summary = makeDailySummary(
            aiSummary: "Highly productive coding day focused on database integration",
            productivityScore: 0.85
        )
        try dataStore.upsertDailySummary(summary)

        let results = try dataStore.searchDailySummaries(query: "database", limit: 20)
        XCTAssertFalse(results.isEmpty, "FTS5 should find 'database' in daily summaries")
    }

    func testSearchCapturesReturnsResults() throws {
        let capture = makeCapture(
            appName: "Safari",
            windowTitle: "Apple Developer Documentation",
            ocrText: "SwiftUI framework reference and API documentation"
        )
        try dataStore.insertCapture(capture)

        let results = try dataStore.searchCaptures(query: "framework", limit: 30)
        XCTAssertFalse(results.isEmpty, "FTS5 should find 'framework' in capture OCR text")
    }

    func testSearchReturnsEmptyForNoMatch() throws {
        let activity = makeActivity(title: "Regular coding", summary: "Fixed a bug")
        try dataStore.insertActivityEntry(activity)

        let results = try dataStore.searchActivityEntries(query: "xyznonexistent123", limit: 50)
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchRespectsLimit() throws {
        // Insert multiple activities
        for i in 0..<10 {
            let activity = makeActivity(
                title: "SwiftUI task \(i)",
                summary: "Working on SwiftUI component \(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 60))
            )
            try dataStore.insertActivityEntry(activity)
        }

        let results = try dataStore.searchActivityEntries(query: "SwiftUI", limit: 3)
        XCTAssertEqual(results.count, 3, "Should respect the limit parameter")
    }

    // Helper to create a daily summary record
    func makeDailySummary(
        date: Date = Date(),
        aiSummary: String = "A productive day",
        activityCount: Int = 10,
        productivityScore: Double = 0.7
    ) -> DailySummaryRecord {
        DailySummaryRecord(
            date: date,
            totalScreenTime: 28800,
            aiSummary: aiSummary,
            activityCount: activityCount,
            productivityScore: productivityScore
        )
    }
}

// MARK: - SidebarTab Tests (regression)

final class SidebarTabTests: XCTestCase {

    func testSidebarTabCaseCount() {
        XCTAssertEqual(SidebarTab.allCases.count, 4)
    }

    func testSidebarTabIcons() {
        XCTAssertEqual(SidebarTab.today.icon, "sun.max.fill")
        XCTAssertEqual(SidebarTab.history.icon, "clock.arrow.circlepath")
        XCTAssertEqual(SidebarTab.insights.icon, "chart.bar.fill")
        XCTAssertEqual(SidebarTab.settings.icon, "gearshape.fill")
    }

    func testSidebarTabIds() {
        XCTAssertEqual(SidebarTab.today.id, "Today")
        XCTAssertEqual(SidebarTab.history.id, "History")
    }
}
