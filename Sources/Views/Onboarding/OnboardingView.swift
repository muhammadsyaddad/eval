import SwiftUI

// MARK: - Onboarding View (M6)

/// First-launch onboarding flow: Welcome → Permissions → Quick Tour → Start Capturing.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage: Int = 0

    private let totalPages = 4

    var body: some View {
        ZStack {
            MPTheme.Colors.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                ZStack {
                    switch currentPage {
                    case 0:
                        WelcomePage()
                    case 1:
                        PermissionsPage()
                    case 2:
                        TourPage()
                    default:
                        GetStartedPage()
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Navigation footer
                OnboardingFooter(
                    currentPage: $currentPage,
                    totalPages: totalPages,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.completeOnboarding()
                        }
                    }
                )
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

// MARK: - Welcome Page

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: MPTheme.Spacing.xl) {
            Spacer()

            // App icon area
            ZStack {
                Circle()
                    .fill(MPTheme.Colors.accentSubtle)
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(MPTheme.Colors.accent)
                    .frame(width: 12, height: 12)
                    .shadow(color: MPTheme.Colors.accent.opacity(0.6), radius: 8)
            }

            VStack(spacing: MPTheme.Spacing.md) {
                Text("Welcome to Eval")
                    .font(MPTheme.Typography.display(28))
                    .foregroundColor(MPTheme.Colors.textPrimary)

                Text("Your private, on-device activity recorder")
                    .font(MPTheme.Typography.body(15))
                    .foregroundColor(MPTheme.Colors.textSecondary)
            }

            VStack(alignment: .leading, spacing: MPTheme.Spacing.lg) {
                OnboardingBullet(
                    icon: "lock.shield.fill",
                    title: "100% Private",
                    description: "All data stays on your Mac. No cloud, no telemetry."
                )
                OnboardingBullet(
                    icon: "camera.fill",
                    title: "Automatic Capture",
                    description: "Records your active window at configurable intervals."
                )
                OnboardingBullet(
                    icon: "sparkles",
                    title: "AI Summaries",
                    description: "Local summarization of your daily activity patterns."
                )
            }
            .frame(maxWidth: 380)
            .padding(.top, MPTheme.Spacing.lg)

            Spacer()
        }
    }
}

// MARK: - Permissions Page

private struct PermissionsPage: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: MPTheme.Spacing.xl) {
            Spacer()

            VStack(spacing: MPTheme.Spacing.md) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundColor(MPTheme.Colors.accent)

                Text("Permissions Required")
                    .font(MPTheme.Typography.display(24))
                    .foregroundColor(MPTheme.Colors.textPrimary)

                Text("Eval needs access to capture your screen content")
                    .font(MPTheme.Typography.body(13))
                    .foregroundColor(MPTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: MPTheme.Spacing.lg) {
                // Screen Recording
                PermissionRow(
                    icon: "camera.metering.spot",
                    title: "Screen Recording",
                    description: "Required to capture on-screen content",
                    isGranted: appState.permissionManager.screenRecordingGranted,
                    onRequest: {
                        appState.permissionManager.requestScreenRecordingPermission()
                    }
                )

                // Accessibility
                PermissionRow(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "Optional — enables browser URL extraction",
                    isGranted: appState.permissionManager.accessibilityGranted,
                    isRequired: false,
                    onRequest: {
                        appState.permissionManager.requestAccessibilityPermission()
                    }
                )
            }
            .frame(maxWidth: 420)
            .cardStyle()

            Text("You can change these later in System Settings")
                .font(MPTheme.Typography.caption(11))
                .foregroundColor(MPTheme.Colors.textTertiary)
            Text("macOS remembers these permissions even if you uninstall the app.")
                .font(MPTheme.Typography.caption(11))
                .foregroundColor(MPTheme.Colors.textTertiary)

            Spacer()
        }
    }
}

// MARK: - Tour Page

private struct TourPage: View {
    var body: some View {
        VStack(spacing: MPTheme.Spacing.xl) {
            Spacer()

            VStack(spacing: MPTheme.Spacing.md) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundColor(MPTheme.Colors.accent)

                Text("Quick Tour")
                    .font(MPTheme.Typography.display(24))
                    .foregroundColor(MPTheme.Colors.textPrimary)
            }

            // Tab descriptions
            VStack(spacing: MPTheme.Spacing.md) {
                TourItem(
                    icon: "sun.max.fill",
                    tab: "Today",
                    description: "See today's screen time, AI summary, and activity timeline"
                )
                TourItem(
                    icon: "clock.arrow.circlepath",
                    tab: "History",
                    description: "Search and browse past daily summaries and activities"
                )
                TourItem(
                    icon: "chart.bar.fill",
                    tab: "Insights",
                    description: "Weekly charts, category breakdowns, and top applications"
                )
                TourItem(
                    icon: "gearshape.fill",
                    tab: "Settings",
                    description: "Configure capture interval, exclusions, and storage"
                )
            }
            .frame(maxWidth: 420)
            .cardStyle()

            Spacer()
        }
    }
}

// MARK: - Get Started Page

private struct GetStartedPage: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: MPTheme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MPTheme.Colors.accentSubtle)
                    .frame(width: 100, height: 100)

                Image(systemName: "play.fill")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundColor(MPTheme.Colors.accent)
            }

            VStack(spacing: MPTheme.Spacing.md) {
                Text("Ready to Go")
                    .font(MPTheme.Typography.display(28))
                    .foregroundColor(MPTheme.Colors.textPrimary)

                Text("Eval will capture your screen activity and generate\nintelligent summaries — all on-device, all private.")
                    .font(MPTheme.Typography.body(13))
                    .foregroundColor(MPTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: MPTheme.Spacing.md) {
                HStack(spacing: MPTheme.Spacing.sm) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                    Text("Tip: Use")
                        .font(MPTheme.Typography.caption(11))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                    Text("Cmd+Shift+C")
                        .font(MPTheme.Typography.monoBold(11))
                        .foregroundColor(MPTheme.Colors.accent)
                    Text("to toggle capture anytime")
                        .font(MPTheme.Typography.caption(11))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Supporting Views

private struct OnboardingBullet: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: MPTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(MPTheme.Colors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                Text(title)
                    .font(MPTheme.Typography.heading(14))
                    .foregroundColor(MPTheme.Colors.textPrimary)
                Text(description)
                    .font(MPTheme.Typography.body(12))
                    .foregroundColor(MPTheme.Colors.textSecondary)
            }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    var isRequired: Bool = true
    let onRequest: () -> Void

    var body: some View {
        HStack(spacing: MPTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isGranted ? MPTheme.Colors.success : (isRequired ? MPTheme.Colors.error : MPTheme.Colors.warning))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                HStack(spacing: MPTheme.Spacing.sm) {
                    Text(title)
                        .font(MPTheme.Typography.body(13))
                        .foregroundColor(MPTheme.Colors.textPrimary)
                    if !isRequired {
                        Text("Optional")
                            .font(MPTheme.Typography.mono(9))
                            .foregroundColor(MPTheme.Colors.textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(MPTheme.Colors.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                Text(description)
                    .font(MPTheme.Typography.caption(11))
                    .foregroundColor(MPTheme.Colors.textTertiary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(MPTheme.Colors.success)
            } else {
                Button("Grant Access", action: onRequest)
                    .buttonStyle(MPAccentButtonStyle())
            }
        }
    }
}

private struct TourItem: View {
    let icon: String
    let tab: String
    let description: String

    var body: some View {
        HStack(spacing: MPTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(MPTheme.Colors.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(tab)
                    .font(MPTheme.Typography.heading(13))
                    .foregroundColor(MPTheme.Colors.textPrimary)
                Text(description)
                    .font(MPTheme.Typography.body(11))
                    .foregroundColor(MPTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, MPTheme.Spacing.xs)
    }
}

// MARK: - Onboarding Footer

private struct OnboardingFooter: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let onComplete: () -> Void

    var body: some View {
        HStack {
            // Back button
            if currentPage > 0 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage -= 1
                    }
                }) {
                    HStack(spacing: MPTheme.Spacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                    }
                }
                .buttonStyle(MPSecondaryButtonStyle())
            }

            Spacer()

            // Page dots
            HStack(spacing: MPTheme.Spacing.sm) {
                ForEach(0..<totalPages, id: \.self) { page in
                    Circle()
                        .fill(page == currentPage ? MPTheme.Colors.accent : MPTheme.Colors.border)
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }

            Spacer()

            // Next / Get Started button
            if currentPage < totalPages - 1 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage += 1
                    }
                }) {
                    HStack(spacing: MPTheme.Spacing.xs) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .buttonStyle(MPAccentButtonStyle())
            } else {
                Button(action: onComplete) {
                    HStack(spacing: MPTheme.Spacing.xs) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Start Capturing")
                    }
                }
                .buttonStyle(MPAccentButtonStyle())
            }
        }
        .padding(.horizontal, MPTheme.Spacing.xxl)
        .padding(.vertical, MPTheme.Spacing.lg)
        .background(MPTheme.Colors.bgSecondary)
        .overlay(
            Rectangle()
                .fill(MPTheme.Colors.border)
                .frame(height: 1),
            alignment: .top
        )
    }
}
