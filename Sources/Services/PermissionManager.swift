import Foundation
import AppKit
import CoreGraphics

// MARK: - Permission Manager

/// Handles checking and requesting Screen Recording and Accessibility permissions.
/// On macOS, these permissions are controlled at the OS level. We can detect
/// whether we have them, but the user must grant them in System Preferences/Settings.
final class PermissionManager: ObservableObject {

    @Published var screenRecordingGranted: Bool = false
    @Published var accessibilityGranted: Bool = false

    /// Callback fired when a previously-granted permission is revoked while the app is running.
    var onPermissionRevoked: ((String) -> Void)?

    private var recheckTimer: Timer?
    private static let recheckInterval: TimeInterval = 10.0 // Re-check every 10 seconds

    init() {
        checkScreenRecordingPermission()
        checkAccessibilityPermission()
    }

    deinit {
        stopPeriodicRecheck()
    }

    // MARK: - Screen Recording

    /// Check if Screen Recording permission has been granted.
    ///
    /// macOS has no direct API to query this. The standard approach is to attempt
    /// a minimal CGWindowList capture and see if window names are returned (they are
    /// blank/nil when permission is denied).
    func checkScreenRecordingPermission() {
        let granted = testScreenRecordingAccess()
        DispatchQueue.main.async {
            let wasGranted = self.screenRecordingGranted
            self.screenRecordingGranted = granted

            // Detect revocation
            if wasGranted && !granted {
                self.onPermissionRevoked?("Screen Recording")
            }
        }
    }

    /// Prompt the user to open System Preferences -> Privacy -> Screen Recording.
    func requestScreenRecordingPermission() {
        // On macOS 13+, open the Screen Recording pane directly
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Accessibility

    /// Check if Accessibility (AX) API access is granted (needed for browser URL extraction).
    func checkAccessibilityPermission() {
        let granted = AXIsProcessTrusted()
        DispatchQueue.main.async {
            let wasGranted = self.accessibilityGranted
            self.accessibilityGranted = granted

            // Detect revocation
            if wasGranted && !granted {
                self.onPermissionRevoked?("Accessibility")
            }
        }
    }

    /// Prompt the user to grant Accessibility access.
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Periodic Re-check

    /// Start a periodic timer that re-checks both permissions.
    /// Useful for detecting when the user grants or revokes access while the app is running.
    func startPeriodicRecheck() {
        guard recheckTimer == nil else { return }

        recheckTimer = Timer.scheduledTimer(withTimeInterval: Self.recheckInterval, repeats: true) { [weak self] _ in
            self?.checkScreenRecordingPermission()
            self?.checkAccessibilityPermission()
        }
    }

    /// Stop the periodic re-check timer.
    func stopPeriodicRecheck() {
        recheckTimer?.invalidate()
        recheckTimer = nil
    }

    /// Perform a single re-check of both permissions.
    func recheckAll() {
        checkScreenRecordingPermission()
        checkAccessibilityPermission()
    }

    // MARK: - Private

    /// The standard detection trick: list on-screen windows and check if we can read
    /// window names for apps other than our own. If Screen Recording is denied,
    /// window names come back as nil for other apps.
    private func testScreenRecordingAccess() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        let myPID = ProcessInfo.processInfo.processIdentifier

        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID != myPID,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { continue }

            // If we can read the window name of another app, we have permission
            if let name = info[kCGWindowName as String] as? String, !name.isEmpty {
                return true
            }
        }

        // If we cannot read any other app window names, treat as not granted.
        // This avoids false positives during onboarding (e.g. when only our window is visible).
        return false
    }
}
