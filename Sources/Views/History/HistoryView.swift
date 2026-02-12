import SwiftUI
import Combine

// MARK: - History View

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    @State private var selectedSummary: DaySummary?
    @State private var searchDebounceTask: DispatchWorkItem?

    private var summaries: [DaySummary] {
        appState.historySummaries
    }

    /// True when the user has typed something and we should show search results instead of history.
    private var isInSearchMode: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Group summaries by month (for non-search mode)
    private var groupedByMonth: [(String, [DaySummary])] {
        let grouped = Dictionary(grouping: summaries) { summary -> String in
            summary.date.monthYear
        }
        return grouped.sorted { pair1, pair2 in
            guard let d1 = pair1.value.first?.date, let d2 = pair2.value.first?.date else { return false }
            return d1 > d2
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: MPTheme.Spacing.xl) {

                // MARK: - Header + Search
                VStack(alignment: .leading, spacing: MPTheme.Spacing.lg) {
                    Text("History")
                        .font(MPTheme.Typography.display(32))
                        .foregroundColor(MPTheme.Colors.textPrimary)

                    // Search bar
                    HStack(spacing: MPTheme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(MPTheme.Colors.textTertiary)

                        TextField("Search activities, summaries, and captures...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(MPTheme.Typography.body(13))
                            .foregroundColor(MPTheme.Colors.textPrimary)
                            .onChange(of: searchText) { newValue in
                                debounceSearch(query: newValue)
                            }
                            .accessibilityLabel("Search")
                            .accessibilityHint("Search across all activity history using full-text search")

                        if appState.isSearching {
                            ProgressView()
                                .scaleEffect(0.6)
                                .progressViewStyle(.circular)
                        }

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                appState.clearSearch()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(MPTheme.Colors.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, MPTheme.Spacing.md)
                    .padding(.vertical, MPTheme.Spacing.sm + 2)
                    .background(MPTheme.Colors.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: MPTheme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                            .stroke(MPTheme.Colors.border, lineWidth: 1)
                    )
                }

                // MARK: - Content
                if isInSearchMode {
                    // FTS5 search results
                    SearchResultsView(
                        results: appState.searchResults,
                        query: searchText,
                        isSearching: appState.isSearching
                    )
                } else if summaries.isEmpty {
                    // Empty state — no history data yet
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "No Activity History",
                        description: "Your activity history will appear here once capturing begins. Start a capture session to begin tracking.",
                        ctaTitle: "Start Capturing",
                        ctaAction: {
                            appState.startCapture()
                        }
                    )
                } else {
                    // Normal history view — grouped by month
                    ForEach(groupedByMonth, id: \.0) { monthName, daySummaries in
                        VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
                            Text(monthName.uppercased())
                                .sectionLabel()
                                .padding(.top, MPTheme.Spacing.sm)

                            ForEach(daySummaries) { summary in
                                HistoryDayCard(
                                    summary: summary,
                                    isExpanded: selectedSummary?.id == summary.id
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        if selectedSummary?.id == summary.id {
                                            selectedSummary = nil
                                        } else {
                                            selectedSummary = summary
                                        }
                                    }
                                }
                                .accessibilityLabel("Activity for \(summary.date.fullDate). \(summary.aiSummary.isEmpty ? "No summary yet." : summary.aiSummary)")
                                .accessibilityHint(selectedSummary?.id == summary.id ? "Tap to collapse" : "Tap to expand details")
                            }
                        }
                    }
                }
            }
            .padding(MPTheme.Spacing.xxl)
        }
        .background(MPTheme.Colors.bgPrimary)
    }

    // MARK: - Debounced Search

    /// Debounce search input by 300ms to avoid excessive FTS queries.
    private func debounceSearch(query: String) {
        searchDebounceTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appState.clearSearch()
            return
        }

        let task = DispatchWorkItem { [trimmed] in
            appState.performSearch(query: trimmed)
        }
        searchDebounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }
}

// MARK: - History Day Card

struct HistoryDayCard: View {
    let summary: DaySummary
    let isExpanded: Bool
    @State private var isHovered = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: MPTheme.Spacing.lg) {
                // Date block
                VStack(spacing: 2) {
                    Text(Self.weekdayFormatter.string(from: summary.date).uppercased())
                        .font(MPTheme.Typography.label(9))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                    Text(Self.dayFormatter.string(from: summary.date))
                        .font(MPTheme.Typography.monoBold(20))
                        .foregroundColor(MPTheme.Colors.textPrimary)
                }
                .frame(width: 40)

                // Vertical divider
                Rectangle()
                    .fill(MPTheme.Colors.border)
                    .frame(width: 1, height: 36)

                // Summary
                VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                    Text(summary.aiSummary.isEmpty ? "No summary yet." : summary.aiSummary)
                        .font(MPTheme.Typography.body(12))
                        .foregroundColor(MPTheme.Colors.textSecondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .lineSpacing(2)
                }

                Spacer()

                // Metrics
                VStack(alignment: .trailing, spacing: MPTheme.Spacing.xs) {
                    Text(summary.totalScreenTime.formattedHoursMinutes)
                        .font(MPTheme.Typography.monoBold(13))
                        .foregroundColor(MPTheme.Colors.textPrimary)

                    ProductivityPill(score: summary.productivityScore)
                }
            }
            .padding(MPTheme.Spacing.md)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
                    Rectangle()
                        .fill(MPTheme.Colors.border)
                        .frame(height: 1)
                        .padding(.horizontal, MPTheme.Spacing.md)

                    // Top apps in expanded view
                    HStack(spacing: MPTheme.Spacing.xl) {
                        ForEach(summary.topApps) { app in
                            HStack(spacing: MPTheme.Spacing.sm) {
                                Image(systemName: app.appIcon)
                                    .font(.system(size: 11))
                                    .foregroundColor(MPTheme.Colors.forCategory(app.category))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.appName)
                                        .font(MPTheme.Typography.caption(11))
                                        .foregroundColor(MPTheme.Colors.textSecondary)
                                    Text(app.duration.formattedDuration)
                                        .font(MPTheme.Typography.mono(10))
                                        .foregroundColor(MPTheme.Colors.textTertiary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, MPTheme.Spacing.md)
                    .padding(.bottom, MPTheme.Spacing.md)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .fill(isHovered || isExpanded ? MPTheme.Colors.bgHover : MPTheme.Colors.bgTertiary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .stroke(
                    isExpanded ? MPTheme.Colors.accent.opacity(0.2) : MPTheme.Colors.border,
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Productivity Pill

struct ProductivityPill: View {
    let score: Double

    private var color: Color {
        if score > 0.75 { return MPTheme.Colors.success }
        if score > 0.5 { return MPTheme.Colors.warning }
        return MPTheme.Colors.error
    }

    var body: some View {
        Text("\(Int(score * 100))%")
            .font(MPTheme.Typography.mono(10))
            .foregroundColor(color)
            .padding(.horizontal, MPTheme.Spacing.sm)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: MPTheme.Radius.sm))
    }
}
