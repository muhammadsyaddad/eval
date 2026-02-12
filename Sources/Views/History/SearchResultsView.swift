import SwiftUI

// MARK: - Search Results View (M6)

/// Displays FTS5 search results with highlighted matches and date context.
struct SearchResultsView: View {
    let results: [SearchResult]
    let query: String
    let isSearching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
            if isSearching {
                // Loading state
                HStack(spacing: MPTheme.Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(.circular)
                    Text("Searching...")
                        .font(MPTheme.Typography.mono(11))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                }
                .padding(.vertical, MPTheme.Spacing.xl)
                .frame(maxWidth: .infinity)
            } else if results.isEmpty {
                // No results empty state
                SearchEmptyState(query: query)
            } else {
                // Results header
                Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                    .font(MPTheme.Typography.mono(11))
                    .foregroundColor(MPTheme.Colors.textTertiary)

                // Results grouped by date
                ForEach(groupedResults, id: \.0) { dateString, dateResults in
                    VStack(alignment: .leading, spacing: MPTheme.Spacing.sm) {
                        Text(dateString.uppercased())
                            .sectionLabel()
                            .padding(.top, MPTheme.Spacing.sm)

                        ForEach(dateResults) { result in
                            SearchResultCard(result: result, query: query)
                        }
                    }
                }
            }
        }
    }

    // Group results by date string
    private var groupedResults: [(String, [SearchResult])] {
        let grouped = Dictionary(grouping: results) { result -> String in
            result.date.fullDate
        }
        return grouped.sorted { pair1, pair2 in
            guard let d1 = pair1.value.first?.date, let d2 = pair2.value.first?.date else { return false }
            return d1 > d2
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let result: SearchResult
    let query: String
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: MPTheme.Spacing.sm) {
            // Header row: source badge + app name + timestamp
            HStack(spacing: MPTheme.Spacing.sm) {
                // Source icon
                Image(systemName: result.source.icon)
                    .font(.system(size: 10))
                    .foregroundColor(sourceColor)

                Text(result.source.rawValue)
                    .font(MPTheme.Typography.mono(9))
                    .foregroundColor(sourceColor)
                    .padding(.horizontal, MPTheme.Spacing.xs)
                    .padding(.vertical, 1)
                    .background(sourceColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                if let appName = result.appName {
                    HStack(spacing: 4) {
                        if let icon = result.appIcon {
                            Image(systemName: icon)
                                .font(.system(size: 10))
                                .foregroundColor(categoryColor)
                        }
                        Text(appName)
                            .font(MPTheme.Typography.caption(10))
                            .foregroundColor(MPTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                Text(result.date.timeString)
                    .font(MPTheme.Typography.mono(10))
                    .foregroundColor(MPTheme.Colors.textTertiary)
            }

            // Title
            Text(result.title)
                .font(MPTheme.Typography.heading(13))
                .foregroundColor(MPTheme.Colors.textPrimary)
                .lineLimit(1)

            // Highlighted snippet
            HighlightedText(text: result.snippet, highlight: query)
                .font(MPTheme.Typography.body(12))
                .foregroundColor(MPTheme.Colors.textSecondary)
                .lineLimit(3)
                .lineSpacing(2)
        }
        .padding(MPTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .fill(isHovered ? MPTheme.Colors.bgHover : MPTheme.Colors.bgTertiary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .stroke(MPTheme.Colors.border, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.source.rawValue) result: \(result.title). \(result.snippet)")
    }

    private var sourceColor: Color {
        switch result.source {
        case .activityEntry: return MPTheme.Colors.accent
        case .dailySummary: return MPTheme.Colors.info
        case .capture: return MPTheme.Colors.categoryTeal
        }
    }

    private var categoryColor: Color {
        if let category = result.category {
            return MPTheme.Colors.forCategory(category)
        }
        return MPTheme.Colors.textTertiary
    }
}

// MARK: - Highlighted Text

/// Renders text with matching query terms bolded in the accent color.
struct HighlightedText: View {
    let text: String
    let highlight: String

    var body: some View {
        highlightedContent
    }

    private var highlightedContent: Text {
        guard !highlight.isEmpty else {
            return Text(text)
        }

        let lowercasedText = text.lowercased()
        let lowercasedHighlight = highlight.lowercased()

        // Find all ranges of the query in the text
        var result = Text("")
        var currentIndex = lowercasedText.startIndex

        while currentIndex < lowercasedText.endIndex {
            if let range = lowercasedText.range(of: lowercasedHighlight, range: currentIndex..<lowercasedText.endIndex) {
                // Add non-matching prefix
                if currentIndex < range.lowerBound {
                    let prefix = String(text[currentIndex..<range.lowerBound])
                    result = result + Text(prefix)
                }

                // Add highlighted match (using original case from text)
                let matchText = String(text[range])
                result = result + Text(matchText)
                    .bold()
                    .foregroundColor(MPTheme.Colors.accent)

                currentIndex = range.upperBound
            } else {
                // Add remaining text
                let remaining = String(text[currentIndex...])
                result = result + Text(remaining)
                break
            }
        }

        return result
    }
}

// MARK: - Search Empty State

struct SearchEmptyState: View {
    let query: String

    var body: some View {
        VStack(spacing: MPTheme.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .thin))
                .foregroundColor(MPTheme.Colors.textTertiary)

            VStack(spacing: MPTheme.Spacing.sm) {
                Text("No results for \"\(query)\"")
                    .font(MPTheme.Typography.heading(14))
                    .foregroundColor(MPTheme.Colors.textSecondary)

                Text("Try different keywords or check your spelling")
                    .font(MPTheme.Typography.body(12))
                    .foregroundColor(MPTheme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MPTheme.Spacing.xxxl)
    }
}
