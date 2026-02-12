import Foundation
import AppKit

// MARK: - Window Metadata Service Protocol

protocol WindowMetadataServiceProtocol {
    /// Read metadata from the currently active (frontmost) window.
    func readFrontmostWindowMetadata() -> WindowMetadata
}

// MARK: - Window Metadata Service

final class WindowMetadataService: WindowMetadataServiceProtocol {

    /// Known browser bundle identifiers for URL extraction.
    private static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "org.mozilla.firefox",
        "company.thebrowser.Browser",   // Arc
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
    ]

    func readFrontmostWindowMetadata() -> WindowMetadata {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return .empty
        }

        let appName = frontApp.localizedName ?? "Unknown"
        let bundleID = frontApp.bundleIdentifier ?? ""

        // Get window title from CGWindowList (does not require Accessibility permission)
        let windowTitle = readWindowTitle(pid: frontApp.processIdentifier) ?? ""

        // Attempt browser URL extraction via Accessibility API (best-effort)
        let browserURL: String?
        if Self.browserBundleIDs.contains(bundleID) {
            browserURL = readBrowserURL(app: frontApp)
        } else {
            browserURL = nil
        }

        return WindowMetadata(
            appName: appName,
            bundleIdentifier: bundleID,
            windowTitle: windowTitle,
            browserURL: browserURL
        )
    }

    // MARK: - Window Title (via CGWindowList — no Accessibility needed)

    private func readWindowTitle(pid: pid_t) -> String? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Find the topmost normal-layer window for this PID
        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { continue }

            return info[kCGWindowName as String] as? String
        }

        return nil
    }

    // MARK: - Browser URL (via Accessibility — best-effort)

    private func readBrowserURL(app: NSRunningApplication) -> String? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Get the focused window
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success else {
            return nil
        }
        let windowElement = windowValue as! AXUIElement

        // Try to find the URL/address bar. Strategy:
        // 1. Look for AXTextField with description containing "address", "url", or "location"
        // 2. Read its AXValue
        return findAddressBarValue(in: windowElement, depth: 0, maxDepth: 6)
    }

    /// Recursively search the accessibility tree for an address-bar-like text field.
    /// Limited depth to avoid performance issues.
    private func findAddressBarValue(in element: AXUIElement, depth: Int, maxDepth: Int) -> String? {
        guard depth < maxDepth else { return nil }

        // Check role
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String

        // If this is a text field, check if it looks like an address bar
        if role == kAXTextFieldRole || role == kAXComboBoxRole {
            var descValue: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descValue)
            let desc = (descValue as? String ?? "").lowercased()

            // Also check role description
            var roleDescValue: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescValue)
            let roleDesc = (roleDescValue as? String ?? "").lowercased()

            let combined = desc + " " + roleDesc

            let addressKeywords = ["address", "url", "location", "search or enter", "search or type"]
            let looksLikeAddressBar = addressKeywords.contains { combined.contains($0) }

            if looksLikeAddressBar {
                var valueRef: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
                if let urlString = valueRef as? String, !urlString.isEmpty {
                    return urlString
                }
            }
        }

        // Recurse into children
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement]
        else { return nil }

        for child in children {
            if let url = findAddressBarValue(in: child, depth: depth + 1, maxDepth: maxDepth) {
                return url
            }
        }

        return nil
    }
}
