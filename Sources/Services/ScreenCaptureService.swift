import Foundation
import AppKit
import CoreGraphics

// MARK: - Screen Capture Service Protocol

protocol ScreenCaptureServiceProtocol {
    /// Capture a screenshot of the currently active window. Returns PNG data or nil on failure.
    func captureActiveWindow() -> Data?
}

// MARK: - Screen Capture Service (CGWindowList)

final class ScreenCaptureService: ScreenCaptureServiceProtocol {

    /// Captures the frontmost window as PNG image data.
    ///
    /// Uses CGWindowListCreateImage to capture only the active window, not the entire screen.
    /// Falls back to full-screen capture if the active window cannot be identified.
    func captureActiveWindow() -> Data? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return captureFullScreen()
        }

        // Find windows belonging to the frontmost app
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        let appPID = frontApp.processIdentifier

        // Find the topmost on-screen window for this app
        let appWindow = windowList.first { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0 // normal window layer
            else { return false }
            return pid == appPID
        }

        if let windowID = appWindow?[kCGWindowNumber as String] as? CGWindowID {
            // Capture just this window
            if let cgImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.boundsIgnoreFraming, .nominalResolution]
            ) {
                return pngData(from: cgImage)
            }
        }

        // Fallback: capture the full screen
        return captureFullScreen()
    }

    // MARK: - Private

    private func captureFullScreen() -> Data? {
        guard let cgImage = CGWindowListCreateImage(
            CGRect.infinite,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.nominalResolution]
        ) else { return nil }

        return pngData(from: cgImage)
    }

    private func pngData(from cgImage: CGImage) -> Data? {
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }
}
