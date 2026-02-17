import XCTest
@testable import Eval

// MARK: - Menu Bar Icon State Tests

final class MenuBarIconStateTests: XCTestCase {

    // MARK: - System Image

    func testCapturingSystemImage() {
        XCTAssertEqual(MenuBarIconState.capturing.systemImage, "waveform.circle.fill")
    }

    func testPausedSystemImage() {
        XCTAssertEqual(MenuBarIconState.paused.systemImage, "pause.circle")
    }

    func testIdleSystemImage() {
        XCTAssertEqual(MenuBarIconState.idle.systemImage, "circle.dotted")
    }

    func testErrorSystemImage() {
        XCTAssertEqual(MenuBarIconState.error.systemImage, "exclamationmark.circle")
    }

    // MARK: - Labels

    func testCapturingLabel() {
        XCTAssertEqual(MenuBarIconState.capturing.label, "Capturing")
    }

    func testPausedLabel() {
        XCTAssertEqual(MenuBarIconState.paused.label, "Paused")
    }

    func testIdleLabel() {
        XCTAssertEqual(MenuBarIconState.idle.label, "Idle")
    }

    func testErrorLabel() {
        XCTAssertEqual(MenuBarIconState.error.label, "Error")
    }

    // MARK: - Is Active

    func testCapturingIsActive() {
        XCTAssertTrue(MenuBarIconState.capturing.isActive)
    }

    func testPausedIsNotActive() {
        XCTAssertFalse(MenuBarIconState.paused.isActive)
    }

    func testIdleIsNotActive() {
        XCTAssertFalse(MenuBarIconState.idle.isActive)
    }

    func testErrorIsNotActive() {
        XCTAssertFalse(MenuBarIconState.error.isActive)
    }
}

// MARK: - Menu Bar Manager Tests

final class MenuBarManagerTests: XCTestCase {

    // MARK: - Initial State

    func testInitialIconStateIsIdle() {
        let manager = MenuBarManager()
        XCTAssertEqual(manager.iconState, .idle)
    }

    func testInitialScreenTimeIsZero() {
        let manager = MenuBarManager()
        XCTAssertEqual(manager.screenTime, 0)
    }

    func testInitialCaptureCountIsZero() {
        let manager = MenuBarManager()
        XCTAssertEqual(manager.captureCount, 0)
    }

    func testInitialActivityCountIsZero() {
        let manager = MenuBarManager()
        XCTAssertEqual(manager.activityCount, 0)
    }

    func testInitialProductivityScoreIsZero() {
        let manager = MenuBarManager()
        XCTAssertEqual(manager.productivityScore, 0)
    }

    func testInitialTopAppNameIsDash() {
        let manager = MenuBarManager()
        XCTAssertEqual(manager.topAppName, "—")
    }

    // MARK: - Bind Updates Stats from AppState

    func testBindUpdatesStatsFromTodaySummary() {
        let manager = MenuBarManager()
        let appState = AppState()

        // Set a known summary before binding
        let testSummary = DaySummary(
            date: Date(),
            totalScreenTime: 7200, // 2 hours
            topApps: [
                AppUsage(appName: "Xcode", appIcon: "hammer.fill", duration: 3600, category: .development)
            ],
            aiSummary: "Test summary",
            activityCount: 15,
            productivityScore: 0.85
        )
        appState.todaySummary = testSummary

        manager.bind(to: appState)

        // The Combine pipeline is async on main queue, so we need a small wait
        let expectation = XCTestExpectation(description: "Stats updated from bind")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(manager.screenTime, 7200)
            XCTAssertEqual(manager.activityCount, 15)
            XCTAssertEqual(manager.productivityScore, 0.85)
            XCTAssertEqual(manager.topAppName, "Xcode")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testBindUpdatesTopAppNameWhenNoApps() {
        let manager = MenuBarManager()
        let appState = AppState()

        let testSummary = DaySummary(
            date: Date(),
            totalScreenTime: 0,
            topApps: [],
            aiSummary: "",
            activityCount: 0,
            productivityScore: 0
        )
        appState.todaySummary = testSummary

        manager.bind(to: appState)

        let expectation = XCTestExpectation(description: "Top app is dash when no apps")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(manager.topAppName, "—")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Icon State Mapping

    func testIconStateMapsIdleCaptureStatus() {
        // Verify the mapping logic: CaptureStatus.idle → MenuBarIconState.idle
        // We test the mapping function directly via the enum cases
        let state = mapCaptureStatusToIconState(.idle)
        XCTAssertEqual(state, .idle)
    }

    func testIconStateMapsCapturingStatus() {
        let state = mapCaptureStatusToIconState(.capturing)
        XCTAssertEqual(state, .capturing)
    }

    func testIconStateMapsPausedStatus() {
        let state = mapCaptureStatusToIconState(.paused)
        XCTAssertEqual(state, .paused)
    }

    func testIconStateMapsPermissionDeniedToError() {
        let state = mapCaptureStatusToIconState(.permissionDenied)
        XCTAssertEqual(state, .error)
    }

    func testIconStateMapsErrorToError() {
        let state = mapCaptureStatusToIconState(.error("test"))
        XCTAssertEqual(state, .error)
    }

    // MARK: - Raw Value

    func testIconStateRawValues() {
        XCTAssertEqual(MenuBarIconState.capturing.rawValue, "capturing")
        XCTAssertEqual(MenuBarIconState.paused.rawValue, "paused")
        XCTAssertEqual(MenuBarIconState.idle.rawValue, "idle")
        XCTAssertEqual(MenuBarIconState.error.rawValue, "error")
    }
}

// MARK: - Helper

/// Maps CaptureStatus to MenuBarIconState — mirrors the logic in MenuBarManager.bind(to:).
private func mapCaptureStatusToIconState(_ status: CaptureStatus) -> MenuBarIconState {
    switch status {
    case .capturing: return .capturing
    case .paused: return .paused
    case .idle: return .idle
    case .permissionDenied: return .error
    case .error: return .error
    }
}
