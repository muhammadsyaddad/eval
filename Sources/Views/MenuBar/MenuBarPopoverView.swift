import SwiftUI

// MARK: - Menu Bar Popover View

/// Compact popover displayed when clicking the menu bar icon.
/// Shows capture status, today's quick stats, toggle control, and navigation links.
struct MenuBarPopoverView: View {
    @ObservedObject var menuBarManager: MenuBarManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status
            MenuBarHeaderView(menuBarManager: menuBarManager)

            Divider()
                .background(MPTheme.Colors.border)

            // Quick stats
            MenuBarStatsView(menuBarManager: menuBarManager)

            Divider()
                .background(MPTheme.Colors.border)

            // Actions
            MenuBarActionsView(menuBarManager: menuBarManager)
        }
        .frame(width: 280)
        .background(MPTheme.Colors.bgSecondary)
    }
}

// MARK: - Header

private struct MenuBarHeaderView: View {
    @ObservedObject var menuBarManager: MenuBarManager
    @EnvironmentObject var appState: AppState

    private var captureStatus: CaptureStatus {
        appState.captureScheduler.status
    }

    private var statusColor: Color {
        switch captureStatus {
        case .capturing: return MPTheme.Colors.success
        case .paused: return MPTheme.Colors.warning
        case .idle: return MPTheme.Colors.textTertiary
        case .permissionDenied: return MPTheme.Colors.error
        case .error: return MPTheme.Colors.error
        }
    }

    var body: some View {
        HStack(spacing: MPTheme.Spacing.sm) {
            // Animated status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: captureStatus.isActive ? statusColor.opacity(0.6) : .clear, radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: MPTheme.Spacing.xs) {
                    Text("MACPULSE")
                        .font(MPTheme.Typography.label(10))
                        .foregroundColor(MPTheme.Colors.textPrimary)
                        .tracking(2)

                    Spacer()

                    Text(captureStatus.label.uppercased())
                        .font(MPTheme.Typography.mono(9))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, MPTheme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: MPTheme.Radius.sm))
                }

                if menuBarManager.captureCount > 0 {
                    Text("\(menuBarManager.captureCount) captures today")
                        .font(MPTheme.Typography.mono(9))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                }
            }
        }
        .padding(MPTheme.Spacing.md)
    }
}

// MARK: - Quick Stats

private struct MenuBarStatsView: View {
    @ObservedObject var menuBarManager: MenuBarManager
    @EnvironmentObject var appState: AppState

    private var productivityColor: Color {
        let score = appState.todaySummary.productivityScore
        if score > 0.75 { return MPTheme.Colors.success }
        if score > 0.5 { return MPTheme.Colors.warning }
        return score > 0 ? MPTheme.Colors.error : MPTheme.Colors.textTertiary
    }

    var body: some View {
        VStack(spacing: MPTheme.Spacing.sm) {
            HStack(spacing: MPTheme.Spacing.md) {
                // Screen time
                MenuBarStatItem(
                    icon: "desktopcomputer",
                    label: "Screen Time",
                    value: appState.todaySummary.totalScreenTime.formattedDuration,
                    color: MPTheme.Colors.accent
                )

                Spacer()

                // Activities
                MenuBarStatItem(
                    icon: "list.bullet",
                    label: "Activities",
                    value: "\(appState.todaySummary.activityCount)",
                    color: MPTheme.Colors.info
                )

                Spacer()

                // Productivity
                MenuBarStatItem(
                    icon: "chart.bar.fill",
                    label: "Productivity",
                    value: "\(Int(appState.todaySummary.productivityScore * 100))%",
                    color: productivityColor
                )
            }

            // Top app
            let topAppName = appState.todaySummary.topApps.first?.appName ?? "—"
            if topAppName != "—" {
                HStack(spacing: MPTheme.Spacing.sm) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(MPTheme.Colors.accent.opacity(0.6))

                    Text("Top app:")
                        .font(MPTheme.Typography.mono(10))
                        .foregroundColor(MPTheme.Colors.textTertiary)

                    Text(topAppName)
                        .font(MPTheme.Typography.monoBold(10))
                        .foregroundColor(MPTheme.Colors.textSecondary)

                    Spacer()
                }
            }
        }
        .padding(MPTheme.Spacing.md)
    }
}

// MARK: - Stat Item

private struct MenuBarStatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: MPTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)

            Text(value)
                .font(MPTheme.Typography.monoBold(13))
                .foregroundColor(MPTheme.Colors.textPrimary)

            Text(label)
                .font(MPTheme.Typography.mono(8))
                .foregroundColor(MPTheme.Colors.textTertiary)
        }
    }
}

// MARK: - Actions

private struct MenuBarActionsView: View {
    @ObservedObject var menuBarManager: MenuBarManager
    @EnvironmentObject var appState: AppState

    private var captureStatus: CaptureStatus {
        appState.captureScheduler.status
    }

    private var toggleIcon: String {
        switch captureStatus {
        case .capturing: return "pause.fill"
        case .paused, .idle, .permissionDenied, .error: return "play.fill"
        }
    }

    private var toggleLabel: String {
        switch captureStatus {
        case .capturing: return "Pause Capture"
        case .paused: return "Resume Capture"
        case .idle, .permissionDenied, .error: return "Start Capture"
        }
    }

    private func toggleCapture() {
        switch captureStatus {
        case .idle, .permissionDenied, .error:
            appState.startCapture()
        case .capturing:
            appState.captureScheduler.pause()
        case .paused:
            appState.captureScheduler.resume()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toggle capture button
            Button(action: { toggleCapture() }) {
                HStack(spacing: MPTheme.Spacing.sm) {
                    Image(systemName: toggleIcon)
                        .font(.system(size: 12))
                        .foregroundColor(MPTheme.Colors.accent)
                        .frame(width: 16)

                    Text(toggleLabel)
                        .font(MPTheme.Typography.body(12))
                        .foregroundColor(MPTheme.Colors.textPrimary)

                    Spacer()

                    // Keyboard shortcut hint
                    Text("\u{2318}\u{21E7}C")
                        .font(MPTheme.Typography.mono(10))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                }
                .padding(.horizontal, MPTheme.Spacing.md)
                .padding(.vertical, MPTheme.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            Divider()
                .background(MPTheme.Colors.borderSubtle)
                .padding(.horizontal, MPTheme.Spacing.sm)

            // Open Today
            MenuBarNavigationButton(
                icon: "sun.max.fill",
                label: "Open Today",
                action: { menuBarManager.openMainWindow(tab: .today) }
            )

            // Open Insights
            MenuBarNavigationButton(
                icon: "chart.bar.fill",
                label: "Open Insights",
                action: { menuBarManager.openMainWindow(tab: .insights) }
            )

            // Open Settings
            MenuBarNavigationButton(
                icon: "gearshape.fill",
                label: "Settings",
                action: { menuBarManager.openMainWindow(tab: .settings) }
            )

            Divider()
                .background(MPTheme.Colors.borderSubtle)
                .padding(.horizontal, MPTheme.Spacing.sm)

            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack(spacing: MPTheme.Spacing.sm) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                        .frame(width: 16)

                    Text("Quit Eval")
                        .font(MPTheme.Typography.body(12))
                        .foregroundColor(MPTheme.Colors.textSecondary)

                    Spacer()

                    Text("\u{2318}Q")
                        .font(MPTheme.Typography.mono(10))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                }
                .padding(.horizontal, MPTheme.Spacing.md)
                .padding(.vertical, MPTheme.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, MPTheme.Spacing.xs)
    }
}

// MARK: - Navigation Button

private struct MenuBarNavigationButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MPTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(MPTheme.Colors.textSecondary)
                    .frame(width: 16)

                Text(label)
                    .font(MPTheme.Typography.body(12))
                    .foregroundColor(MPTheme.Colors.textPrimary)

                Spacer()
            }
            .padding(.horizontal, MPTheme.Spacing.md)
            .padding(.vertical, MPTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
