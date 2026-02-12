import XCTest
@testable import MacPulse

// MARK: - Capture Storage Service Tests

final class CaptureStorageServiceTests: XCTestCase {

    private var tempDir: URL!
    private var service: CaptureStorageService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Create a unique temp directory for each test
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacPulseTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = CaptureStorageService()
    }

    override func tearDownWithError() throws {
        // Clean up temp directory
        if let dir = tempDir, FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.removeItem(at: dir)
        }
        try super.tearDownWithError()
    }

    // MARK: - Save Tests

    func testSaveCaptureReturnsPNGPath() throws {
        let metadata = WindowMetadata(
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            windowTitle: "Test Page",
            browserURL: "https://example.com"
        )

        let capture = CaptureResult(
            imageData: Data([0x89, 0x50, 0x4E, 0x47]), // Fake PNG header
            metadata: metadata
        )

        let savedURL = try service.save(capture)
        XCTAssertTrue(savedURL.pathExtension == "png")
        XCTAssertTrue(savedURL.lastPathComponent.contains(capture.id.uuidString))
    }

    func testSaveCaptureWritesImageFile() throws {
        let imageData = Data(repeating: 0xAA, count: 100)
        let metadata = WindowMetadata.empty
        let capture = CaptureResult(imageData: imageData, metadata: metadata)

        let savedURL = try service.save(capture)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))

        let readBack = try Data(contentsOf: savedURL)
        XCTAssertEqual(readBack, imageData)
    }

    func testSaveCaptureWritesMetadataJSON() throws {
        let metadata = WindowMetadata(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "bash",
            browserURL: nil
        )
        let capture = CaptureResult(imageData: Data([0x01]), metadata: metadata)

        let savedURL = try service.save(capture)

        // The JSON file should be alongside the PNG
        let jsonURL = savedURL.deletingPathExtension().appendingPathExtension("json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path))

        // Verify the JSON can be decoded
        let jsonData = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        let stored = try decoder.decode(StoredCapture.self, from: jsonData)
        XCTAssertEqual(stored.id, capture.id)
        XCTAssertEqual(stored.metadata.appName, "Terminal")
        XCTAssertEqual(stored.metadata.bundleIdentifier, "com.apple.Terminal")
        XCTAssertNil(stored.metadata.browserURL)
    }

    func testSaveCaptureWithNilImageDataCreatesNoImage() throws {
        let metadata = WindowMetadata.empty
        let capture = CaptureResult(imageData: nil, metadata: metadata)

        let savedURL = try service.save(capture)
        // PNG file should not exist when imageData is nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedURL.path))
    }

    func testSaveMultipleCapturesOnSameDay() throws {
        let metadata = WindowMetadata.empty

        let capture1 = CaptureResult(imageData: Data([0x01]), metadata: metadata)
        let capture2 = CaptureResult(imageData: Data([0x02]), metadata: metadata)

        let url1 = try service.save(capture1)
        let url2 = try service.save(capture2)

        XCTAssertNotEqual(url1, url2)
        // Both should be in the same date directory
        XCTAssertEqual(url1.deletingLastPathComponent(), url2.deletingLastPathComponent())
    }

    // MARK: - Total Storage Tests

    func testTotalStorageBytesReturnsNonNegative() {
        let bytes = service.totalStorageBytes()
        // Should return 0 or more (depends on whether other tests left data)
        XCTAssertTrue(bytes >= 0)
    }

    // MARK: - StoredCapture Tests

    func testStoredCaptureImageURLConstruction() {
        let stored = StoredCapture(
            id: UUID(),
            timestamp: Date(),
            metadata: WindowMetadata.empty,
            imagePath: "2026-02-08/test.png",
            ocrText: nil,
            ocrConfidence: nil
        )

        XCTAssertNotNil(stored.imageURL)
        XCTAssertTrue(stored.imageURL?.path.contains("MacPulse/Captures") ?? false)
        XCTAssertTrue(stored.imageURL?.path.contains("2026-02-08/test.png") ?? false)
    }
}

// MARK: - Storage Error Tests

final class StorageErrorTests: XCTestCase {

    func testDirectoryNotAvailableDescription() {
        let error = StorageError.directoryNotAvailable
        XCTAssertEqual(error.errorDescription, "Application support directory not available")
    }
}
