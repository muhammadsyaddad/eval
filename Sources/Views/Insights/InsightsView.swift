import SwiftUI
import Charts

// MARK: - Insights View

struct InsightsView: View {
    @EnvironmentObject var appState: AppState

    private var insight: WeeklyInsight {
        appState.weeklyInsight
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: MPTheme.Spacing.xl) {

                // MARK: - Header
                VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                    Text("Insights")
                        .font(MPTheme.Typography.display(32))
                        .foregroundColor(MPTheme.Colors.textPrimary)

                    HStack(spacing: MPTheme.Spacing.sm) {
                        Text("Week of \(insight.weekStarting.shortDate)")
                            .font(MPTheme.Typography.mono(12))
                            .foregroundColor(MPTheme.Colors.textTertiary)

                        // Trend indicator
                        HStack(spacing: 4) {
                            Image(systemName: insight.trend.icon)
                                .font(.system(size: 10, weight: .bold))
                            Text(insight.trend.rawValue)
                                .font(MPTheme.Typography.mono(10))
                        }
                        .foregroundColor(trendColor)
                        .padding(.horizontal, MPTheme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(trendColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: MPTheme.Radius.sm))
                    }
                }
                .padding(.bottom, MPTheme.Spacing.sm)

                if insight.dailyScreenTime.isEmpty && insight.categoryBreakdown.isEmpty {
                    // MARK: - Empty State
                    EmptyStateView(
                        icon: "chart.bar.fill",
                        title: "Not Enough Data",
                        description: "Insights require at least a few days of captured activity. Keep capturing and check back soon for weekly charts and trends.",
                        ctaTitle: "Start Capturing",
                        ctaAction: {
                            appState.startCapture()
                        }
                    )
                } else {
                    // MARK: - Key Metrics Row
                    HStack(spacing: MPTheme.Spacing.lg) {
                        InsightMetricCard(
                            label: "AVG DAILY",
                            value: String(format: "%.1fh", avgDailyHours),
                            icon: "clock.fill",
                            color: MPTheme.Colors.textPrimary
                        )
                        InsightMetricCard(
                            label: "PRODUCTIVITY",
                            value: "\(Int(insight.avgProductivityScore * 100))%",
                            icon: "bolt.fill",
                            color: productivityColor
                        )
                        if !insight.categoryBreakdown.isEmpty {
                            InsightMetricCard(
                                label: "TOP CATEGORY",
                                value: topCategory.category.rawValue,
                                icon: "star.fill",
                                color: MPTheme.Colors.forCategory(topCategory.category)
                            )
                        }
                    }

                    // MARK: - Daily Screen Time Chart
                    if !insight.dailyScreenTime.isEmpty {
                        VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
                            Text("DAILY SCREEN TIME")
                                .sectionLabel()

                            if #available(macOS 14.0, *) {
                                DailyScreenTimeChart(metrics: insight.dailyScreenTime)
                                    .frame(height: 200)
                                    .cardStyle()
                            } else {
                                // macOS 13 fallback — custom bar chart
                                DailyScreenTimeBarsFallback(metrics: insight.dailyScreenTime)
                                    .frame(height: 200)
                                    .cardStyle()
                            }
                        }
                    }

                    // MARK: - Category Breakdown
                    HStack(alignment: .top, spacing: MPTheme.Spacing.lg) {
                        if !insight.categoryBreakdown.isEmpty {
                            // Category list
                            VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
                                Text("CATEGORY BREAKDOWN")
                                    .sectionLabel()

                                VStack(spacing: MPTheme.Spacing.sm) {
                                    ForEach(insight.categoryBreakdown) { metric in
                                        CategoryRow(metric: metric)
                                    }
                                }
                                .cardStyle()
                            }
                            .frame(maxWidth: .infinity)
                        }

                        if !insight.topApps.isEmpty {
                            // Top apps list
                            VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
                                Text("TOP APPLICATIONS")
                                    .sectionLabel()

                                VStack(spacing: MPTheme.Spacing.sm) {
                                    ForEach(Array(insight.topApps.enumerated()), id: \.element.id) { index, app in
                                        TopAppRow(app: app, rank: index + 1)
                                    }
                                }
                                .cardStyle()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(MPTheme.Spacing.xxl)
        }
        .background(MPTheme.Colors.bgPrimary)
    }

    // MARK: - Computed

    private var avgDailyHours: Double {
        let total = insight.dailyScreenTime.reduce(0.0) { $0 + $1.value }
        return total / Double(max(insight.dailyScreenTime.count, 1))
    }

    private var topCategory: CategoryMetric {
        insight.categoryBreakdown.max(by: { $0.hours < $1.hours }) ?? insight.categoryBreakdown[0]
    }

    private var productivityColor: Color {
        if insight.avgProductivityScore > 0.75 { return MPTheme.Colors.success }
        if insight.avgProductivityScore > 0.5 { return MPTheme.Colors.warning }
        return MPTheme.Colors.error
    }

    private var trendColor: Color {
        switch insight.trend {
        case .up: return MPTheme.Colors.success
        case .down: return MPTheme.Colors.error
        case .stable: return MPTheme.Colors.textTertiary
        }
    }
}

// MARK: - Insight Metric Card

struct InsightMetricCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
            HStack(spacing: MPTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color.opacity(0.7))
                Text(label)
                    .sectionLabel()
            }

            Text(value)
                .font(MPTheme.Typography.monoBold(22))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Daily Screen Time Chart (macOS 14+)

@available(macOS 14.0, *)
struct DailyScreenTimeChart: View {
    let metrics: [DailyMetric]

    var body: some View {
        Chart(metrics) { metric in
            BarMark(
                x: .value("Day", metric.date.dayOfWeek),
                y: .value("Hours", metric.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [MPTheme.Colors.accent, MPTheme.Colors.accent.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(4)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(Int(hours))h")
                            .font(MPTheme.Typography.mono(10))
                            .foregroundColor(MPTheme.Colors.textTertiary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(MPTheme.Colors.border)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(MPTheme.Typography.mono(10))
                    .foregroundStyle(MPTheme.Colors.textTertiary)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
        }
    }
}

// MARK: - Fallback Bar Chart (macOS 13)

struct DailyScreenTimeBarsFallback: View {
    let metrics: [DailyMetric]

    private var maxValue: Double {
        metrics.map(\.value).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: MPTheme.Spacing.md) {
            ForEach(metrics) { metric in
                VStack(spacing: MPTheme.Spacing.sm) {
                    Text(String(format: "%.1f", metric.value))
                        .font(MPTheme.Typography.mono(9))
                        .foregroundColor(MPTheme.Colors.textTertiary)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [MPTheme.Colors.accent, MPTheme.Colors.accent.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: max(CGFloat(metric.value / maxValue) * 150, 8))

                    Text(metric.date.dayOfWeek)
                        .font(MPTheme.Typography.mono(10))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                }
            }
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let metric: CategoryMetric
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: MPTheme.Spacing.md) {
            Circle()
                .fill(MPTheme.Colors.forCategory(metric.category))
                .frame(width: 8, height: 8)

            Text(metric.category.rawValue)
                .font(MPTheme.Typography.body(12))
                .foregroundColor(MPTheme.Colors.textSecondary)

            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MPTheme.Colors.bgSecondary)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(MPTheme.Colors.forCategory(metric.category))
                        .frame(width: geo.size.width * metric.percentage, height: 4)
                }
            }
            .frame(width: 80, height: 4)

            Text(String(format: "%.1fh", metric.hours))
                .font(MPTheme.Typography.mono(11))
                .foregroundColor(MPTheme.Colors.textPrimary)
                .frame(width: 40, alignment: .trailing)

            Text("\(Int(metric.percentage * 100))%")
                .font(MPTheme.Typography.mono(10))
                .foregroundColor(MPTheme.Colors.textTertiary)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, MPTheme.Spacing.xs)
        .padding(.horizontal, MPTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .fill(isHovered ? MPTheme.Colors.bgHover : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.category.rawValue): \(String(format: "%.1f", metric.hours)) hours, \(Int(metric.percentage * 100)) percent")
    }
}

// MARK: - Top App Row

struct TopAppRow: View {
    let app: AppUsage
    let rank: Int
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: MPTheme.Spacing.md) {
            Text("\(rank)")
                .font(MPTheme.Typography.mono(11))
                .foregroundColor(MPTheme.Colors.textTertiary)
                .frame(width: 16)

            Image(systemName: app.appIcon)
                .font(.system(size: 14))
                .foregroundColor(MPTheme.Colors.forCategory(app.category))
                .frame(width: 20)

            Text(app.appName)
                .font(MPTheme.Typography.body(12))
                .foregroundColor(MPTheme.Colors.textSecondary)

            Spacer()

            Text(app.duration.formattedDuration)
                .font(MPTheme.Typography.monoBold(11))
                .foregroundColor(MPTheme.Colors.textPrimary)
        }
        .padding(.vertical, MPTheme.Spacing.xs)
        .padding(.horizontal, MPTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .fill(isHovered ? MPTheme.Colors.bgHover : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank): \(app.appName), \(app.duration.formattedDuration)")
    }
}
