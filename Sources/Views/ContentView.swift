import SwiftUI

// MARK: - Content View (Root Shell)

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ZStack {
                MPTheme.Colors.bgPrimary
                    .ignoresSafeArea()

                switch appState.selectedTab {
                case .today:
                    TodayView()
                case .history:
                    HistoryView()
                case .insights:
                    InsightsView()
                case .settings:
                    SettingsView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .overlay(alignment: .top) {
            // Error banner overlay
            if let error = appState.currentError {
                ErrorBannerView(error: error) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        appState.dismissError()
                    }
                }
                .padding(.top, MPTheme.Spacing.sm)
            }
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var hoveredTab: SidebarTab?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo area
            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                HStack(spacing: MPTheme.Spacing.sm) {
                    // Animated pulse indicator
                    Circle()
                        .fill(MPTheme.Colors.accent)
                        .frame(width: 8, height: 8)
                        .shadow(color: MPTheme.Colors.accent.opacity(0.6), radius: 4)

                    Text("EVAL")
                        .font(MPTheme.Typography.label(12))
                        .foregroundColor(MPTheme.Colors.textPrimary)
                        .tracking(3)
                }

                Text("v0.1.0 — local only")
                    .font(MPTheme.Typography.mono(10))
                    .foregroundColor(MPTheme.Colors.textTertiary)
            }
            .padding(.horizontal, MPTheme.Spacing.lg)
            .padding(.top, MPTheme.Spacing.xl)
            .padding(.bottom, MPTheme.Spacing.xxl)

            // Navigation items
            VStack(spacing: MPTheme.Spacing.xs) {
                ForEach(SidebarTab.allCases) { tab in
                    SidebarItem(
                        tab: tab,
                        isSelected: appState.selectedTab == tab,
                        isHovered: hoveredTab == tab
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.selectedTab = tab
                        }
                    }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredTab = hovering ? tab : nil
                        }
                    }
                }
            }
            .padding(.horizontal, MPTheme.Spacing.md)

            Spacer()

            // Status footer — reads from CaptureScheduler
            CaptureStatusFooter()
        }
        .frame(maxHeight: .infinity)
        .background(MPTheme.Colors.bgSecondary)
    }
}

// MARK: - Sidebar Item

struct SidebarItem: View {
    let tab: SidebarTab
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: MPTheme.Spacing.md) {
            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? MPTheme.Colors.accent : MPTheme.Colors.textSecondary)
                .frame(width: 20)

            Text(tab.rawValue)
                .font(MPTheme.Typography.body(13))
                .foregroundColor(isSelected ? MPTheme.Colors.textPrimary : MPTheme.Colors.textSecondary)

            Spacer()

            // Active indicator line
            if isSelected {
                RoundedRectangle(cornerRadius: 1)
                    .fill(MPTheme.Colors.accent)
                    .frame(width: 3, height: 16)
            }
        }
        .padding(.horizontal, MPTheme.Spacing.md)
        .padding(.vertical, MPTheme.Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                .fill(isSelected ? MPTheme.Colors.accentSubtle : (isHovered ? MPTheme.Colors.bgHover : Color.clear))
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tab.rawValue) tab\(isSelected ? ", selected" : "")")
        .accessibilityHint("Double-click to switch to \(tab.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Capture Status Footer

struct CaptureStatusFooter: View {
    @EnvironmentObject var appState: AppState

    private var scheduler: CaptureScheduler {
        appState.captureScheduler
    }

    private var statusColor: Color {
        switch scheduler.status {
        case .capturing: return MPTheme.Colors.success
        case .paused: return MPTheme.Colors.warning
        case .idle: return MPTheme.Colors.textTertiary
        case .permissionDenied: return MPTheme.Colors.error
        case .error: return MPTheme.Colors.error
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MPTheme.Spacing.sm) {
            Divider()
                .background(MPTheme.Colors.border)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scheduler.toggle()
                }
            }) {
                HStack(spacing: MPTheme.Spacing.sm) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: scheduler.status.isActive ? statusColor.opacity(0.6) : .clear, radius: 3)

                    Text(scheduler.status.label)
                        .font(MPTheme.Typography.mono(10))
                        .foregroundColor(MPTheme.Colors.textTertiary)

                    Spacer()

                    if scheduler.status.isActive || scheduler.status == .paused {
                        Text("\(scheduler.intervalSeconds)s")
                            .font(MPTheme.Typography.mono(10))
                            .foregroundColor(MPTheme.Colors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, MPTheme.Spacing.lg)
            .padding(.bottom, MPTheme.Spacing.sm)
            .accessibilityLabel("Capture status: \(scheduler.status.label)")
            .accessibilityHint("Double-click to toggle capture")

            // Capture counter
            if scheduler.captureCount > 0 {
                Text("\(scheduler.captureCount) captures today")
                    .font(MPTheme.Typography.mono(9))
                    .foregroundColor(MPTheme.Colors.textTertiary.opacity(0.6))
                    .padding(.horizontal, MPTheme.Spacing.lg)
                    .padding(.bottom, MPTheme.Spacing.lg)
            }
        }
    }
}
