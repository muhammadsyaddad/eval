import Foundation

// MARK: - Activity Classifier

/// Classifies applications and screen content into activity categories.
/// Uses a rule-based approach: app name / bundle ID patterns first, then OCR text fallback.
/// Designed to be replaced or augmented by an ML classifier in a future milestone.
final class ActivityClassifier {

    // MARK: - Public API

    /// Classify a capture into an activity category based on app metadata and OCR text.
    func classify(appName: String, bundleIdentifier: String, windowTitle: String, ocrText: String?) -> ActivityCategory {
        // 1. Try bundle ID classification (most reliable)
        if let category = classifyByBundleID(bundleIdentifier) {
            return category
        }

        // 2. Try app name classification
        if let category = classifyByAppName(appName) {
            return category
        }

        let isBrowser = classifyByBundleID(bundleIdentifier, allowBrowser: true) == .browsing ||
            classifyByAppName(appName, allowBrowser: true) == .browsing

        // 3. For browsers, try to override with more specific signals first
        if isBrowser {
            if let category = classifyByWindowTitle(windowTitle), category != .browsing {
                return category
            }

            if let text = ocrText, !text.isEmpty, let category = classifyByOCRText(text), category != .browsing {
                return category
            }
        }

        // 4. Try window title classification
        if let category = classifyByWindowTitle(windowTitle) {
            return category
        }

        // 5. Try OCR text heuristics
        if let text = ocrText, !text.isEmpty, let category = classifyByOCRText(text) {
            return category
        }

        // 6. Default browsers to browsing when no other signals are found
        if isBrowser {
            return .browsing
        }

        return .other
    }

    /// Get an appropriate SF Symbol icon for an app name.
    func iconForApp(_ appName: String) -> String {
        let lower = appName.lowercased()

        // Browsers
        if browserApps.contains(where: { lower.contains($0) }) { return "globe" }

        // Communication
        if communicationApps.contains(where: { lower.contains($0) }) { return "message.fill" }

        // Development
        if devApps.contains(where: { lower.contains($0) }) { return "chevron.left.forwardslash.chevron.right" }

        // Design
        if designApps.contains(where: { lower.contains($0) }) { return "paintbrush.fill" }

        // Writing
        if writingApps.contains(where: { lower.contains($0) }) { return "doc.text.fill" }

        // Productivity
        if productivityApps.contains(where: { lower.contains($0) }) { return "chart.bar.fill" }

        // Entertainment
        if entertainmentApps.contains(where: { lower.contains($0) }) { return "play.circle.fill" }

        // System
        if systemApps.contains(where: { lower.contains($0) }) { return "gearshape.fill" }

        return "app.fill"
    }

    // MARK: - Bundle ID Classification

    private func classifyByBundleID(_ bundleID: String, allowBrowser: Bool = false) -> ActivityCategory? {
        let id = bundleID.lowercased()

        // Development
        if id.contains("com.apple.dt.xcode") || id.contains("com.microsoft.vscode") ||
           id.contains("com.jetbrains") || id.contains("com.sublimetext") ||
           id.contains("com.github.atom") || id.contains("dev.zed") ||
           id.contains("com.todesktop.cursor") || id.contains("com.googlecode.iterm2") ||
           id.contains("com.apple.terminal") || id.contains("net.kovidgoyal.kitty") ||
           id.contains("com.mitchellh.ghostty") || id.contains("co.warp.warpterm") {
            return .development
        }

        // Communication
        if id.contains("com.apple.mail") || id.contains("com.microsoft.outlook") ||
           id.contains("com.tinyspeck.slackmacgap") || id.contains("com.microsoft.teams") ||
           id.contains("us.zoom.xos") || id.contains("com.apple.messages") ||
           id.contains("com.apple.facetime") || id.contains("ru.keepcoder.telegram") ||
           id.contains("com.hnc.discord") || id.contains("com.whatsapp") {
            return .communication
        }

        // Browsing
        if id.contains("com.apple.safari") || id.contains("com.google.chrome") ||
           id.contains("org.mozilla.firefox") || id.contains("company.thebrowser.browser") ||
           id.contains("com.microsoft.edgemac") || id.contains("com.brave.browser") ||
           id.contains("com.vivaldi.vivaldi") || id.contains("com.operasoftware.opera") {
            return allowBrowser ? .browsing : nil
        }

        // Design
        if id.contains("com.figma") || id.contains("com.bohemiancoding.sketch") ||
           id.contains("com.adobe.photoshop") || id.contains("com.adobe.illustrator") ||
           id.contains("com.adobe.xd") || id.contains("com.pixelmatorteam") ||
           id.contains("com.apple.garageband") || id.contains("com.adobe.indesign") {
            return .design
        }

        // Writing
        if id.contains("com.apple.iwork.pages") || id.contains("com.microsoft.word") ||
           id.contains("com.google.docs") || id.contains("com.ulyssesapp") ||
           id.contains("md.obsidian") || id.contains("com.apple.notes") ||
           id.contains("com.notion") || id.contains("abnerworks.typora") ||
           id.contains("com.bear-writer") {
            return .writing
        }

        // Productivity (spreadsheets, presentations, databases, task management)
        if id.contains("com.apple.iwork.keynote") || id.contains("com.apple.iwork.numbers") ||
           id.contains("com.microsoft.excel") || id.contains("com.microsoft.powerpoint") ||
           id.contains("com.apple.finder") || id.contains("com.apple.preview") ||
           id.contains("com.apple.calculator") || id.contains("com.apple.calendar") ||
           id.contains("com.apple.reminders") || id.contains("com.todoist") ||
           id.contains("com.linear") || id.contains("com.asana") {
            return .productivity
        }

        // Entertainment
        if id.contains("com.apple.music") || id.contains("com.spotify") ||
           id.contains("com.apple.tv") || id.contains("com.netflix") ||
           id.contains("com.youtube") || id.contains("com.apple.podcasts") ||
           id.contains("com.valvesoftware.steam") {
            return .entertainment
        }

        return nil
    }

    // MARK: - App Name Classification

    private let browserApps = ["safari", "chrome", "firefox", "arc", "edge", "brave", "vivaldi", "opera"]
    private let communicationApps = ["mail", "outlook", "slack", "teams", "zoom", "messages", "facetime", "telegram", "discord", "whatsapp", "signal"]
    private let devApps = ["xcode", "visual studio code", "vscode", "terminal", "iterm", "kitty", "ghostty", "warp", "intellij", "webstorm", "pycharm", "cursor", "zed", "sublime text", "neovim", "vim"]
    private let designApps = ["figma", "sketch", "photoshop", "illustrator", "pixelmator", "affinity", "canva", "garageband", "logic pro", "final cut"]
    private let writingApps = ["pages", "word", "obsidian", "notion", "typora", "bear", "ulysses", "ia writer", "scrivener", "notes"]
    private let productivityApps = ["numbers", "excel", "keynote", "powerpoint", "finder", "preview", "calendar", "reminders", "todoist", "linear", "asana", "jira", "trello"]
    private let entertainmentApps = ["music", "spotify", "tv", "netflix", "youtube", "podcasts", "steam", "twitch"]
    private let systemApps = ["system preferences", "system settings", "activity monitor", "disk utility", "console", "keychain"]

    private func classifyByAppName(_ appName: String, allowBrowser: Bool = false) -> ActivityCategory? {
        let lower = appName.lowercased()

        if devApps.contains(where: { lower.contains($0) }) { return .development }
        if communicationApps.contains(where: { lower.contains($0) }) { return .communication }
        if allowBrowser, browserApps.contains(where: { lower.contains($0) }) { return .browsing }
        if designApps.contains(where: { lower.contains($0) }) { return .design }
        if writingApps.contains(where: { lower.contains($0) }) { return .writing }
        if productivityApps.contains(where: { lower.contains($0) }) { return .productivity }
        if entertainmentApps.contains(where: { lower.contains($0) }) { return .entertainment }

        return nil
    }

    // MARK: - Window Title Classification

    private func classifyByWindowTitle(_ title: String) -> ActivityCategory? {
        let lower = title.lowercased()

        // Development signals in window titles
        if lower.contains(".swift") || lower.contains(".py") || lower.contains(".ts") ||
           lower.contains(".js") || lower.contains(".rs") || lower.contains(".go") ||
           lower.contains(".java") || lower.contains(".c") || lower.contains(".cpp") ||
           lower.contains(".rb") || lower.contains(".kt") || lower.contains(".cs") ||
           lower.contains("debug") || lower.contains("build") || lower.contains("compile") ||
           lower.contains("github.com") || lower.contains("gitlab.com") ||
           lower.contains("stackoverflow.com") || lower.contains("localhost:") ||
           lower.contains("pull request") || lower.contains("merge request") {
            return .development
        }

        // Communication signals
        if lower.contains("inbox") || lower.contains("compose") || lower.contains("new message") ||
           lower.contains("chat") || lower.contains("meeting") || lower.contains("call") {
            return .communication
        }

        // Design signals
        if lower.contains("figma") || lower.contains("untitled design") ||
           lower.contains("canvas") || lower.contains("artboard") || lower.contains("layer") {
            return .design
        }

        // Writing signals
        if lower.contains("untitled document") || lower.contains("draft") ||
           lower.contains("writing") || lower.contains("essay") || lower.contains("blog post") {
            return .writing
        }

        // Entertainment signals
        if lower.contains("youtube") || lower.contains("netflix") || lower.contains("twitch") ||
           lower.contains("spotify") || lower.contains("now playing") {
            return .entertainment
        }

        return nil
    }

    // MARK: - OCR Text Classification

    private func classifyByOCRText(_ text: String) -> ActivityCategory? {
        let lower = text.lowercased()
        let wordCount = lower.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        guard wordCount > 3 else { return nil } // Not enough text to classify

        // Score each category by keyword density
        var scores: [ActivityCategory: Int] = [:]

        let devKeywords = ["func ", "class ", "import ", "return ", "var ", "let ", "def ", "const ",
                           "function ", "struct ", "enum ", "protocol ", "interface ", "error",
                           "debug", "build", "compile", "commit", "branch", "merge", "pull request",
                           "console", "terminal", "npm", "git", "docker"]

        let commKeywords = ["inbox", "sent", "reply", "forward", "subject:", "from:", "to:",
                           "message", "chat", "thread", "channel", "mention", "notification"]

        let productivityKeywords = ["spreadsheet", "formula", "cell", "row", "column", "chart",
                                   "presentation", "slide", "table", "total", "sum", "average",
                                   "task", "project", "deadline", "due date", "priority"]

        let writingKeywords = ["paragraph", "heading", "bold", "italic", "font", "style",
                              "document", "page", "chapter", "section", "outline", "draft"]

        for keyword in devKeywords where lower.contains(keyword) { scores[.development, default: 0] += 1 }
        for keyword in commKeywords where lower.contains(keyword) { scores[.communication, default: 0] += 1 }
        for keyword in productivityKeywords where lower.contains(keyword) { scores[.productivity, default: 0] += 1 }
        for keyword in writingKeywords where lower.contains(keyword) { scores[.writing, default: 0] += 1 }

        // Return the highest-scoring category if it has at least 2 hits
        if let best = scores.max(by: { $0.value < $1.value }), best.value >= 2 {
            return best.key
        }

        return nil
    }
}

// MARK: - Productivity Score Estimation

extension ActivityClassifier {

    /// Estimate a productivity score (0.0–1.0) for a set of activities based on category distribution.
    func estimateProductivityScore(activities: [(category: ActivityCategory, duration: TimeInterval)]) -> Double {
        guard !activities.isEmpty else { return 0.0 }

        let totalDuration = activities.map(\.duration).reduce(0, +)
        guard totalDuration > 0 else { return 0.0 }

        var weightedScore: Double = 0
        for activity in activities {
            let weight = activity.duration / totalDuration
            let categoryScore = productivityWeight(for: activity.category)
            weightedScore += weight * categoryScore
        }

        return min(max(weightedScore, 0.0), 1.0)
    }

    /// Productivity weight for each category (0.0 = unproductive, 1.0 = highly productive).
    private func productivityWeight(for category: ActivityCategory) -> Double {
        switch category {
        case .development:    return 0.95
        case .writing:        return 0.90
        case .design:         return 0.85
        case .productivity:   return 0.80
        case .communication:  return 0.55
        case .browsing:       return 0.40
        case .entertainment:  return 0.10
        case .other:          return 0.30
        }
    }
}
