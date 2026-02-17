import Foundation

// MARK: - Mock Data Store

struct MockDataStore {
    let todayActivities: [ActivityEntry]
    let todaySummary: DaySummary
    let historySummaries: [DaySummary]
    let weeklyInsight: WeeklyInsight
    var settings: AppSettings

    init() {
        let now = Date()
        let cal = Calendar.current

        // MARK: - Today's Activities (realistic macOS usage)

        self.todayActivities = [
            ActivityEntry(
                timestamp: cal.date(bySettingHour: 8, minute: 12, second: 0, of: now)!,
                appName: "Mail",
                appIcon: "envelope.fill",
                title: "Morning inbox review",
                summary: "Reviewed 12 emails. Replied to 3 threads about Q4 planning and flagged 2 for follow-up.",
                category: .communication,
                duration: 1080
            ),
            ActivityEntry(
                timestamp: cal.date(bySettingHour: 8, minute: 45, second: 0, of: now)!,
                appName: "Safari",
                appIcon: "safari.fill",
                title: "Research: on-device ML frameworks",
                summary: "Read Apple documentation on Core ML and Vision framework. Bookmarked 4 articles on local inference optimization.",
                category: .browsing,
                duration: 2700
            ),
            ActivityEntry(
                timestamp: cal.date(bySettingHour: 9, minute: 30, second: 0, of: now)!,
                appName: "Xcode",
                appIcon: "hammer.fill",
                title: "Eval — OCR pipeline",
                summary: "Implemented VNRecognizeTextRequest handler for screen capture processing. Added confidence threshold filtering.",
                category: .development,
                duration: 5400
            ),
            ActivityEntry(
                timestamp: cal.date(bySettingHour: 11, minute: 0, second: 0, of: now)!,
                appName: "Slack",
                appIcon: "bubble.left.and.bubble.right.fill",
                title: "Team standup & async updates",
                summary: "Participated in #engineering standup. Shared progress on OCR pipeline. Discussed timeline with PM.",
                category: .communication,
                duration: 1800
            ),
            ActivityEntry(
                timestamp: cal.date(bySettingHour: 11, minute: 35, second: 0, of: now)!,
                appName: "Figma",
                appIcon: "paintbrush.pointed.fill",
                title: "Settings panel wireframes",
                summary: "Iterated on Settings UI layout. Updated capture interval controls and model status indicators.",
                category: .design,
                duration: 3600
            ),
            ActivityEntry(
                timestamp: cal.date(bySettingHour: 12, minute: 40, second: 0, of: now)!,
                appName: "Notes",
                appIcon: "note.text",
                title: "Architecture decision record",
                summary: "Drafted ADR for local-first data storage approach. Compared SQLite vs Core Data for activity logs.",
                category: .writing,
                duration: 2400
            ),
            ActivityEntry(
                timestamp: cal.date(bySettingHour: 13, minute: 20, second: 0, of: now)!,
                appName: "Xcode",
                appIcon: "hammer.fill",
                title: "Eval — timeline UI",
                summary: "Built vertical timeline component with SwiftUI. Implemented activity cards with category color coding.",
                category: .development,
                duration: 7200
            ),
            ActivityEntry(
                timestamp: cal.date(bySettingHour: 15, minute: 25, second: 0, of: now)!,
                appName: "Terminal",
                appIcon: "terminal.fill",
                title: "Build & test run",
                summary: "Ran full test suite — 42 passed, 0 failed. Fixed one flaky test in OCR module.",
                category: .development,
                duration: 1200
            ),
            ActivityEntry(
                timestamp: cal.date(bySettingHour: 15, minute: 50, second: 0, of: now)!,
                appName: "Safari",
                appIcon: "safari.fill",
                title: "Hacker News & tech reading",
                summary: "Browsed HN front page. Read article on privacy-preserving analytics and new SQLite features.",
                category: .entertainment,
                duration: 1500
            ),
            ActivityEntry(
                timestamp: cal.date(bySettingHour: 16, minute: 20, second: 0, of: now)!,
                appName: "Xcode",
                appIcon: "hammer.fill",
                title: "Eval — insights chart view",
                summary: "Implemented weekly bar chart using Swift Charts. Added category breakdown donut visualization.",
                category: .development,
                duration: 4800
            ),
        ]

        let todayTopApps = [
            AppUsage(appName: "Xcode", appIcon: "hammer.fill", duration: 18600, category: .development),
            AppUsage(appName: "Safari", appIcon: "safari.fill", duration: 4200, category: .browsing),
            AppUsage(appName: "Figma", appIcon: "paintbrush.pointed.fill", duration: 3600, category: .design),
            AppUsage(appName: "Slack", appIcon: "bubble.left.and.bubble.right.fill", duration: 1800, category: .communication),
            AppUsage(appName: "Mail", appIcon: "envelope.fill", duration: 1080, category: .communication),
        ]

        self.todaySummary = DaySummary(
            date: now,
            totalScreenTime: 31680,
            topApps: todayTopApps,
            aiSummary: "Highly productive development day focused on Eval. Built OCR pipeline and timeline UI in Xcode (5.2h). Collaborated with team via Slack and refined Settings wireframes in Figma. Light browsing in the afternoon. 87% of screen time was productive.",
            activityCount: 10,
            productivityScore: 0.87
        )

        // MARK: - History (30 days of summaries)

        var summaries: [DaySummary] = []
        let aiSummaries = [
            "Deep work session on data pipeline. Minimal interruptions. Shipped new feature branch.",
            "Meeting-heavy day — 3 video calls. Wrote specs for privacy module between meetings.",
            "Focused writing day. Published internal blog post and updated documentation.",
            "Debugging session for memory leak in capture service. Fixed by evening.",
            "Design review with team. Iterated on onboarding flow. Updated Figma prototypes.",
            "Light day. Code reviews and small fixes. Left early for appointment.",
            "Weekend — browsed tech articles and watched conference talks.",
            "Sprint planning and backlog grooming. Set up CI pipeline improvements.",
            "Paired programming on OCR accuracy improvements. Good progress.",
            "Research day: evaluated 3 local SLM options for summarization quality.",
        ]

        for i in 1...30 {
            let date = cal.date(byAdding: .day, value: -i, to: now)!
            let screenTime = Double.random(in: 14400...36000)
            let score = Double.random(in: 0.45...0.95)
            let count = Int.random(in: 5...18)

            summaries.append(DaySummary(
                date: date,
                totalScreenTime: screenTime,
                topApps: [
                    AppUsage(appName: "Xcode", appIcon: "hammer.fill", duration: screenTime * 0.4, category: .development),
                    AppUsage(appName: "Safari", appIcon: "safari.fill", duration: screenTime * 0.2, category: .browsing),
                    AppUsage(appName: "Slack", appIcon: "bubble.left.and.bubble.right.fill", duration: screenTime * 0.15, category: .communication),
                ],
                aiSummary: aiSummaries[i % aiSummaries.count],
                activityCount: count,
                productivityScore: score
            ))
        }
        self.historySummaries = summaries

        // MARK: - Weekly Insight

        var dailyMetrics: [DailyMetric] = []
        for i in 0..<7 {
            let date = cal.date(byAdding: .day, value: -i, to: now)!
            dailyMetrics.append(DailyMetric(date: date, value: Double.random(in: 4.0...9.5)))
        }

        let categoryBreakdown = [
            CategoryMetric(category: .development, hours: 22.5, percentage: 0.42),
            CategoryMetric(category: .communication, hours: 10.8, percentage: 0.20),
            CategoryMetric(category: .browsing, hours: 8.1, percentage: 0.15),
            CategoryMetric(category: .design, hours: 5.4, percentage: 0.10),
            CategoryMetric(category: .writing, hours: 3.8, percentage: 0.07),
            CategoryMetric(category: .entertainment, hours: 3.2, percentage: 0.06),
        ]

        self.weeklyInsight = WeeklyInsight(
            weekStarting: cal.date(byAdding: .day, value: -6, to: now)!,
            dailyScreenTime: dailyMetrics.reversed(),
            categoryBreakdown: categoryBreakdown,
            topApps: todayTopApps,
            avgProductivityScore: 0.78,
            trend: .up
        )

        // MARK: - Settings

        self.settings = AppSettings()
    }
}
