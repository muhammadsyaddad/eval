import XCTest
@testable import MacPulse

// MARK: - Window Metadata Tests

final class WindowMetadataTests: XCTestCase {

    func testMetadataCreation() {
        let metadata = WindowMetadata(
            appName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: "MacPulse — Package.swift",
            browserURL: nil
        )

        XCTAssertEqual(metadata.appName, "Xcode")
        XCTAssertEqual(metadata.bundleIdentifier, "com.apple.dt.Xcode")
        XCTAssertEqual(metadata.windowTitle, "MacPulse — Package.swift")
        XCTAssertNil(metadata.browserURL)
    }

    func testMetadataWithBrowserURL() {
        let metadata = WindowMetadata(
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            windowTitle: "Apple",
            browserURL: "https://apple.com"
        )

        XCTAssertEqual(metadata.appName, "Safari")
        XCTAssertNotNil(metadata.browserURL)
        XCTAssertEqual(metadata.browserURL, "https://apple.com")
    }

    func testEmptyMetadata() {
        let metadata = WindowMetadata.empty

        XCTAssertEqual(metadata.appName, "Unknown")
        XCTAssertEqual(metadata.bundleIdentifier, "")
        XCTAssertEqual(metadata.windowTitle, "")
        XCTAssertNil(metadata.browserURL)
    }

    func testMetadataEncodeDecode() throws {
        let original = WindowMetadata(
            appName: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            windowTitle: "GitHub",
            browserURL: "https://github.com"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WindowMetadata.self, from: data)

        XCTAssertEqual(decoded.appName, original.appName)
        XCTAssertEqual(decoded.bundleIdentifier, original.bundleIdentifier)
        XCTAssertEqual(decoded.windowTitle, original.windowTitle)
        XCTAssertEqual(decoded.browserURL, original.browserURL)
    }

    func testMetadataEncodeDecodeNilURL() throws {
        let original = WindowMetadata(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "bash",
            browserURL: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WindowMetadata.self, from: data)

        XCTAssertEqual(decoded.appName, original.appName)
        XCTAssertNil(decoded.browserURL)
    }
}

// MARK: - Capture Result Tests

final class CaptureResultTests: XCTestCase {

    func testCaptureResultCreationDefaults() {
        let metadata = WindowMetadata(
            appName: "Finder",
            bundleIdentifier: "com.apple.finder",
            windowTitle: "Documents",
            browserURL: nil
        )
        let result = CaptureResult(imageData: Data([0x01, 0x02]), metadata: metadata)

        XCTAssertNotNil(result.id)
        XCTAssertNotNil(result.timestamp)
        XCTAssertEqual(result.imageData, Data([0x01, 0x02]))
        XCTAssertEqual(result.metadata.appName, "Finder")
    }

    func testCaptureResultWithNilImageData() {
        let metadata = WindowMetadata.empty
        let result = CaptureResult(imageData: nil, metadata: metadata)

        XCTAssertNil(result.imageData)
        XCTAssertEqual(result.metadata.appName, "Unknown")
    }

    func testCaptureResultWithCustomIDAndTimestamp() {
        let customID = UUID()
        let customDate = Date(timeIntervalSince1970: 1000000)
        let metadata = WindowMetadata.empty

        let result = CaptureResult(
            id: customID,
            timestamp: customDate,
            imageData: nil,
            metadata: metadata
        )

        XCTAssertEqual(result.id, customID)
        XCTAssertEqual(result.timestamp, customDate)
    }
}
