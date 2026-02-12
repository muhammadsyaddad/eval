import Foundation

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        }
    }
}

// MARK: - Export Service Protocol

protocol ExportServiceProtocol {
    /// Export daily summaries for a date range.
    func exportDailySummaries(from startDate: Date, to endDate: Date, format: ExportFormat) throws -> Data

    /// Export activity entries for a date range.
    func exportActivityEntries(from startDate: Date, to endDate: Date, format: ExportFormat) throws -> Data

    /// Export app usage for a date range.
    func exportAppUsage(from startDate: Date, to endDate: Date, format: ExportFormat) throws -> Data

    /// Export all data for a date range as a combined JSON bundle.
    func exportAll(from startDate: Date, to endDate: Date) throws -> Data
}

// MARK: - Export Service

final class ExportService: ExportServiceProtocol {

    private let dataStore: DataStoreProtocol

    init(dataStore: DataStoreProtocol) {
        self.dataStore = dataStore
    }

    // MARK: - Daily Summaries

    func exportDailySummaries(from startDate: Date, to endDate: Date, format: ExportFormat) throws -> Data {
        let summaries = try dataStore.fetchDailySummaries(from: startDate, to: endDate)

        switch format {
        case .json:
            return try exportAsJSON(summaries.map { ExportableSummary(from: $0) })
        case .csv:
            return exportSummariesAsCSV(summaries)
        }
    }

    // MARK: - Activity Entries

    func exportActivityEntries(from startDate: Date, to endDate: Date, format: ExportFormat) throws -> Data {
        let entries = try dataStore.fetchActivityEntries(from: startDate, to: endDate)

        switch format {
        case .json:
            return try exportAsJSON(entries.map { ExportableActivity(from: $0) })
        case .csv:
            return exportActivitiesAsCSV(entries)
        }
    }

    // MARK: - App Usage

    func exportAppUsage(from startDate: Date, to endDate: Date, format: ExportFormat) throws -> Data {
        let topApps = try dataStore.fetchTopApps(from: startDate, to: endDate, limit: 100)

        switch format {
        case .json:
            return try exportAsJSON(topApps.map { ExportableAppUsage(from: $0) })
        case .csv:
            return exportAppUsageAsCSV(topApps)
        }
    }

    // MARK: - Export All

    func exportAll(from startDate: Date, to endDate: Date) throws -> Data {
        let summaries = try dataStore.fetchDailySummaries(from: startDate, to: endDate)
        let entries = try dataStore.fetchActivityEntries(from: startDate, to: endDate)
        let topApps = try dataStore.fetchTopApps(from: startDate, to: endDate, limit: 100)

        let bundle = ExportBundle(
            exportDate: Date(),
            dateRange: ExportDateRange(from: startDate, to: endDate),
            dailySummaries: summaries.map { ExportableSummary(from: $0) },
            activityEntries: entries.map { ExportableActivity(from: $0) },
            appUsage: topApps.map { ExportableAppUsage(from: $0) }
        )

        return try exportAsJSON(bundle)
    }

    // MARK: - Private — JSON

    private func exportAsJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    // MARK: - Private — CSV Generators

    private func exportSummariesAsCSV(_ summaries: [DailySummaryRecord]) -> Data {
        var csv = "date,total_screen_time_seconds,activity_count,productivity_score,ai_summary\n"
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        for s in summaries {
            let date = dateFormatter.string(from: s.date)
            let summary = escapeCSV(s.aiSummary)
            csv += "\(date),\(s.totalScreenTime),\(s.activityCount),\(String(format: "%.2f", s.productivityScore)),\(summary)\n"
        }
        return Data(csv.utf8)
    }

    private func exportActivitiesAsCSV(_ entries: [ActivityEntryRecord]) -> Data {
        var csv = "timestamp,app_name,title,summary,category,duration_seconds\n"
        let dateFormatter = ISO8601DateFormatter()

        for e in entries {
            let ts = dateFormatter.string(from: e.timestamp)
            let title = escapeCSV(e.title)
            let summary = escapeCSV(e.summary)
            csv += "\(ts),\(escapeCSV(e.appName)),\(title),\(summary),\(e.category),\(e.duration)\n"
        }
        return Data(csv.utf8)
    }

    private func exportAppUsageAsCSV(_ records: [AppUsageRecord]) -> Data {
        var csv = "date,app_name,category,duration_seconds\n"
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        for r in records {
            let date = dateFormatter.string(from: r.date)
            csv += "\(date),\(escapeCSV(r.appName)),\(r.category),\(r.duration)\n"
        }
        return Data(csv.utf8)
    }

    /// Escape a string for CSV: wrap in quotes if it contains commas, quotes, or newlines.
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

// MARK: - Exportable Models (Codable wrappers for JSON export)

private struct ExportBundle: Encodable {
    let exportDate: Date
    let dateRange: ExportDateRange
    let dailySummaries: [ExportableSummary]
    let activityEntries: [ExportableActivity]
    let appUsage: [ExportableAppUsage]
}

private struct ExportDateRange: Encodable {
    let from: Date
    let to: Date
}

private struct ExportableSummary: Encodable {
    let date: Date
    let totalScreenTimeSeconds: Double
    let activityCount: Int
    let productivityScore: Double
    let aiSummary: String

    init(from record: DailySummaryRecord) {
        self.date = record.date
        self.totalScreenTimeSeconds = record.totalScreenTime
        self.activityCount = record.activityCount
        self.productivityScore = record.productivityScore
        self.aiSummary = record.aiSummary
    }
}

private struct ExportableActivity: Encodable {
    let timestamp: Date
    let appName: String
    let title: String
    let summary: String
    let category: String
    let durationSeconds: Double

    init(from record: ActivityEntryRecord) {
        self.timestamp = record.timestamp
        self.appName = record.appName
        self.title = record.title
        self.summary = record.summary
        self.category = record.category
        self.durationSeconds = record.duration
    }
}

private struct ExportableAppUsage: Encodable {
    let date: Date
    let appName: String
    let category: String
    let durationSeconds: Double

    init(from record: AppUsageRecord) {
        self.date = record.date
        self.appName = record.appName
        self.category = record.category
        self.durationSeconds = record.duration
    }
}
