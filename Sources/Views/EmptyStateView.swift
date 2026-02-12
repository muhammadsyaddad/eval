import SwiftUI

// MARK: - Empty State View (M6)

/// Reusable empty state component with icon, title, description, and optional CTA button.
/// Used across TodayView, HistoryView, InsightsView, and search results when no data is available.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var ctaTitle: String? = nil
    var ctaAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: MPTheme.Spacing.xl) {
            Spacer()
                .frame(height: MPTheme.Spacing.xxxl)

            // Icon
            ZStack {
                Circle()
                    .fill(MPTheme.Colors.accentSubtle)
                    .frame(width: 72, height: 72)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .thin))
                    .foregroundColor(MPTheme.Colors.accent.opacity(0.7))
            }

            // Text
            VStack(spacing: MPTheme.Spacing.sm) {
                Text(title)
                    .font(MPTheme.Typography.heading(16))
                    .foregroundColor(MPTheme.Colors.textPrimary)

                Text(description)
                    .font(MPTheme.Typography.body(13))
                    .foregroundColor(MPTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 340)
            }

            // Optional CTA button
            if let ctaTitle = ctaTitle, let ctaAction = ctaAction {
                Button(action: ctaAction) {
                    HStack(spacing: MPTheme.Spacing.sm) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text(ctaTitle)
                            .font(MPTheme.Typography.caption(12))
                    }
                }
                .buttonStyle(MPAccentButtonStyle())
                .padding(.top, MPTheme.Spacing.sm)
            }

            Spacer()
                .frame(height: MPTheme.Spacing.xxxl)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}

// MARK: - Error Banner View (M6)

/// A dismissible error banner that slides in from the top of the view.
struct ErrorBannerView: View {
    let error: AppError
    let onDismiss: () -> Void

    private var bannerColor: Color {
        switch error.severity {
        case .info: return MPTheme.Colors.info
        case .warning: return MPTheme.Colors.warning
        case .error: return MPTheme.Colors.error
        }
    }

    private var bannerIcon: String {
        switch error.severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: MPTheme.Spacing.md) {
            Image(systemName: bannerIcon)
                .font(.system(size: 14))
                .foregroundColor(bannerColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(MPTheme.Typography.caption(12))
                    .foregroundColor(MPTheme.Colors.textPrimary)

                Text(error.message)
                    .font(MPTheme.Typography.body(11))
                    .foregroundColor(MPTheme.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(MPTheme.Colors.textTertiary)
                    .padding(4)
                    .background(MPTheme.Colors.bgSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(MPTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .fill(MPTheme.Colors.bgTertiary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .stroke(bannerColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, MPTheme.Spacing.lg)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(error.severity.rawValue): \(error.title). \(error.message)")
    }
}
