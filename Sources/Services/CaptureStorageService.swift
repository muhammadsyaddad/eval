import Foundation

// MARK: - Capture Storage Service Protocol

protocol CaptureStorageServiceProtocol {
    /// Save a capture result to disk. Returns the file path of the saved screenshot.
    func save(_ capture: CaptureResult) throws -> URL

    /// List all captures for a given date range.
    func listCaptures(from: Date, to: Date) -> [StoredCapture]

    /// Delete captures older than the given date.
    func deleteCaptures(olderThan date: Date) throws

    /// Delete ALL capture files from disk. Returns the number of bytes freed.
    func deleteAllCaptures() throws -> UInt64

    /// Total storage used by captures in bytes.
    func totalStorageBytes() -> UInt64

    /// Delete a single screenshot by relative path.
    func deleteImage(at relativePath: String) throws
}

/// Represents a capture persisted to disk.
struct StoredCapture: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let metadata: WindowMetadata
    let imagePath: String           // Relative path to screenshot file
    let ocrText: String?            // Extracted text from OCR (nil if OCR was disabled)
    let ocrConfidence: Float?       // Average OCR confidence (nil if no OCR)

    var imageURL: URL? {
        let base = CaptureStorageService.capturesDirectory
        return base?.appendingPathComponent(imagePath)
    }
}

// MARK: - Capture Storage Service

final class CaptureStorageService: CaptureStorageServiceProtocol {

    /// Base directory for all captures: ~/Library/Application Support/Eval/Captures/
    static var capturesDirectory: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("Eval", isDirectory: true)
            .appendingPathComponent("Captures", isDirectory: true)
    }

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        ensureDirectoryExists()
    }

    // MARK: - Save

    func save(_ capture: CaptureResult) throws -> URL {
        guard let baseDir = Self.capturesDirectory else {
            throw StorageError.directoryNotAvailable
        }

        // Organize by date: Captures/2026-02-08/
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateDir = baseDir.appendingPathComponent(dateFormatter.string(from: capture.timestamp), isDirectory: true)

        try fileManager.createDirectory(at: dateDir, withIntermediateDirectories: true)

        // Filename: <uuid>.png + <uuid>.json for metadata
        let baseName = capture.id.uuidString

        // Save screenshot
        let imagePath = dateDir.appendingPathComponent("\(baseName).png")
        if let imageData = capture.imageData {
            try imageData.write(to: imagePath, options: .atomic)
        }

        // Save metadata
        let stored = StoredCapture(
            id: capture.id,
            timestamp: capture.timestamp,
            metadata: capture.metadata,
            imagePath: "\(dateFormatter.string(from: capture.timestamp))/\(baseName).png",
            ocrText: capture.ocrResult?.fullText,
            ocrConfidence: capture.ocrResult?.averageConfidence
        )
        let metadataPath = dateDir.appendingPathComponent("\(baseName).json")
        let metadataData = try encoder.encode(stored)
        try metadataData.write(to: metadataPath, options: .atomic)

        return imagePath
    }

    // MARK: - List

    func listCaptures(from startDate: Date, to endDate: Date) -> [StoredCapture] {
        guard let baseDir = Self.capturesDirectory else { return [] }

        var captures: [StoredCapture] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Iterate over date directories
        let calendar = Calendar.current
        var current = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        while current <= end {
            let dateDirName = dateFormatter.string(from: current)
            let dateDir = baseDir.appendingPathComponent(dateDirName, isDirectory: true)

            if fileManager.fileExists(atPath: dateDir.path) {
                do {
                    let files = try fileManager.contentsOfDirectory(at: dateDir, includingPropertiesForKeys: nil)
                    let jsonFiles = files.filter { $0.pathExtension == "json" }

                    for jsonFile in jsonFiles {
                        if let data = try? Data(contentsOf: jsonFile),
                           let stored = try? decoder.decode(StoredCapture.self, from: data) {
                            captures.append(stored)
                        }
                    }
                } catch {
                    // Skip directories we can't read
                }
            }

            current = calendar.date(byAdding: .day, value: 1, to: current) ?? end.addingTimeInterval(1)
        }

        return captures.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Delete

    func deleteCaptures(olderThan date: Date) throws {
        guard let baseDir = Self.capturesDirectory else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let cutoffString = dateFormatter.string(from: date)

        let contents = try fileManager.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil)
        for dir in contents where dir.hasDirectoryPath {
            let dirName = dir.lastPathComponent
            if dirName < cutoffString {
                try fileManager.removeItem(at: dir)
            }
        }
    }

    // MARK: - Delete All

    func deleteAllCaptures() throws -> UInt64 {
        guard let baseDir = Self.capturesDirectory else {
            throw StorageError.directoryNotAvailable
        }

        guard fileManager.fileExists(atPath: baseDir.path) else {
            return 0
        }

        // Calculate size before deletion
        let bytesUsed = directorySize(at: baseDir)

        // Remove the entire directory tree
        try fileManager.removeItem(at: baseDir)

        // Recreate the empty directory for future use
        try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)

        return bytesUsed
    }

    // MARK: - Storage Size

    func totalStorageBytes() -> UInt64 {
        guard let baseDir = Self.capturesDirectory else { return 0 }
        return directorySize(at: baseDir)
    }

    func deleteImage(at relativePath: String) throws {
        guard let baseDir = Self.capturesDirectory else {
            throw StorageError.directoryNotAvailable
        }

        let fileURL = baseDir.appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        guard let dir = Self.capturesDirectory else { return }
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func directorySize(at url: URL) -> UInt64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }
}

// MARK: - Storage Error

enum StorageError: LocalizedError {
    case directoryNotAvailable

    var errorDescription: String? {
        switch self {
        case .directoryNotAvailable: return "Application support directory not available"
        }
    }
}
