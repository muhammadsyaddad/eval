import SwiftUI

// MARK: - App State

class AppState: ObservableObject {
    @Published var selectedTab: SidebarTab = .today

    // MARK: - Data (M3)
    /// Published data for views to bind to. Loaded from DataStore on refresh.
    @Published var todaySummary: DaySummary
    @Published var todayActivities: [ActivityEntry] = []
    @Published var historySummaries: [DaySummary] = []
    @Published var weeklyInsight: WeeklyInsight

    @Published var settings = AppSettings()

    // MARK: - Search (M6)
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching: Bool = false

    // MARK: - Error Handling (M6)
    @Published var currentError: AppError?
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    // MARK: - Privacy & Security (M7)
    @Published var isClearingData: Bool = false
    @Published var fileVaultEnabled: Bool = false

    // MARK: - Services (M1)
    let captureScheduler: CaptureScheduler
    let permissionManager: PermissionManager

    // MARK: - Database (M3)
    let databaseManager: DatabaseManager?
    let dataStore: DataStore?
    let retentionService: DataRetentionService?
    let exportService: ExportService?

    // MARK: - Summarization (M4)
    let summarizationPipeline: SummarizationPipeline?
    let summarizer: SummarizationServiceProtocol
    let activityClassifier: ActivityClassifier

    // MARK: - Security (M7)
    let securityService: SecurityService
    let captureStorageService: CaptureStorageService

    private func emptyWeeklyInsight() -> WeeklyInsight {
        WeeklyInsight.empty()
    }

    init() {
        let permissions = PermissionManager()
        self.permissionManager = permissions
        self.captureScheduler = CaptureScheduler(permissionManager: permissions)

        // M7: Initialize security service
        let security = SecurityService()
        self.securityService = security
        self.captureStorageService = CaptureStorageService()

        // Initialize empty data defaults (will be overwritten by loadData if DB has content)
        self.todaySummary = DaySummary.empty()
        self.todayActivities = []
        self.historySummaries = []
        self.weeklyInsight = WeeklyInsight.empty()

        // M4: Initialize summarization services (always available, no model dependency)
        let classifier = ActivityClassifier()
        let summarizer = HeuristicSummarizer()
        self.activityClassifier = classifier
        self.summarizer = summarizer

        // Initialize database (gracefully handle failures)
        do {
            let dbManager = try DatabaseManager()
            self.databaseManager = dbManager
            let store = DataStore(databaseManager: dbManager)
            self.dataStore = store
            self.exportService = ExportService(dataStore: store)
            self.retentionService = DataRetentionService(
                dataStore: store,
                captureStorage: CaptureStorageService(),
                databaseManager: dbManager,
                policy: RetentionPolicy()  // Uses default 5 GB; updated by applySettings()
            )
            // M4: Create summarization pipeline wired to the DataStore
            self.summarizationPipeline = SummarizationPipeline(
                dataStore: store,
                classifier: classifier,
                summarizer: summarizer,
                captureStorage: captureStorageService
            )
            self.summarizationPipeline?.deleteScreenshotsAfterSummarize = settings.deleteScreenshotsAfterSummarize
        } catch {
            self.databaseManager = nil
            self.dataStore = nil
            self.exportService = nil
            self.retentionService = nil
            self.summarizationPipeline = nil
            print("[MacPulse] Failed to initialize database: \(error). Using empty state.")
        }

        // Load real data from DB (or keep mock defaults)
        loadData()

        // M4: Wire capture callback to store captures in the DataStore
        captureScheduler.onCapture = { [weak self] result, imagePath in
            self?.storeCapture(result, imagePath: imagePath)
        }

        // M7: Wire permission revocation handler
        permissionManager.onPermissionRevoked = { [weak self] permissionName in
            DispatchQueue.main.async {
                self?.showError(
                    title: "\(permissionName) Permission Revoked",
                    message: "MacPulse requires \(permissionName) permission to function. Please re-enable it in System Settings > Privacy & Security.",
                    severity: .error
                )
                // Stop capture if screen recording was revoked
                if permissionName == "Screen Recording" {
                    self?.captureScheduler.stop()
                }
            }
        }

        // M7: Start periodic permission re-checks
        permissionManager.startPeriodicRecheck()

        // M7: Check FileVault status
        fileVaultEnabled = security.isFileVaultEnabled()
    }

    /// Start capture with current settings applied.
    func startCapture() {
        captureScheduler.updateInterval(settings.captureIntervalSeconds)
        captureScheduler.updateExclusions(appNames: settings.excludedApps)
        captureScheduler.updateOCREnabled(settings.ocrEnabled)
        captureScheduler.start()

        // M4: Start the summarization pipeline alongside capture
        summarizationPipeline?.start()
    }

    /// Sync settings changes to the scheduler.
    func applySettings() {
        captureScheduler.updateInterval(settings.captureIntervalSeconds)
        captureScheduler.updateExclusions(appNames: settings.excludedApps)
        captureScheduler.updateOCREnabled(settings.ocrEnabled)

        summarizationPipeline?.deleteScreenshotsAfterSummarize = settings.deleteScreenshotsAfterSummarize

        // Update retention policy with new storage limit
        retentionService?.policy.storageLimitBytes = UInt64(settings.storageLimitGB * 1024 * 1024 * 1024)
    }

    /// Stop capture and summarization.
    func stopCapture() {
        captureScheduler.stop()
        summarizationPipeline?.stop()
    }

    /// Trigger the summarization pipeline immediately and refresh view data.
    func refreshSummaries() {
        summarizationPipeline?.runNow()
        // Give the pipeline a moment to process, then reload
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.loadData()
        }
    }

    // MARK: - Data Loading (M3)

    /// Load data from the DataStore. Keeps empty state if the store is empty or unavailable.
    func loadData() {
        guard let store = dataStore else { return }

        do {
            // Load today's data
            let now = Date()
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: now)

            // Today's activity entries
            let todayEntryRecords = try store.fetchActivityEntries(for: now)
            todayActivities = todayEntryRecords.map { $0.toActivityEntry() }

            // Today's summary
            if let summaryRecord = try store.fetchDailySummary(for: now) {
                let appUsageRecords = try store.fetchAppUsage(for: now)
                let topApps = appUsageRecords.map { $0.toAppUsage() }
                todaySummary = summaryRecord.toDaySummary(topApps: topApps)
            } else {
                todaySummary = DaySummary.empty(date: now)
            }

            // History summaries
            let allSummaryRecords = try store.fetchAllDailySummaries()
            historySummaries = try allSummaryRecords.map { record in
                let appUsageRecords = try store.fetchAppUsage(for: record.date)
                let topApps = appUsageRecords.map { $0.toAppUsage() }
                return record.toDaySummary(topApps: topApps)
            }

            // Weekly insight
            let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart)!
            let dailyTotals = try store.dailyScreenTimeTotals(from: weekStart, to: todayStart)
            let categoryData = try store.categoryBreakdown(from: weekStart, to: todayStart)
            let topAppsRecords = try store.fetchTopApps(from: weekStart, to: todayStart, limit: 5)

            if !dailyTotals.isEmpty {
                let dailyMetrics = dailyTotals.map { DailyMetric(date: $0.date, value: $0.totalSeconds / 3600) }

                let totalHours = categoryData.values.reduce(0, +) / 3600
                let categoryMetrics = categoryData.map { (key, value) in
                    let hours = value / 3600
                    let pct = totalHours > 0 ? hours / totalHours : 0
                    return CategoryMetric(
                        category: ActivityCategory(rawValue: key) ?? .other,
                        hours: hours,
                        percentage: pct
                    )
                }.sorted { $0.hours > $1.hours }

                let topApps = topAppsRecords.map { $0.toAppUsage() }

                // Calculate average productivity from summaries this week
                let weekSummaries = try store.fetchDailySummaries(from: weekStart, to: todayStart)
                let avgProd = weekSummaries.isEmpty ? 0.0 : weekSummaries.map(\.productivityScore).reduce(0, +) / Double(weekSummaries.count)

                // Determine trend from this week vs previous week
                let prevWeekStart = calendar.date(byAdding: .day, value: -13, to: todayStart)!
                let prevWeekEnd = calendar.date(byAdding: .day, value: -7, to: todayStart)!
                let prevTotalTime = try store.totalScreenTime(from: prevWeekStart, to: prevWeekEnd)
                let thisTotalTime = try store.totalScreenTime(from: weekStart, to: todayStart)

                let trend: TrendDirection
                if thisTotalTime > prevTotalTime * 1.1 {
                    trend = .up
                } else if thisTotalTime < prevTotalTime * 0.9 {
                    trend = .down
                } else {
                    trend = .stable
                }

                weeklyInsight = WeeklyInsight(
                    weekStarting: weekStart,
                    dailyScreenTime: dailyMetrics,
                    categoryBreakdown: categoryMetrics,
                    topApps: topApps,
                    avgProductivityScore: avgProd,
                    trend: trend
                )
            } else {
                weeklyInsight = WeeklyInsight.empty(weekStarting: weekStart)
            }

            // Update storage usage in settings
            if let retention = retentionService {
                let totalBytes = retention.totalStorageBytes()
                settings.currentStorageGB = Double(totalBytes) / (1024 * 1024 * 1024)
            }

        } catch {
            print("[MacPulse] Error loading data from DataStore: \(error). Keeping empty/cached data.")
        }
    }

    /// Insert a capture into the DataStore.
    func storeCapture(_ capture: CaptureResult, imagePath: String) {
        guard let store = dataStore else { return }
        do {
            let record = CaptureRecord(from: capture, imagePath: imagePath)
            try store.insertCapture(record)
            scheduleSummarizationRefresh()
        } catch {
            print("[MacPulse] Failed to store capture: \(error)")
        }
    }

    private func scheduleSummarizationRefresh() {
        guard summarizationPipeline != nil else { return }

        pendingSummarizationRefresh?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.summarizationPipeline?.runNow()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.loadData()
            }
        }
        pendingSummarizationRefresh = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: task)
    }

    /// Run data retention to clean up old data.
    func runRetention() {
        guard let retention = retentionService else { return }
        do {
            let result = try retention.applyRetention()
            if result.totalDeleted > 0 {
                print("[MacPulse] Retention cleaned up \(result.totalDeleted) rows.")
                loadData() // Refresh after cleanup
            }
        } catch {
            print("[MacPulse] Retention error: \(error)")
        }
    }

    // MARK: - Full-Text Search (M6)

    /// Perform a full-text search across activity entries, daily summaries, and captures.
    /// Results are unified into SearchResult models and sorted by date descending.
    func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        guard let store = dataStore else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        // Run search on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var results: [SearchResult] = []

            do {
                // Search activity entries
                let activityRecords = try store.searchActivityEntries(query: query, limit: 50)
                for record in activityRecords {
                    let matchedField: String
                    let snippet: String
                    let lowerQuery = query.lowercased()
                    if record.title.lowercased().contains(lowerQuery) {
                        matchedField = "title"
                        snippet = record.title
                    } else if record.summary.lowercased().contains(lowerQuery) {
                        matchedField = "summary"
                        snippet = record.summary
                    } else {
                        matchedField = "app"
                        snippet = record.summary
                    }

                    results.append(SearchResult(
                        id: UUID(uuidString: record.id) ?? UUID(),
                        date: record.timestamp,
                        title: record.title,
                        snippet: snippet,
                        matchedField: matchedField,
                        source: .activityEntry,
                        appName: record.appName,
                        appIcon: record.appIcon,
                        category: ActivityCategory(rawValue: record.category)
                    ))
                }

                // Search daily summaries
                let summaryRecords = try store.searchDailySummaries(query: query, limit: 20)
                for record in summaryRecords {
                    results.append(SearchResult(
                        date: record.date,
                        title: "Daily Summary",
                        snippet: record.aiSummary,
                        matchedField: "aiSummary",
                        source: .dailySummary
                    ))
                }

                // Search captures (OCR text)
                let captureRecords = try store.searchCaptures(query: query, limit: 30)
                for record in captureRecords {
                    let snippet = record.ocrText ?? record.windowTitle
                    results.append(SearchResult(
                        date: record.timestamp,
                        title: record.windowTitle,
                        snippet: snippet,
                        matchedField: record.ocrText != nil ? "ocrText" : "windowTitle",
                        source: .capture,
                        appName: record.appName
                    ))
                }
            } catch {
                print("[MacPulse] Search error: \(error)")
            }

            // Sort by date descending
            results.sort { $0.date > $1.date }

            DispatchQueue.main.async {
                self?.searchResults = results
                self?.isSearching = false
            }
        }
    }

    /// Clear search results.
    func clearSearch() {
        searchResults = []
        isSearching = false
    }

    // MARK: - Onboarding (M6)

    /// Mark onboarding as completed and persist the flag.
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Error Handling (M6)

    /// Show a user-facing error.
    func showError(title: String, message: String, severity: ErrorSeverity = .warning) {
        currentError = AppError(title: title, message: message, severity: severity)
    }

    /// Dismiss the current error.
    func dismissError() {
        currentError = nil
    }

    // MARK: - Clear All Data (M7)

    /// Orchestrated purge: stop capture -> delete DB rows -> delete capture files ->
    /// vacuum DB -> reset UI state -> clear UserDefaults.
    /// Runs heavy work on a background queue and updates UI on main.
    func clearAllData() {
        guard !isClearingData else { return }
        isClearingData = true

        // 1. Stop capture and summarization immediately
        captureScheduler.stop()
        summarizationPipeline?.stop()
        pendingSummarizationRefresh?.cancel()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var errors: [String] = []

            // 2. Delete all database rows
            if let store = self.dataStore {
                do {
                    try store.deleteAllData()
                } catch {
                    errors.append("Database: \(error.localizedDescription)")
                }
            }

            // 3. Delete all capture files from disk
            do {
                _ = try self.captureStorageService.deleteAllCaptures()
            } catch {
                errors.append("Capture files: \(error.localizedDescription)")
            }

            // 4. Vacuum database to reclaim disk space
            if let dbManager = self.databaseManager {
                do {
                    try dbManager.vacuumDatabase()
                } catch {
                    errors.append("Vacuum: \(error.localizedDescription)")
                }
            }

            // 5. Reset UI state and UserDefaults on main thread
            DispatchQueue.main.async {
                self.todaySummary = DaySummary.empty()
                self.todayActivities = []
                self.historySummaries = []
                self.weeklyInsight = WeeklyInsight.empty()
                self.searchResults = []
                self.isSearching = false
                self.settings.currentStorageGB = 0.0

                // Clear onboarding flag so user sees fresh state description
                // (Intentionally NOT resetting hasCompletedOnboarding — user already knows the app)

                self.isClearingData = false

                if errors.isEmpty {
                    print("[MacPulse] All data cleared successfully.")
                } else {
                    let message = errors.joined(separator: "; ")
                    self.showError(
                        title: "Data Purge Incomplete",
                        message: "Some data could not be deleted: \(message)",
                        severity: .warning
                    )
                }
            }
        }
    }
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case history = "History"
    case insights = "Insights"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .history: return "clock.arrow.circlepath"
        case .insights: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
    private var pendingSummarizationRefresh: DispatchWorkItem?
