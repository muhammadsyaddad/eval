import Foundation

// MARK: - Summarization Service Protocol

/// Abstraction for generating natural language summaries from captured activity data.
/// The heuristic implementation uses templates and pattern matching.
/// A future LLM-backed implementation (llama.cpp / Core ML) can be swapped in via this protocol.
protocol SummarizationServiceProtocol {

    /// Generate a short summary for a single activity (one or more captures grouped by app/context).
    func summarizeActivity(
        appName: String,
        windowTitle: String,
        ocrText: String?,
        category: ActivityCategory,
        duration: TimeInterval
    ) -> String

    /// Generate a daily narrative summary from all the day's activity entries.
    func summarizeDay(
        entries: [ActivityEntry],
        totalScreenTime: TimeInterval,
        topApps: [AppUsage],
        productivityScore: Double
    ) -> String

    /// The name of this summarization backend (for display in Settings).
    var backendName: String { get }

    /// Whether the backend is ready to generate summaries.
    var isReady: Bool { get }
}

// MARK: - Heuristic Summarizer

/// Rule-based summarizer using templates and OCR text extraction.
/// Produces readable, human-friendly summaries without any ML model.
/// Designed to be "good enough" for v1 and upgradeable to LLM later.
final class HeuristicSummarizer: SummarizationServiceProtocol {

    var backendName: String { "Heuristic Engine" }
    var isReady: Bool { true }

    // MARK: - Activity Summarization

    func summarizeActivity(
        appName: String,
        windowTitle: String,
        ocrText: String?,
        category: ActivityCategory,
        duration: TimeInterval
    ) -> String {
        let durationStr = formatDuration(duration)

        // Try to generate a context-aware summary
        if let contextSummary = contextualSummary(
            appName: appName,
            windowTitle: windowTitle,
            ocrText: ocrText,
            category: category,
            duration: durationStr
        ) {
            return contextSummary
        }

        // Fallback: generic category-based summary
        return genericSummary(appName: appName, category: category, duration: durationStr)
    }

    // MARK: - Daily Summarization

    func summarizeDay(
        entries: [ActivityEntry],
        totalScreenTime: TimeInterval,
        topApps: [AppUsage],
        productivityScore: Double
    ) -> String {
        guard !entries.isEmpty else {
            return "No activity recorded today."
        }

        var parts: [String] = []

        // Opening line: screen time overview
        let hours = Int(totalScreenTime) / 3600
        let minutes = (Int(totalScreenTime) % 3600) / 60
        if hours > 0 {
            parts.append("You spent \(hours)h \(minutes)m on screen today")
        } else {
            parts.append("You spent \(minutes) minutes on screen today")
        }
        parts.append("across \(entries.count) activities.")

        // Top apps narrative
        if !topApps.isEmpty {
            let appNames = topApps.prefix(3).map(\.appName)
            if appNames.count == 1 {
                parts.append("Most time was spent in \(appNames[0]).")
            } else if appNames.count == 2 {
                parts.append("Most time was spent in \(appNames[0]) and \(appNames[1]).")
            } else {
                parts.append("Top apps: \(appNames[0]), \(appNames[1]), and \(appNames[2]).")
            }
        }

        // Category breakdown narrative
        let categoryDurations = Dictionary(grouping: entries, by: \.category)
            .mapValues { entries in entries.map(\.duration).reduce(0, +) }
            .sorted { $0.value > $1.value }

        if let topCategory = categoryDurations.first {
            let pct = Int((topCategory.value / totalScreenTime) * 100)
            parts.append("\(topCategory.key.rawValue) was your primary focus at \(pct)% of total time.")
        }

        // Productivity assessment
        let prodPct = Int(productivityScore * 100)
        if productivityScore >= 0.75 {
            parts.append("Productivity score: \(prodPct)% — a highly focused day.")
        } else if productivityScore >= 0.50 {
            parts.append("Productivity score: \(prodPct)% — a balanced day of work and other activities.")
        } else if productivityScore >= 0.25 {
            parts.append("Productivity score: \(prodPct)% — a lighter work day.")
        } else {
            parts.append("Productivity score: \(prodPct)% — mostly leisure and non-work activities.")
        }

        // Notable activities
        let devEntries = entries.filter { $0.category == .development }
        if !devEntries.isEmpty {
            let devTime = devEntries.map(\.duration).reduce(0, +)
            let devMinutes = Int(devTime) / 60
            if devMinutes >= 30 {
                parts.append("Development work totaled \(formatDuration(devTime)).")
            }
        }

        let commEntries = entries.filter { $0.category == .communication }
        if !commEntries.isEmpty {
            let commTime = commEntries.map(\.duration).reduce(0, +)
            let commMinutes = Int(commTime) / 60
            if commMinutes >= 15 {
                parts.append("Communication took \(formatDuration(commTime)).")
            }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Contextual Summary (window title + OCR aware)

    private func contextualSummary(
        appName: String,
        windowTitle: String,
        ocrText: String?,
        category: ActivityCategory,
        duration: String
    ) -> String? {
        let title = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        switch category {
        case .development:
            return developmentSummary(appName: appName, windowTitle: title, ocrText: ocrText, duration: duration)
        case .communication:
            return communicationSummary(appName: appName, windowTitle: title, duration: duration)
        case .browsing:
            return browsingSummary(appName: appName, windowTitle: title, duration: duration)
        case .writing:
            return writingSummary(appName: appName, windowTitle: title, duration: duration)
        case .design:
            return designSummary(appName: appName, windowTitle: title, duration: duration)
        case .entertainment:
            return entertainmentSummary(appName: appName, windowTitle: title, duration: duration)
        case .productivity:
            return productivitySummary(appName: appName, windowTitle: title, duration: duration)
        case .other:
            return nil
        }
    }

    private func developmentSummary(appName: String, windowTitle: String, ocrText: String?, duration: String) -> String? {
        // Extract file name from window title
        let components = windowTitle.components(separatedBy: " — ")
        let firstPart = components.first ?? windowTitle

        if firstPart.contains(".swift") || firstPart.contains(".py") || firstPart.contains(".ts") ||
           firstPart.contains(".js") || firstPart.contains(".rs") || firstPart.contains(".go") {
            return "Editing \(firstPart) in \(appName) for \(duration)."
        }

        if windowTitle.lowercased().contains("terminal") || appName.lowercased().contains("terminal") ||
           appName.lowercased().contains("iterm") || appName.lowercased().contains("warp") {
            // Try to get context from OCR
            if let text = ocrText, !text.isEmpty {
                let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                if let lastCommand = lines.last(where: { $0.contains("$") || $0.contains("%") || $0.contains(">") }) {
                    let cmd = lastCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                    let truncated = cmd.count > 60 ? String(cmd.prefix(60)) + "..." : cmd
                    return "Working in terminal (\(truncated)) for \(duration)."
                }
            }
            return "Working in \(appName) for \(duration)."
        }

        if windowTitle.lowercased().contains("pull request") || windowTitle.lowercased().contains("merge request") {
            return "Reviewing a pull request in \(appName) for \(duration)."
        }

        if windowTitle.lowercased().contains("github.com") || windowTitle.lowercased().contains("gitlab.com") {
            return "Browsing code repositories for \(duration)."
        }

        return "Working in \(appName) on \"\(truncateTitle(firstPart))\" for \(duration)."
    }

    private func communicationSummary(appName: String, windowTitle: String, duration: String) -> String? {
        if windowTitle.lowercased().contains("inbox") {
            return "Checking email in \(appName) for \(duration)."
        }
        if windowTitle.lowercased().contains("compose") || windowTitle.lowercased().contains("new message") {
            return "Writing a message in \(appName) for \(duration)."
        }
        if windowTitle.lowercased().contains("meeting") || windowTitle.lowercased().contains("call") {
            return "In a meeting/call via \(appName) for \(duration)."
        }

        let channel = truncateTitle(windowTitle)
        return "Communicating via \(appName) (\(channel)) for \(duration)."
    }

    private func browsingSummary(appName: String, windowTitle: String, duration: String) -> String? {
        let title = truncateTitle(windowTitle)
        return "Browsing \"\(title)\" in \(appName) for \(duration)."
    }

    private func writingSummary(appName: String, windowTitle: String, duration: String) -> String? {
        let docName = truncateTitle(windowTitle)
        return "Writing in \(appName) — \"\(docName)\" for \(duration)."
    }

    private func designSummary(appName: String, windowTitle: String, duration: String) -> String? {
        let projectName = truncateTitle(windowTitle)
        return "Designing in \(appName) — \"\(projectName)\" for \(duration)."
    }

    private func entertainmentSummary(appName: String, windowTitle: String, duration: String) -> String? {
        let content = truncateTitle(windowTitle)
        return "Watching/listening: \"\(content)\" in \(appName) for \(duration)."
    }

    private func productivitySummary(appName: String, windowTitle: String, duration: String) -> String? {
        let detail = truncateTitle(windowTitle)
        return "Using \(appName) (\(detail)) for \(duration)."
    }

    // MARK: - Generic Summary

    private func genericSummary(appName: String, category: ActivityCategory, duration: String) -> String {
        switch category {
        case .development:    return "Working in \(appName) for \(duration)."
        case .communication:  return "Communicating via \(appName) for \(duration)."
        case .browsing:       return "Browsing in \(appName) for \(duration)."
        case .entertainment:  return "Using \(appName) for leisure (\(duration))."
        case .design:         return "Designing in \(appName) for \(duration)."
        case .writing:        return "Writing in \(appName) for \(duration)."
        case .productivity:   return "Working in \(appName) for \(duration)."
        case .other:          return "Using \(appName) for \(duration)."
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        }
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        if minutes < 60 {
            return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
    }

    private func truncateTitle(_ title: String, maxLength: Int = 50) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= maxLength {
            return cleaned
        }
        return String(cleaned.prefix(maxLength)) + "..."
    }
}
