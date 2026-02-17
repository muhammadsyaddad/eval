import XCTest
@testable import Eval

// MARK: - Mock Services

final class MockScreenCaptureService: ScreenCaptureServiceProtocol {
    var captureCallCount = 0
    var mockImageData: Data? = Data([0x89, 0x50, 0x4E, 0x47]) // Fake PNG header

    func captureActiveWindow() -> Data? {
        captureCallCount += 1
        return mockImageData
    }
}

final class MockWindowMetadataService: WindowMetadataServiceProtocol {
    var mockMetadata = WindowMetadata(
        appName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        windowTitle: "Apple - Start",
        browserURL: "https://apple.com"
    )
    var readCallCount = 0

    func readFrontmostWindowMetadata() -> WindowMetadata {
        readCallCount += 1
        return mockMetadata
    }
}

final class MockCaptureStorageService: CaptureStorageServiceProtocol {
    var savedCaptures: [CaptureResult] = []
    var saveCallCount = 0
    var shouldThrow = false

    func save(_ capture: CaptureResult) throws -> URL {
        if shouldThrow {
            throw StorageError.directoryNotAvailable
        }
        saveCallCount += 1
        savedCaptures.append(capture)
        return URL(fileURLWithPath: "/tmp/test/\(capture.id.uuidString).png")
    }

    func listCaptures(from: Date, to: Date) -> [StoredCapture] {
        return []
    }

    func deleteCaptures(olderThan date: Date) throws {}
    func deleteAllCaptures() throws -> UInt64 { return 0 }
    func totalStorageBytes() -> UInt64 { return 0 }
}

// MARK: - Capture Scheduler Tests

final class CaptureSchedulerTests: XCTestCase {

    // MARK: - Lifecycle Tests

    func testInitialStatusIsIdle() {
        let scheduler = makeMockScheduler()
        XCTAssertEqual(scheduler.status, .idle)
        XCTAssertNil(scheduler.lastCapture)
        XCTAssertEqual(scheduler.captureCount, 0)
    }

    func testPauseFromCapturingChangesStatus() {
        let scheduler = makeMockScheduler()
        // Manually set status to capturing (since start() requires real permissions)
        scheduler.status = .capturing
        scheduler.pause()
        XCTAssertEqual(scheduler.status, .paused)
    }

    func testPauseFromIdleDoesNothing() {
        let scheduler = makeMockScheduler()
        scheduler.pause()
        XCTAssertEqual(scheduler.status, .idle)
    }

    func testResumeFromPausedChangesStatus() {
        let scheduler = makeMockScheduler()
        scheduler.status = .paused
        scheduler.resume()
        XCTAssertEqual(scheduler.status, .capturing)
    }

    func testResumeFromIdleDoesNothing() {
        let scheduler = makeMockScheduler()
        scheduler.resume()
        XCTAssertEqual(scheduler.status, .idle)
    }

    func testStopResetsToIdle() {
        let scheduler = makeMockScheduler()
        scheduler.status = .capturing
        scheduler.stop()
        XCTAssertEqual(scheduler.status, .idle)
    }

    func testStopFromPausedResetsToIdle() {
        let scheduler = makeMockScheduler()
        scheduler.status = .paused
        scheduler.stop()
        XCTAssertEqual(scheduler.status, .idle)
    }

    func testToggleFromCapturingPauses() {
        let scheduler = makeMockScheduler()
        scheduler.status = .capturing
        scheduler.toggle()
        XCTAssertEqual(scheduler.status, .paused)
    }

    func testToggleFromPausedResumes() {
        let scheduler = makeMockScheduler()
        scheduler.status = .paused
        scheduler.toggle()
        XCTAssertEqual(scheduler.status, .capturing)
    }

    // MARK: - Interval Tests

    func testDefaultIntervalIs30Seconds() {
        let scheduler = makeMockScheduler()
        XCTAssertEqual(scheduler.intervalSeconds, 30)
    }

    func testUpdateIntervalChangesValue() {
        let scheduler = makeMockScheduler()
        scheduler.updateInterval(10)
        XCTAssertEqual(scheduler.intervalSeconds, 10)
    }

    func testUpdateIntervalWhileIdle() {
        let scheduler = makeMockScheduler()
        scheduler.updateInterval(60)
        XCTAssertEqual(scheduler.intervalSeconds, 60)
        XCTAssertEqual(scheduler.status, .idle)
    }

    // MARK: - Exclusion Tests

    func testUpdateExclusions() {
        let scheduler = makeMockScheduler()
        scheduler.updateExclusions(appNames: ["Safari", "Slack"])
        // Exclusions are internal, so we verify behavior indirectly
        // (the scheduler should skip captures for excluded apps)
        XCTAssertEqual(scheduler.status, .idle) // No crash, state unchanged
    }

    // MARK: - CaptureStatus Tests

    func testCaptureStatusLabels() {
        XCTAssertEqual(CaptureStatus.idle.label, "Idle")
        XCTAssertEqual(CaptureStatus.capturing.label, "Capturing")
        XCTAssertEqual(CaptureStatus.paused.label, "Paused")
        XCTAssertEqual(CaptureStatus.permissionDenied.label, "No Permission")
        XCTAssertEqual(CaptureStatus.error("test").label, "Error: test")
    }

    func testCaptureStatusIsActive() {
        XCTAssertFalse(CaptureStatus.idle.isActive)
        XCTAssertTrue(CaptureStatus.capturing.isActive)
        XCTAssertFalse(CaptureStatus.paused.isActive)
        XCTAssertFalse(CaptureStatus.permissionDenied.isActive)
        XCTAssertFalse(CaptureStatus.error("test").isActive)
    }

    func testCaptureStatusEquality() {
        XCTAssertEqual(CaptureStatus.idle, CaptureStatus.idle)
        XCTAssertEqual(CaptureStatus.capturing, CaptureStatus.capturing)
        XCTAssertNotEqual(CaptureStatus.idle, CaptureStatus.capturing)
        XCTAssertEqual(CaptureStatus.error("a"), CaptureStatus.error("a"))
        XCTAssertNotEqual(CaptureStatus.error("a"), CaptureStatus.error("b"))
    }

    // MARK: - Helpers

    private func makeMockScheduler() -> CaptureScheduler {
        CaptureScheduler(
            screenCapture: MockScreenCaptureService(),
            metadataService: MockWindowMetadataService(),
            storage: MockCaptureStorageService(),
            permissionManager: PermissionManager()
        )
    }
}
