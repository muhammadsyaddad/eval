import XCTest
@testable import Eval
import GRDB

// MARK: - Activity Classifier Tests

final class ActivityClassifierTests: XCTestCase {

    let classifier = ActivityClassifier()

    // MARK: - Bundle ID Classification

    func testClassifyXcodeByBundleID() {
        let result = classifier.classify(
            appName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: "MyProject.swift",
            ocrText: nil
        )
        XCTAssertEqual(result, .development)
    }

    func testClassifyVSCodeByBundleID() {
        let result = classifier.classify(
            appName: "Visual Studio Code",
            bundleIdentifier: "com.microsoft.VSCode",
            windowTitle: "index.ts",
            ocrText: nil
        )
        XCTAssertEqual(result, .development)
    }

    func testClassifySafariByBundleID() {
        let result = classifier.classify(
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            windowTitle: "Apple",
            ocrText: nil
        )
        XCTAssertEqual(result, .browsing)
    }

    func testClassifySlackByBundleID() {
        let result = classifier.classify(
            appName: "Slack",
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            windowTitle: "#general",
            ocrText: nil
        )
        XCTAssertEqual(result, .communication)
    }

    func testClassifyFigmaByBundleID() {
        let result = classifier.classify(
            appName: "Figma",
            bundleIdentifier: "com.figma.Desktop",
            windowTitle: "Design System",
            ocrText: nil
        )
        XCTAssertEqual(result, .design)
    }

    func testClassifyObsidianByBundleID() {
        let result = classifier.classify(
            appName: "Obsidian",
            bundleIdentifier: "md.obsidian",
            windowTitle: "Daily Notes",
            ocrText: nil
        )
        XCTAssertEqual(result, .writing)
    }

    func testClassifySpotifyByBundleID() {
        let result = classifier.classify(
            appName: "Spotify",
            bundleIdentifier: "com.spotify.client",
            windowTitle: "Now Playing",
            ocrText: nil
        )
        XCTAssertEqual(result, .entertainment)
    }

    func testClassifyExcelByBundleID() {
        let result = classifier.classify(
            appName: "Microsoft Excel",
            bundleIdentifier: "com.microsoft.Excel",
            windowTitle: "Budget.xlsx",
            ocrText: nil
        )
        XCTAssertEqual(result, .productivity)
    }

    // MARK: - App Name Classification

    func testClassifyTerminalByAppName() {
        let result = classifier.classify(
            appName: "Terminal",
            bundleIdentifier: "unknown.bundle",
            windowTitle: "bash",
            ocrText: nil
        )
        XCTAssertEqual(result, .development)
    }

    func testClassifyDiscordByAppName() {
        let result = classifier.classify(
            appName: "Discord",
            bundleIdentifier: "unknown.bundle",
            windowTitle: "Server",
            ocrText: nil
        )
        XCTAssertEqual(result, .communication)
    }

    // MARK: - Window Title Classification

    func testClassifySwiftFileByWindowTitle() {
        let result = classifier.classify(
            appName: "UnknownEditor",
            bundleIdentifier: "com.unknown.editor",
            windowTitle: "ContentView.swift — Eval",
            ocrText: nil
        )
        XCTAssertEqual(result, .development)
    }

    func testClassifyGitHubByWindowTitle() {
        let result = classifier.classify(
            appName: "UnknownBrowser",
            bundleIdentifier: "com.unknown.browser",
            windowTitle: "Pull Request #42 - github.com",
            ocrText: nil
        )
        XCTAssertEqual(result, .development)
    }

    func testClassifyYouTubeByWindowTitle() {
        let result = classifier.classify(
            appName: "UnknownBrowser",
            bundleIdentifier: "com.unknown.browser",
            windowTitle: "How to Cook Pasta - YouTube",
            ocrText: nil
        )
        XCTAssertEqual(result, .entertainment)
    }

    func testClassifyInboxByWindowTitle() {
        let result = classifier.classify(
            appName: "UnknownApp",
            bundleIdentifier: "com.unknown.app",
            windowTitle: "Inbox (42) - Mail",
            ocrText: nil
        )
        XCTAssertEqual(result, .communication)
    }

    // MARK: - OCR Text Classification

    func testClassifyByOCRTextDevelopment() {
        let ocrText = """
        import Foundation
        func calculateTotal() -> Double {
            let items = fetchItems()
            return items.map { $0.price }.reduce(0, +)
        }
        """
        let result = classifier.classify(
            appName: "Unknown",
            bundleIdentifier: "com.unknown",
            windowTitle: "",
            ocrText: ocrText
        )
        XCTAssertEqual(result, .development)
    }

    func testClassifyByOCRTextCommunication() {
        let ocrText = """
        From: john@example.com
        To: jane@example.com
        Subject: Meeting Tomorrow
        Hi Jane, please reply to confirm the meeting.
        You have 5 new notifications in your inbox.
        """
        let result = classifier.classify(
            appName: "Unknown",
            bundleIdentifier: "com.unknown",
            windowTitle: "",
            ocrText: ocrText
        )
        XCTAssertEqual(result, .communication)
    }

    func testClassifyUnknownAppReturnsOther() {
        let result = classifier.classify(
            appName: "SomeRandomApp",
            bundleIdentifier: "com.random.app",
            windowTitle: "",
            ocrText: nil
        )
        XCTAssertEqual(result, .other)
    }

    func testClassifyShortOCRTextIgnored() {
        // OCR text with <= 3 words should be ignored
        let result = classifier.classify(
            appName: "Unknown",
            bundleIdentifier: "com.unknown",
            windowTitle: "",
            ocrText: "import func"
        )
        XCTAssertEqual(result, .other)
    }

    // MARK: - Icon Resolution

    func testIconForBrowserApp() {
        XCTAssertEqual(classifier.iconForApp("Safari"), "globe")
        XCTAssertEqual(classifier.iconForApp("Google Chrome"), "globe")
    }

    func testIconForDevApp() {
        XCTAssertEqual(classifier.iconForApp("Xcode"), "chevron.left.forwardslash.chevron.right")
        XCTAssertEqual(classifier.iconForApp("Terminal"), "chevron.left.forwardslash.chevron.right")
    }

    func testIconForUnknownApp() {
        XCTAssertEqual(classifier.iconForApp("MyCustomApp"), "app.fill")
    }

    // MARK: - Productivity Score

    func testProductivityScoreAllDev() {
        let activities: [(category: ActivityCategory, duration: TimeInterval)] = [
            (.development, 3600),
            (.development, 1800)
        ]
        let score = classifier.estimateProductivityScore(activities: activities)
        XCTAssertEqual(score, 0.95, accuracy: 0.01)
    }

    func testProductivityScoreMixed() {
        let activities: [(category: ActivityCategory, duration: TimeInterval)] = [
            (.development, 3600),    // 50%
            (.entertainment, 3600)   // 50%
        ]
        let score = classifier.estimateProductivityScore(activities: activities)
        // (0.95 * 0.5 + 0.10 * 0.5) = 0.525
        XCTAssertEqual(score, 0.525, accuracy: 0.01)
    }

    func testProductivityScoreEmpty() {
        let score = classifier.estimateProductivityScore(activities: [])
        XCTAssertEqual(score, 0.0)
    }

    func testProductivityScoreAllEntertainment() {
        let activities: [(category: ActivityCategory, duration: TimeInterval)] = [
            (.entertainment, 7200)
        ]
        let score = classifier.estimateProductivityScore(activities: activities)
        XCTAssertEqual(score, 0.10, accuracy: 0.01)
    }
}

// MARK: - Heuristic Summarizer Tests

final class HeuristicSummarizerTests: XCTestCase {

    let summarizer = HeuristicSummarizer()

    // MARK: - Activity Summary

    func testActivitySummaryDevelopment() {
        let summary = summarizer.summarizeActivity(
            appName: "Xcode",
            windowTitle: "ContentView.swift — Eval",
            ocrText: nil,
            category: .development,
            duration: 1800
        )
        XCTAssertTrue(summary.contains("Xcode"), "Summary should mention the app name")
        XCTAssertTrue(summary.contains("30m"), "Summary should mention the duration")
    }

    func testActivitySummaryBrowsing() {
        let summary = summarizer.summarizeActivity(
            appName: "Safari",
            windowTitle: "Swift Package Manager Documentation",
            ocrText: nil,
            category: .browsing,
            duration: 600
        )
        XCTAssertTrue(summary.contains("Safari"), "Summary should mention browser name")
        XCTAssertTrue(summary.contains("Swift Package Manager"), "Summary should include page title")
    }

    func testActivitySummaryTerminalWithOCR() {
        let summary = summarizer.summarizeActivity(
            appName: "Terminal",
            windowTitle: "bash",
            ocrText: "$ git push origin main\n$ npm run build\nBuild successful",
            category: .development,
            duration: 900
        )
        XCTAssertTrue(summary.contains("terminal") || summary.contains("Terminal"),
                      "Summary should reference terminal work")
    }

    func testActivitySummaryEmptyWindowTitle() {
        let summary = summarizer.summarizeActivity(
            appName: "Figma",
            windowTitle: "",
            ocrText: nil,
            category: .design,
            duration: 3600
        )
        XCTAssertTrue(summary.contains("Figma"), "Summary should mention app name")
        XCTAssertTrue(summary.contains("1h"), "Summary should mention 1 hour duration")
    }

    func testActivitySummaryShortDuration() {
        let summary = summarizer.summarizeActivity(
            appName: "Slack",
            windowTitle: "#general",
            ocrText: nil,
            category: .communication,
            duration: 45
        )
        XCTAssertTrue(summary.contains("45s"), "Summary should show seconds for short durations")
    }

    func testActivitySummaryLongDuration() {
        let summary = summarizer.summarizeActivity(
            appName: "Xcode",
            windowTitle: "Project.swift",
            ocrText: nil,
            category: .development,
            duration: 7380 // 2h 3m
        )
        XCTAssertTrue(summary.contains("2h 3m"), "Summary should show hours and minutes")
    }

    // MARK: - Daily Summary

    func testDailySummaryWithEntries() {
        let entries = [
            ActivityEntry(timestamp: Date(), appName: "Xcode", appIcon: "hammer", title: "Coding",
                         summary: "Working", category: .development, duration: 7200),
            ActivityEntry(timestamp: Date(), appName: "Slack", appIcon: "message", title: "Chat",
                         summary: "Chatting", category: .communication, duration: 1800),
            ActivityEntry(timestamp: Date(), appName: "Safari", appIcon: "globe", title: "Browsing",
                         summary: "Browsing", category: .browsing, duration: 900)
        ]
        let topApps = [
            AppUsage(appName: "Xcode", appIcon: "hammer", duration: 7200, category: .development),
            AppUsage(appName: "Slack", appIcon: "message", duration: 1800, category: .communication)
        ]

        let summary = summarizer.summarizeDay(
            entries: entries,
            totalScreenTime: 9900,
            topApps: topApps,
            productivityScore: 0.78
        )

        XCTAssertTrue(summary.contains("2h"), "Should mention screen time in hours")
        XCTAssertTrue(summary.contains("3 activities"), "Should mention activity count")
        XCTAssertTrue(summary.contains("Xcode"), "Should mention top app")
        XCTAssertTrue(summary.contains("78%"), "Should mention productivity percentage")
    }

    func testDailySummaryNoEntries() {
        let summary = summarizer.summarizeDay(
            entries: [],
            totalScreenTime: 0,
            topApps: [],
            productivityScore: 0
        )
        XCTAssertEqual(summary, "No activity recorded today.")
    }

    func testDailySummaryHighProductivity() {
        let entries = [
            ActivityEntry(timestamp: Date(), appName: "Xcode", appIcon: "hammer", title: "Dev",
                         summary: "Dev", category: .development, duration: 14400)
        ]
        let summary = summarizer.summarizeDay(
            entries: entries,
            totalScreenTime: 14400,
            topApps: [],
            productivityScore: 0.92
        )
        XCTAssertTrue(summary.contains("highly focused"), "High productivity should be praised")
    }

    func testDailySummaryLowProductivity() {
        let entries = [
            ActivityEntry(timestamp: Date(), appName: "Netflix", appIcon: "play", title: "Watch",
                         summary: "Watching", category: .entertainment, duration: 7200)
        ]
        let summary = summarizer.summarizeDay(
            entries: entries,
            totalScreenTime: 7200,
            topApps: [],
            productivityScore: 0.10
        )
        XCTAssertTrue(summary.contains("leisure") || summary.contains("non-work"),
                      "Low productivity should be noted")
    }

    // MARK: - Backend Properties

    func testBackendName() {
        XCTAssertEqual(summarizer.backendName, "Heuristic Engine")
    }

    func testIsReady() {
        XCTAssertTrue(summarizer.isReady)
    }
}

// MARK: - Summarization Pipeline Tests

/// Tests for the SummarizationPipeline, using a real GRDB database (temp file).
final class SummarizationPipelineTests: XCTestCase {

    var dbManager: DatabaseManager!
    var dataStore: DataStore!
    var pipeline: SummarizationPipeline!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("eval_pipeline_test_\(UUID().uuidString).db")
        dbManager = try DatabaseManager(databaseURL: tmpURL)
        dataStore = DataStore(databaseManager: dbManager)
        pipeline = SummarizationPipeline(dataStore: dataStore)
    }

    override func tearDownWithError() throws {
        pipeline.stop()
        try? FileManager.default.removeItem(at: dbManager.databaseURL)
        pipeline = nil
        dataStore = nil
        dbManager = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func insertCaptures(count: Int, appName: String = "Xcode", bundleID: String = "com.apple.dt.Xcode", windowTitle: String = "Project.swift") throws {
        let now = Date()
        for i in 0..<count {
            let capture = CaptureRecord(
                timestamp: now.addingTimeInterval(TimeInterval(-count + i) * 30),
                appName: appName,
                bundleIdentifier: bundleID,
                windowTitle: windowTitle,
                imagePath: "2026-02-08/\(UUID().uuidString).png",
                ocrText: "import Foundation\nfunc test() { return }",
                ocrConfidence: 0.9
            )
            try dataStore.insertCapture(capture)
        }
    }

    // MARK: - Pipeline Processing

    func testPipelineCreatesActivityEntries() throws {
        // Insert enough captures to trigger processing
        try insertCaptures(count: 5)

        // Set minimum low for test
        pipeline.minimumCapturesForProcessing = 3

        // Run pipeline synchronously
        pipeline.runNow()

        // Wait for background processing
        let expectation = XCTestExpectation(description: "Pipeline processes captures")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        // Check that activity entries were created
        let entries = try dataStore.fetchActivityEntries(for: Date())
        XCTAssertFalse(entries.isEmpty, "Pipeline should create activity entries from captures")
    }

    func testPipelineCreatesActivityEntriesWithCorrectCategory() throws {
        try insertCaptures(count: 5, appName: "Xcode", bundleID: "com.apple.dt.Xcode")

        pipeline.minimumCapturesForProcessing = 3
        pipeline.runNow()

        let expectation = XCTestExpectation(description: "Pipeline processes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { expectation.fulfill() }
        wait(for: [expectation], timeout: 5.0)

        let entries = try dataStore.fetchActivityEntries(for: Date())
        if let first = entries.first {
            XCTAssertEqual(first.category, "Development", "Xcode should be classified as Development")
        }
    }

    func testPipelineUpdatesAppUsage() throws {
        try insertCaptures(count: 5)

        pipeline.minimumCapturesForProcessing = 3
        pipeline.runNow()

        let expectation = XCTestExpectation(description: "Pipeline processes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { expectation.fulfill() }
        wait(for: [expectation], timeout: 5.0)

        let appUsage = try dataStore.fetchAppUsage(for: Date())
        XCTAssertFalse(appUsage.isEmpty, "Pipeline should create app usage records")
        if let xcode = appUsage.first(where: { $0.appName == "Xcode" }) {
            XCTAssertGreaterThan(xcode.duration, 0, "App usage should have positive duration")
        }
    }

    func testPipelineGeneratesDailySummary() throws {
        try insertCaptures(count: 5)

        pipeline.minimumCapturesForProcessing = 3
        pipeline.runNow()

        let expectation = XCTestExpectation(description: "Pipeline processes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { expectation.fulfill() }
        wait(for: [expectation], timeout: 5.0)

        let summary = try dataStore.fetchDailySummary(for: Date())
        XCTAssertNotNil(summary, "Pipeline should generate a daily summary")
        if let s = summary {
            XCTAssertGreaterThan(s.activityCount, 0, "Summary should have activity count")
            XCTAssertFalse(s.aiSummary.isEmpty, "Summary should have text")
        }
    }

    func testPipelineSkipsWhenTooFewCaptures() throws {
        // Insert only 1 capture (less than minimum of 3)
        try insertCaptures(count: 1)

        pipeline.minimumCapturesForProcessing = 3
        pipeline.runNow()

        let expectation = XCTestExpectation(description: "Pipeline processes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { expectation.fulfill() }
        wait(for: [expectation], timeout: 5.0)

        let entries = try dataStore.fetchActivityEntries(for: Date())
        XCTAssertTrue(entries.isEmpty, "Pipeline should not create entries with too few captures")
    }

    func testPipelineGroupsMultipleApps() throws {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        // Insert captures for two different apps with timestamps clearly within today
        // Use timestamps starting from the beginning of the day to avoid fetchCaptures range issues
        let baseTime = startOfToday.addingTimeInterval(3600) // 1 hour into the day
        for i in 0..<3 {
            let capture = CaptureRecord(
                timestamp: baseTime.addingTimeInterval(TimeInterval(i) * 30),
                appName: "Xcode",
                bundleIdentifier: "com.apple.dt.Xcode",
                windowTitle: "Main.swift",
                imagePath: "2026-02-08/\(UUID().uuidString).png"
            )
            try dataStore.insertCapture(capture)
        }
        for i in 3..<6 {
            let capture = CaptureRecord(
                timestamp: baseTime.addingTimeInterval(TimeInterval(i) * 30),
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                windowTitle: "Apple Developer",
                imagePath: "2026-02-08/\(UUID().uuidString).png"
            )
            try dataStore.insertCapture(capture)
        }

        pipeline.minimumCapturesForProcessing = 3
        pipeline.runNow()

        let expectation = XCTestExpectation(description: "Pipeline processes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { expectation.fulfill() }
        wait(for: [expectation], timeout: 5.0)

        let entries = try dataStore.fetchActivityEntries(for: now)
        let appNames = Set(entries.map(\.appName))
        XCTAssertTrue(appNames.contains("Xcode"), "Should have Xcode entry, got: \(appNames)")
        XCTAssertTrue(appNames.contains("Safari"), "Should have Safari entry, got: \(appNames)")
    }

    func testPipelineDailySummaryContainsProductivityScore() throws {
        try insertCaptures(count: 5)

        pipeline.minimumCapturesForProcessing = 3
        pipeline.runNow()

        let expectation = XCTestExpectation(description: "Pipeline processes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { expectation.fulfill() }
        wait(for: [expectation], timeout: 5.0)

        let summary = try dataStore.fetchDailySummary(for: Date())
        XCTAssertNotNil(summary)
        if let s = summary {
            XCTAssertGreaterThanOrEqual(s.productivityScore, 0.0)
            XCTAssertLessThanOrEqual(s.productivityScore, 1.0)
        }
    }
}
