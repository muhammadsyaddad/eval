import SwiftUI

// MARK: - Today View

struct TodayView: View {
    @EnvironmentObject var appState: AppState

    private var summary: DaySummary {
        appState.todaySummary
    }

    private var activities: [ActivityEntry] {
        appState.todayActivities
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: MPTheme.Spacing.xl) {

                // MARK: - Header
                VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                    Text("Today")
                        .font(MPTheme.Typography.display(32))
                        .foregroundColor(MPTheme.Colors.textPrimary)

                    Text(Date().fullDate)
                        .font(MPTheme.Typography.mono(12))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                }
                .padding(.bottom, MPTheme.Spacing.sm)

                if activities.isEmpty && summary.activityCount == 0 {
                    // MARK: - Empty State
                    EmptyStateView(
                        icon: "sun.max.fill",
                        title: "No Activity Yet",
                        description: "Start a capture session to begin tracking your screen activity. MacPulse will record and summarize what you do throughout the day.",
                        ctaTitle: "Start Capturing",
                        ctaAction: {
                            appState.startCapture()
                        }
                    )
                } else {
            // MARK: - Summary Card
            SummaryCardView(summary: summary)

                    // MARK: - Top Apps Bar
                    if !summary.topApps.isEmpty {
                        TopAppsBarView(apps: summary.topApps)
                    }

                    // MARK: - Activity Timeline
                    if !activities.isEmpty {
                        VStack(alignment: .leading, spacing: MPTheme.Spacing.lg) {
                            Text("ACTIVITY TIMELINE")
                                .sectionLabel()

                            ActivityTimelineView(activities: activities)
                        }
                    }
                }
            }
            .padding(MPTheme.Spacing.xxl)
        }
        .background(MPTheme.Colors.bgPrimary)
    }
}

// MARK: - Summary Card

struct SummaryCardView: View {
    let summary: DaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: MPTheme.Spacing.lg) {

            // Stats row
            HStack(spacing: MPTheme.Spacing.xxl) {
                StatBlock(
                    label: "SCREEN TIME",
                    value: summary.totalScreenTime.formattedHoursMinutes,
                    isMono: true
                )

                StatBlock(
                    label: "ACTIVITIES",
                    value: "\(summary.activityCount)",
                    isMono: true
                )

                StatBlock(
                    label: "PRODUCTIVITY",
                    value: "\(Int(summary.productivityScore * 100))%",
                    isMono: true,
                    accentColor: productivityColor
                )

                Spacer()
            }

            // Divider with subtle glow
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [MPTheme.Colors.accent.opacity(0.3), MPTheme.Colors.border],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // AI Summary
            VStack(alignment: .leading, spacing: MPTheme.Spacing.sm) {
                HStack(spacing: MPTheme.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(MPTheme.Colors.accent)
                    Text("AI SUMMARY")
                        .sectionLabel()
                }

                Text(summary.aiSummary.isEmpty ? "No summary yet. Start capturing to generate insights." : summary.aiSummary)
                    .font(MPTheme.Typography.body(13))
                    .foregroundColor(MPTheme.Colors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's summary. Screen time \(summary.totalScreenTime.formattedHoursMinutes). \(summary.activityCount) activities. Productivity \(Int(summary.productivityScore * 100)) percent. \(summary.aiSummary)")
    }

    private var productivityColor: Color {
        if summary.productivityScore > 0.75 { return MPTheme.Colors.success }
        if summary.productivityScore > 0.5 { return MPTheme.Colors.warning }
        return MPTheme.Colors.error
    }
}

// MARK: - Stat Block

struct StatBlock: View {
    let label: String
    let value: String
    var isMono: Bool = false
    var accentColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
            Text(label)
                .sectionLabel()

            Text(value)
                .font(isMono ? MPTheme.Typography.monoBold(24) : MPTheme.Typography.heading(24))
                .foregroundColor(accentColor ?? MPTheme.Colors.textPrimary)
        }
    }
}

// MARK: - Top Apps Bar

struct TopAppsBarView: View {
    let apps: [AppUsage]

    private var totalDuration: TimeInterval {
        apps.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
            Text("TOP APPS")
                .sectionLabel()

            // Proportional bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(apps) { app in
                        let fraction = app.duration / totalDuration
                        RoundedRectangle(cornerRadius: 3)
                            .fill(MPTheme.Colors.forCategory(app.category))
                            .frame(width: max(geo.size.width * fraction - 2, 4))
                    }
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            // Legend
            HStack(spacing: MPTheme.Spacing.lg) {
                ForEach(apps) { app in
                    HStack(spacing: MPTheme.Spacing.sm) {
                        Circle()
                            .fill(MPTheme.Colors.forCategory(app.category))
                            .frame(width: 6, height: 6)
                        Text(app.appName)
                            .font(MPTheme.Typography.caption(11))
                            .foregroundColor(MPTheme.Colors.textSecondary)
                        Text(app.duration.formattedDuration)
                            .font(MPTheme.Typography.mono(10))
                            .foregroundColor(MPTheme.Colors.textTertiary)
                    }
                }
                Spacer()
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Top apps: \(apps.map { "\($0.appName) \($0.duration.formattedDuration)" }.joined(separator: ", "))")
    }
}

// MARK: - Activity Timeline

struct ActivityTimelineView: View {
    let activities: [ActivityEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                HStack(alignment: .top, spacing: MPTheme.Spacing.lg) {

                    // Timestamp column
                    Text(activity.timestamp.timeString)
                        .font(MPTheme.Typography.mono(11))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                        .frame(width: 44, alignment: .trailing)

                    // Timeline line + dot
                    VStack(spacing: 0) {
                        Circle()
                            .fill(MPTheme.Colors.forCategory(activity.category))
                            .frame(width: 10, height: 10)
                            .shadow(color: MPTheme.Colors.forCategory(activity.category).opacity(0.4), radius: 4)

                        if index < activities.count - 1 {
                            Rectangle()
                                .fill(MPTheme.Colors.border)
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 10)

                    // Content card
                    ActivityCardView(activity: activity)
                        .padding(.bottom, index < activities.count - 1 ? MPTheme.Spacing.md : 0)
                }
            }
        }
    }
}

// MARK: - Activity Card

struct ActivityCardView: View {
    let activity: ActivityEntry
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: MPTheme.Spacing.sm) {
            HStack(spacing: MPTheme.Spacing.sm) {
                Image(systemName: activity.appIcon)
                    .font(.system(size: 13))
                    .foregroundColor(MPTheme.Colors.forCategory(activity.category))

                Text(activity.appName)
                    .font(MPTheme.Typography.caption(11))
                    .foregroundColor(MPTheme.Colors.forCategory(activity.category))

                Spacer()

                Text(activity.duration.formattedDuration)
                    .font(MPTheme.Typography.mono(10))
                    .foregroundColor(MPTheme.Colors.textTertiary)
                    .padding(.horizontal, MPTheme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(MPTheme.Colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: MPTheme.Radius.sm))
            }

            Text(activity.title)
                .font(MPTheme.Typography.heading(14))
                .foregroundColor(MPTheme.Colors.textPrimary)

            Text(activity.summary)
                .font(MPTheme.Typography.body(12))
                .foregroundColor(MPTheme.Colors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(MPTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .fill(isHovered ? MPTheme.Colors.bgHover : MPTheme.Colors.bgTertiary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .stroke(
                    isHovered ? MPTheme.Colors.forCategory(activity.category).opacity(0.3) : MPTheme.Colors.border,
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.appName): \(activity.title). \(activity.summary). Duration: \(activity.duration.formattedDuration)")
    }
}
