import Foundation
import AppKit

// MARK: - Capture Result

/// A single capture: screenshot image data + window metadata, produced by one tick of the capture pipeline.
struct CaptureResult: Identifiable {
    let id: UUID
    let timestamp: Date
    let imageData: Data?          // PNG screenshot of active window
    let metadata: WindowMetadata
    var ocrResult: OCRResult?     // Populated after OCR processing (nil if OCR disabled or not yet run)

    init(id: UUID = UUID(), timestamp: Date = Date(), imageData: Data?, metadata: WindowMetadata, ocrResult: OCRResult? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.imageData = imageData
        self.metadata = metadata
        self.ocrResult = ocrResult
    }
}

/// Metadata extracted from the frontmost window at capture time.
struct WindowMetadata: Codable {
    let appName: String
    let bundleIdentifier: String
    let windowTitle: String
    let browserURL: String?       // non-nil only for Safari/Chrome/Firefox/Arc

    static let empty = WindowMetadata(appName: "Unknown", bundleIdentifier: "", windowTitle: "", browserURL: nil)
}

// MARK: - Capture Status

enum CaptureStatus: Equatable {
    case idle                     // Never started
    case capturing                // Running normally
    case paused                   // User paused
    case permissionDenied         // Screen Recording permission not granted
    case error(String)            // Something went wrong

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .capturing: return "Capturing"
        case .paused: return "Paused"
        case .permissionDenied: return "No Permission"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var isActive: Bool {
        self == .capturing
    }
}
