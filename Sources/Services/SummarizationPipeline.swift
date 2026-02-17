import Foundation

// MARK: - Summarization Pipeline

/// Orchestrates the conversion of raw captures into structured activity entries and daily summaries.
///
/// Pipeline flow:
/// 1. **Process captures**: Group recent unprocessed captures by app, classify, and summarize into activity entries.
/// 2. **Update app usage**: Track per-app duration for the day.
/// 3. **Generate daily summary**: Aggregate all activity entries into a coherent daily narrative.
///
/// Runs on a configurable timer (default: every 15 minutes). Can also be triggered manually.
final class SummarizationPipeline {

    // MARK: - Dependencies

    private let dataStore: DataStoreProtocol
    private let classifier: ActivityClassifier
    private let summarizer: SummarizationServiceProtocol
    private let captureStorage: CaptureStorageServiceProtocol
    var deleteScreenshotsAfterSummarize: Bool = false

    // MARK: - Configuration

    /// How often the pipeline runs, in seconds. Default: 15 minutes.
    var pipelineIntervalSeconds: TimeInterval = 15 * 60

    /// Minimum number of captures needed before generating activity entries.
    var minimumCapturesForProcessing: Int = 3

    // MARK: - Internal State

    private var timer: Timer?
    private var lastProcessedTimestamp: Date?
    private let pipelineQueue = DispatchQueue(label: "com.eval.summarization", qos: .utility)

    // MARK: - Init

    init(
        dataStore: DataStoreProtocol,
        classifier: ActivityClassifier = ActivityClassifier(),
        summarizer: SummarizationServiceProtocol = HeuristicSummarizer(),
        captureStorage: CaptureStorageServiceProtocol = CaptureStorageService()
    ) {
        self.dataStore = dataStore
        self.classifier = classifier
        self.summarizer = summarizer
        self.captureStorage = captureStorage
    }

    // MARK: - Lifecycle

    /// Start the pipeline timer. Runs processing at the configured interval.
    func start() {
        stop()
        scheduleTimer()
    }

    /// Stop the pipeline timer.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Manually trigger a pipeline run (e.g., on app exit or when refreshing views).
    func runNow() {
        pipelineQueue.async { [weak self] in
            self?.processPipeline()
        }
    }

    // MARK: - Timer

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: pipelineIntervalSeconds, repeats: true) { [weak self] _ in
            self?.pipelineQueue.async {
                self?.processPipeline()
            }
        }
    }

    // MARK: - Core Pipeline

    /// Main pipeline execution. Groups captures → activity entries → daily summary.
    private func processPipeline() {
        let perfLogger = PerformanceLogger.shared
        let pipelineToken = perfLogger.startMeasurement(.summarization, label: "full_pipeline")

        do {
            let now = Date()
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: now)

            // 1. Fetch today's unprocessed captures (since last processed or start of day)
            let fetchStart = lastProcessedTimestamp ?? todayStart
            let captures = try perfLogger.measure(.dbRead, label: "fetch_captures_for_pipeline") {
                try dataStore.fetchCaptures(from: fetchStart, to: now)
            }

            if captures.count >= minimumCapturesForProcessing {
                // 2. Group captures by app name
                let grouped = groupCapturesByApp(captures)

                // 3. Convert each group into an activity entry
                for (appName, appCaptures) in grouped {
                    let entry = perfLogger.measure(.summarization, label: "classify_and_summarize") {
                        createActivityEntry(appName: appName, captures: appCaptures)
                    }
                    try perfLogger.measure(.dbWrite, label: "insert_activity_entry") {
                        try dataStore.insertActivityEntry(entry)
                    }

                    // 4. Update app usage for today
                    let appUsage = AppUsageRecord(
                        date: todayStart,
                        appName: entry.appName,
                        appIcon: entry.appIcon,
                        duration: entry.duration,
                        category: entry.category
                    )
                    try perfLogger.measure(.dbWrite, label: "upsert_app_usage") {
                        try dataStore.upsertAppUsage(appUsage)
                    }

                    if deleteScreenshotsAfterSummarize {
                        deleteCaptureImages(appCaptures)
                    }
                }

                lastProcessedTimestamp = now
            }

            // 5. Generate/update daily summary
            try perfLogger.measure(.summarization, label: "generate_daily_summary") {
                try generateDailySummary(for: now)
            }

        } catch {
            print("[Eval] Summarization pipeline error: \(error)")
        }

        perfLogger.endMeasurement(pipelineToken)
        perfLogger.takeMemorySnapshot()
    }

    // MARK: - Grouping

    /// Group captures by app name. Adjacent captures of the same app are combined.
    private func groupCapturesByApp(_ captures: [CaptureRecord]) -> [(String, [CaptureRecord])] {
        guard !captures.isEmpty else { return [] }

        // Sort by timestamp ascending for chronological grouping
        let sorted = captures.sorted { $0.timestamp < $1.timestamp }

        var groups: [(String, [CaptureRecord])] = []
        var currentApp = sorted[0].appName
        var currentGroup: [CaptureRecord] = [sorted[0]]

        for capture in sorted.dropFirst() {
            if capture.appName == currentApp {
                currentGroup.append(capture)
            } else {
                groups.append((currentApp, currentGroup))
                currentApp = capture.appName
                currentGroup = [capture]
            }
        }
        groups.append((currentApp, currentGroup))

        return groups
    }

    // MARK: - Activity Entry Creation

    /// Create an ActivityEntryRecord from a group of captures for the same app.
    private func createActivityEntry(appName: String, captures: [CaptureRecord]) -> ActivityEntryRecord {
        guard let first = captures.first, let last = captures.last else {
            fatalError("createActivityEntry called with empty captures")
        }

        // Representative capture: use the one with the most OCR text
        let representative = captures.max(by: {
            ($0.ocrText?.count ?? 0) < ($1.ocrText?.count ?? 0)
        }) ?? first

        // Classify
        let category = classifier.classify(
            appName: appName,
            bundleIdentifier: representative.bundleIdentifier,
            windowTitle: representative.windowTitle,
            ocrText: representative.ocrText
        )

        // Calculate duration from first to last capture timestamp
        let duration = max(last.timestamp.timeIntervalSince(first.timestamp), TimeInterval(captures.count * 30))

        // Get icon
        let icon = classifier.iconForApp(appName)

        // Window title for context
        let windowTitle = representative.windowTitle

        // Generate summary
        let summary = summarizer.summarizeActivity(
            appName: appName,
            windowTitle: windowTitle,
            ocrText: representative.ocrText,
            category: category,
            duration: duration
        )

        return ActivityEntryRecord(
            timestamp: first.timestamp,
            appName: appName,
            appIcon: icon,
            title: windowTitle.isEmpty ? appName : truncateTitle(windowTitle),
            summary: summary,
            category: category.rawValue,
            duration: duration
        )
    }

    // MARK: - Daily Summary

    /// Generate or update the daily summary for the given date.
    private func generateDailySummary(for date: Date) throws {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: date)

        // Fetch all of today's activity entries
        let entryRecords = try dataStore.fetchActivityEntries(for: date)
        let entries = entryRecords.map { $0.toActivityEntry() }

        guard !entries.isEmpty else { return }

        // Calculate total screen time from app usage
        let totalScreenTime = try dataStore.totalScreenTime(for: date)

        // Fetch top apps
        let topAppRecords = try dataStore.fetchAppUsage(for: date)
        let topApps = topAppRecords.map { $0.toAppUsage() }

        // Calculate productivity score
        let activitiesForScoring = entries.map { (category: $0.category, duration: $0.duration) }
        let productivityScore = classifier.estimateProductivityScore(activities: activitiesForScoring)

        // Generate AI summary
        let aiSummary = summarizer.summarizeDay(
            entries: entries,
            totalScreenTime: totalScreenTime,
            topApps: topApps,
            productivityScore: productivityScore
        )

        // Upsert the daily summary
        let summaryRecord = DailySummaryRecord(
            date: todayStart,
            totalScreenTime: totalScreenTime,
            aiSummary: aiSummary,
            activityCount: entries.count,
            productivityScore: productivityScore
        )
        try dataStore.upsertDailySummary(summaryRecord)
    }

    private func deleteCaptureImages(_ captures: [CaptureRecord]) {
        for capture in captures {
            do {
                try captureStorage.deleteImage(at: capture.imagePath)
            } catch {
                print("[Eval] Failed to delete capture image: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func truncateTitle(_ title: String, maxLength: Int = 80) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= maxLength { return cleaned }
        return String(cleaned.prefix(maxLength)) + "..."
    }
}
