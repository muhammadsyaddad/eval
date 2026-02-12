import SwiftUI

@main
struct MacPulseApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var menuBarManager = MenuBarManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(appState)
                        .frame(minWidth: 900, minHeight: 620)
                } else {
                    OnboardingView()
                        .environmentObject(appState)
                        .frame(minWidth: 600, minHeight: 500)
                }
            }
            .onAppear {
                menuBarManager.bind(to: appState)
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1120, height: 720)
        .commands {
            // Global keyboard shortcut: Cmd+Shift+C to toggle capture
            CommandGroup(after: .appInfo) {
                Button("Toggle Capture") {
                    menuBarManager.toggleCapture()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }

            // Sidebar navigation: Cmd+1/2/3/4
            CommandGroup(after: .sidebar) {
                Button("Show Today") {
                    appState.selectedTab = .today
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Show History") {
                    appState.selectedTab = .history
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Show Insights") {
                    appState.selectedTab = .insights
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Show Settings") {
                    appState.selectedTab = .settings
                }
                .keyboardShortcut("4", modifiers: .command)
            }
        }

        // MARK: - Menu Bar Extra (macOS 13+)
        MenuBarExtra {
            MenuBarPopoverView(menuBarManager: menuBarManager)
                .environmentObject(appState)
        } label: {
            MenuBarIconView(iconState: menuBarManager.iconState)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Icon View

/// The icon displayed in the system menu bar. Changes based on capture state.
struct MenuBarIconView: View {
    let iconState: MenuBarIconState

    var body: some View {
        Image(systemName: iconState.systemImage)
            .symbolRenderingMode(.hierarchical)
    }
}
