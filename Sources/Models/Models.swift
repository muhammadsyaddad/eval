import Foundation

// MARK: - Activity Entry

struct ActivityEntry: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let appName: String
    let appIcon: String       // SF Symbol name
    let title: String
    let summary: String
    let category: ActivityCategory
    let duration: TimeInterval // seconds

    init(
        id: UUID = UUID(),
        timestamp: Date,
        appName: String,
        appIcon: String,
        title: String,
        summary: String,
        category: ActivityCategory,
        duration: TimeInterval
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
}

enum ActivityCategory: String, CaseIterable, Hashable {
    case productivity = "Productivity"
    case communication = "Communication"
    case browsing = "Browsing"
    case entertainment = "Entertainment"
    case development = "Development"
    case design = "Design"
    case writing = "Writing"
    case other = "Other"

    var color: String {
        switch self {
        case .productivity: return "amber"
        case .communication: return "teal"
        case .browsing: return "slate"
        case .entertainment: return "rose"
        case .development: return "emerald"
        case .design: return "violet"
        case .writing: return "sky"
        case .other: return "zinc"
        }
    }
}

// MARK: - Day Summary

struct DaySummary: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let totalScreenTime: TimeInterval
    let topApps: [AppUsage]
    let aiSummary: String
    let activityCount: Int
    let productivityScore: Double // 0.0 - 1.0

    init(
        id: UUID = UUID(),
        date: Date,
        totalScreenTime: TimeInterval,
        topApps: [AppUsage],
        aiSummary: String,
        activityCount: Int,
        productivityScore: Double
    ) {
        self.id = id
        self.date = date
        self.totalScreenTime = totalScreenTime
        self.topApps = topApps
        self.aiSummary = aiSummary
        self.activityCount = activityCount
        self.productivityScore = productivityScore
    }

    static func empty(date: Date = Date()) -> DaySummary {
        DaySummary(
            date: date,
            totalScreenTime: 0,
            topApps: [],
            aiSummary: "",
            activityCount: 0,
            productivityScore: 0
        )
    }
}

struct AppUsage: Identifiable, Hashable {
    let id: UUID
    let appName: String
    let appIcon: String
    let duration: TimeInterval
    let category: ActivityCategory

    init(
        id: UUID = UUID(),
        appName: String,
        appIcon: String,
        duration: TimeInterval,
        category: ActivityCategory
    ) {
        self.id = id
        self.appName = appName
        self.appIcon = appIcon
        self.duration = duration
        self.category = category
    }
}

// MARK: - Insight Data

struct WeeklyInsight: Identifiable {
    let id: UUID
    let weekStarting: Date
    let dailyScreenTime: [DailyMetric]
    let categoryBreakdown: [CategoryMetric]
    let topApps: [AppUsage]
    let avgProductivityScore: Double
    let trend: TrendDirection

    init(
        id: UUID = UUID(),
        weekStarting: Date,
        dailyScreenTime: [DailyMetric],
        categoryBreakdown: [CategoryMetric],
        topApps: [AppUsage],
        avgProductivityScore: Double,
        trend: TrendDirection
    ) {
        self.id = id
        self.weekStarting = weekStarting
        self.dailyScreenTime = dailyScreenTime
        self.categoryBreakdown = categoryBreakdown
        self.topApps = topApps
        self.avgProductivityScore = avgProductivityScore
        self.trend = trend
    }

    static func empty(weekStarting: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()) -> WeeklyInsight {
        WeeklyInsight(
            weekStarting: weekStarting,
            dailyScreenTime: [],
            categoryBreakdown: [],
            topApps: [],
            avgProductivityScore: 0,
            trend: .stable
        )
    }
}

struct DailyMetric: Identifiable {
    let id: UUID
    let date: Date
    let value: Double // hours

    init(id: UUID = UUID(), date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
}

struct CategoryMetric: Identifiable {
    let id: UUID
    let category: ActivityCategory
    let hours: Double
    let percentage: Double

    init(id: UUID = UUID(), category: ActivityCategory, hours: Double, percentage: Double) {
        self.id = id
        self.category = category
        self.hours = hours
        self.percentage = percentage
    }
}

enum TrendDirection: String {
    case up = "Up"
    case down = "Down"
    case stable = "Stable"

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
}

// MARK: - Settings

struct AppSettings {
    var captureIntervalSeconds: Int = 30
    var excludedApps: [String] = ["Keychain Access", "1Password", "System Preferences"]
    var storageLocation: String = "~/Library/Application Support/MacPulse"
    var storageLimitGB: Double = 5.0
    var currentStorageGB: Double = 0.0
    var aiModelName: String = "Llama 3.2 1B"
    var aiModelStatus: AIModelStatus = .ready
    var ocrEnabled: Bool = true
    var launchAtLogin: Bool = false
    var captureEnabled: Bool = true
    var encryptionEnabled: Bool = false  // M7: Optional app-level encryption for capture files
    var deleteScreenshotsAfterSummarize: Bool = false
}

enum AIModelStatus: String {
    case ready = "Ready"
    case downloading = "Downloading"
    case notInstalled = "Not Installed"
    case error = "Error"

    var color: String {
        switch self {
        case .ready: return "green"
        case .downloading: return "amber"
        case .notInstalled: return "slate"
        case .error: return "red"
        }
    }
}

// MARK: - Search Result (M6)

/// Unified search result that can represent matches from activity entries, daily summaries, or captures.
struct SearchResult: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let snippet: String           // The matched text excerpt
    let matchedField: String      // Which field matched (e.g. "summary", "title", "ocrText")
    let source: SearchResultSource
    let appName: String?
    let appIcon: String?
    let category: ActivityCategory?

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        snippet: String,
        matchedField: String,
        source: SearchResultSource,
        appName: String? = nil,
        appIcon: String? = nil,
        category: ActivityCategory? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.snippet = snippet
        self.matchedField = matchedField
        self.source = source
        self.appName = appName
        self.appIcon = appIcon
        self.category = category
    }
}

enum SearchResultSource: String {
    case activityEntry = "Activity"
    case dailySummary = "Daily Summary"
    case capture = "Capture"

    var icon: String {
        switch self {
        case .activityEntry: return "text.badge.checkmark"
        case .dailySummary: return "calendar"
        case .capture: return "camera.fill"
        }
    }
}

// MARK: - App Error (M6)

/// User-facing error that can be displayed as a banner/toast.
struct AppError: Identifiable {
    let id: UUID
    let title: String
    let message: String
    let severity: ErrorSeverity
    let timestamp: Date

    init(
        id: UUID = UUID(),
        title: String,
        message: String,
        severity: ErrorSeverity = .warning,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.severity = severity
        self.timestamp = timestamp
    }
}

enum ErrorSeverity: String {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
}
