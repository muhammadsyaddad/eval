import SwiftUI
import Combine

// MARK: - Menu Bar Manager

/// Manages the menu bar icon state and coordinates between the menu bar popover and the main app.
/// Tracks capture status, today's quick stats, and provides actions for the popover UI.
final class MenuBarManager: ObservableObject {

    // MARK: - Published State

    /// Current icon state for the menu bar — derived from CaptureScheduler.status.
    @Published var iconState: MenuBarIconState = .idle

    /// Quick stats for the popover.
    @Published var screenTime: TimeInterval = 0
    @Published var captureCount: Int = 0
    @Published var activityCount: Int = 0
    @Published var productivityScore: Double = 0
    @Published var topAppName: String = "—"

    // MARK: - Dependencies

    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {}

    /// Bind to an AppState to observe changes. Call once from the app scene.
    func bind(to appState: AppState) {
        self.appState = appState

        // Observe capture scheduler status → icon state
        appState.captureScheduler.$status
            .receive(on: DispatchQueue.main)
            .map { status -> MenuBarIconState in
                switch status {
                case .capturing: return .capturing
                case .paused: return .paused
                case .idle: return .idle
                case .permissionDenied: return .error
                case .error: return .error
                }
            }
            .assign(to: &$iconState)

        // Observe capture count
        appState.captureScheduler.$captureCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$captureCount)

        // Sync today's stats periodically from appState published data
        appState.$todaySummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.screenTime = summary.totalScreenTime
                self?.activityCount = summary.activityCount
                self?.productivityScore = summary.productivityScore
                self?.topAppName = summary.topApps.first?.appName ?? "—"
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// Toggle capture on/off.
    func toggleCapture() {
        guard let appState = appState else { return }
        switch appState.captureScheduler.status {
        case .idle, .permissionDenied, .error:
            appState.startCapture()
        case .capturing:
            appState.captureScheduler.pause()
        case .paused:
            appState.captureScheduler.resume()
        }
    }

    /// Open the main window and switch to a specific tab.
    func openMainWindow(tab: SidebarTab = .today) {
        guard let appState = appState else { return }
        appState.selectedTab = tab
        // Bring the main window to front
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.title.contains("Eval") || $0.isKeyWindow || !$0.title.isEmpty }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Menu Bar Icon State

enum MenuBarIconState: String {
    case capturing
    case paused
    case idle
    case error

    /// SF Symbol name for the menu bar icon.
    var systemImage: String {
        switch self {
        case .capturing: return "waveform.circle.fill"
        case .paused: return "pause.circle"
        case .idle: return "circle.dotted"
        case .error: return "exclamationmark.circle"
        }
    }

    /// Short label for the popover header.
    var label: String {
        switch self {
        case .capturing: return "Capturing"
        case .paused: return "Paused"
        case .idle: return "Idle"
        case .error: return "Error"
        }
    }

    /// Whether capture is actively running.
    var isActive: Bool {
        self == .capturing
    }
}
