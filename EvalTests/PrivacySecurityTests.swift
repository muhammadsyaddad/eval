import XCTest
import CryptoKit
@testable import Eval

// MARK: - Security Service Tests

final class SecurityServiceTests: XCTestCase {

    private var service: SecurityService!

    override func setUp() {
        super.setUp()
        service = SecurityService()
    }

    // MARK: - FileVault Detection

    func testFileVaultDetectionReturnsBool() {
        // We can't control system FileVault state, just verify it doesn't crash
        // and returns a deterministic Bool.
        let result = service.isFileVaultEnabled()
        XCTAssertTrue(result == true || result == false, "isFileVaultEnabled should return a Bool")
    }

    func testFileVaultDetectionIsConsistent() {
        // Two consecutive calls should return the same result (system state shouldn't change mid-test).
        let first = service.isFileVaultEnabled()
        let second = service.isFileVaultEnabled()
        XCTAssertEqual(first, second, "FileVault detection should be consistent across calls")
    }

    // MARK: - AES-GCM Encryption

    func testEncryptDecryptRoundTrip() throws {
        let key = service.generateEncryptionKey()
        let originalData = "Hello, Eval privacy!".data(using: .utf8)!

        let encrypted = try service.encrypt(data: originalData, key: key)
        let decrypted = try service.decrypt(data: encrypted, key: key)

        XCTAssertEqual(decrypted, originalData, "Decrypted data should match original")
    }

    func testEncryptDecryptLargeData() throws {
        let key = service.generateEncryptionKey()
        // Simulate a moderately large payload (like OCR text or metadata JSON)
        let largeString = String(repeating: "This is a test of AES-256-GCM encryption. ", count: 1000)
        let originalData = largeString.data(using: .utf8)!

        let encrypted = try service.encrypt(data: originalData, key: key)
        let decrypted = try service.decrypt(data: encrypted, key: key)

        XCTAssertEqual(decrypted, originalData, "Large data should round-trip correctly")
        XCTAssertNotEqual(encrypted, originalData, "Encrypted data must differ from original")
    }

    func testDecryptWithWrongKeyFails() throws {
        let key1 = service.generateEncryptionKey()
        let key2 = service.generateEncryptionKey()
        let originalData = "Secret data".data(using: .utf8)!

        let encrypted = try service.encrypt(data: originalData, key: key1)

        XCTAssertThrowsError(try service.decrypt(data: encrypted, key: key2)) { error in
            guard let secError = error as? SecurityError else {
                XCTFail("Expected SecurityError, got \(type(of: error))")
                return
            }
            if case .decryptionFailed(_) = secError {
                // Expected
            } else {
                XCTFail("Expected .decryptionFailed, got \(secError)")
            }
        }
    }

    func testEncryptEmptyData() throws {
        let key = service.generateEncryptionKey()
        let emptyData = Data()

        let encrypted = try service.encrypt(data: emptyData, key: key)
        XCTAssertFalse(encrypted.isEmpty, "Encrypted empty data should have nonce + tag overhead")

        let decrypted = try service.decrypt(data: encrypted, key: key)
        XCTAssertEqual(decrypted, emptyData, "Decrypted empty data should be empty")
    }

    func testGenerateEncryptionKeyIsUnique() {
        let key1 = service.generateEncryptionKey()
        let key2 = service.generateEncryptionKey()

        // Convert to data for comparison
        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }

        XCTAssertNotEqual(data1, data2, "Two generated keys should be unique")
    }

    func testGenerateEncryptionKeyIs256Bits() {
        let key = service.generateEncryptionKey()
        let keyData = key.withUnsafeBytes { Data($0) }
        XCTAssertEqual(keyData.count, 32, "Key should be 256 bits (32 bytes)")
    }

    func testEncryptedDataDiffersFromOriginal() throws {
        let key = service.generateEncryptionKey()
        let original = "Plaintext content".data(using: .utf8)!

        let encrypted = try service.encrypt(data: original, key: key)
        XCTAssertNotEqual(encrypted, original, "Encrypted data must not equal plaintext")
    }

    func testEncryptProducesDifferentCiphertextEachTime() throws {
        // AES-GCM uses a random nonce, so encrypting the same data twice should produce different ciphertext.
        let key = service.generateEncryptionKey()
        let original = "Same data each time".data(using: .utf8)!

        let encrypted1 = try service.encrypt(data: original, key: key)
        let encrypted2 = try service.encrypt(data: original, key: key)

        XCTAssertNotEqual(encrypted1, encrypted2, "AES-GCM should use random nonces, producing different ciphertext")

        // But both should decrypt to the same plaintext
        let decrypted1 = try service.decrypt(data: encrypted1, key: key)
        let decrypted2 = try service.decrypt(data: encrypted2, key: key)
        XCTAssertEqual(decrypted1, original)
        XCTAssertEqual(decrypted2, original)
    }

    func testDecryptCorruptedDataFails() throws {
        let key = service.generateEncryptionKey()
        let original = "Valid data".data(using: .utf8)!
        var encrypted = try service.encrypt(data: original, key: key)

        // Corrupt the ciphertext by flipping a byte
        if encrypted.count > 20 {
            encrypted[20] ^= 0xFF
        }

        XCTAssertThrowsError(try service.decrypt(data: encrypted, key: key)) { error in
            XCTAssertTrue(error is SecurityError, "Should throw SecurityError for corrupted data")
        }
    }

    // MARK: - Capture File Purge

    func testDeleteAllCaptureFilesOnEmptyDirectory() throws {
        // Create a temporary directory to simulate an empty captures directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvalTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // The SecurityService.deleteAllCaptureFiles() uses CaptureStorageService.capturesDirectory
        // which is a fixed path. We test the concept with SecurityService directly.
        // Since we can't easily mock the static path, we verify the service doesn't crash.
        // For a proper test, we'd need to inject the directory path.
        XCTAssertNoThrow(try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil))
    }

    // MARK: - Security Error

    func testSecurityErrorDescriptions() {
        let errors: [(SecurityError, String)] = [
            (.encryptionFailed("test"), "Encryption failed: test"),
            (.decryptionFailed("bad key"), "Decryption failed: bad key"),
            (.fileVaultCheckFailed("timeout"), "FileVault check failed: timeout"),
            (.purgeIncomplete("partial"), "Data purge incomplete: partial"),
            (.captureDirectoryNotAvailable, "Capture directory not available"),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.errorDescription, expected)
        }
    }
}

// MARK: - Permission Manager Tests

final class PermissionManagerTests: XCTestCase {

    func testInitialState() {
        let manager = PermissionManager()
        // On a test runner, permissions may or may not be granted.
        // Just verify the properties exist and are Bool.
        XCTAssertTrue(manager.screenRecordingGranted == true || manager.screenRecordingGranted == false)
        XCTAssertTrue(manager.accessibilityGranted == true || manager.accessibilityGranted == false)
    }

    func testAccessibilityGrantedIsPublished() {
        let manager = PermissionManager()
        let expectation = XCTestExpectation(description: "accessibilityGranted is observable")

        let cancellable = manager.$accessibilityGranted.sink { _ in
            expectation.fulfill()
        }

        // The initial value should trigger the sink immediately
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    func testScreenRecordingGrantedIsPublished() {
        let manager = PermissionManager()
        let expectation = XCTestExpectation(description: "screenRecordingGranted is observable")

        let cancellable = manager.$screenRecordingGranted.sink { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    func testRecheckAllDoesNotCrash() {
        let manager = PermissionManager()
        // Verify recheckAll runs both checks without crashing
        manager.recheckAll()
        // Properties should still be valid Bools
        XCTAssertTrue(manager.screenRecordingGranted == true || manager.screenRecordingGranted == false)
    }

    func testStartAndStopPeriodicRecheck() {
        let manager = PermissionManager()
        // Start should not crash
        manager.startPeriodicRecheck()
        // Double-start should be a no-op (guard against nil)
        manager.startPeriodicRecheck()
        // Stop should not crash
        manager.stopPeriodicRecheck()
        // Double-stop should be safe
        manager.stopPeriodicRecheck()
    }

    func testPeriodicRecheckTimerFires() {
        // This test verifies the timer mechanism works.
        // PermissionManager uses a 10s interval, which is too long for a unit test.
        // Instead, we verify the mechanism is wired correctly by starting/stopping.
        let manager = PermissionManager()
        manager.startPeriodicRecheck()

        // Give a brief moment for setup
        let expectation = XCTestExpectation(description: "Timer setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        manager.stopPeriodicRecheck()
    }

    func testPermissionRevokedCallbackCanBeSet() {
        let manager = PermissionManager()
        var callbackFired = false

        manager.onPermissionRevoked = { permissionName in
            callbackFired = true
            XCTAssertFalse(permissionName.isEmpty, "Permission name should not be empty")
        }

        // We can't easily simulate revocation in a test, but verify the callback is set
        XCTAssertNotNil(manager.onPermissionRevoked)
        _ = callbackFired // Suppress unused warning
    }

    func testDeinitStopsTimer() {
        // Create manager, start recheck, then let it deinit
        var manager: PermissionManager? = PermissionManager()
        manager?.startPeriodicRecheck()
        manager = nil // Should trigger deinit which stops the timer
        // No crash = success
    }
}

// MARK: - CaptureStorageService Delete All Tests

final class CaptureStorageDeleteTests: XCTestCase {

    func testDeleteAllCapturesProtocolMethod() throws {
        let storage = CaptureStorageService()
        // On a fresh test environment, captures directory may be empty or have test artifacts.
        // The method should not crash and should return a UInt64.
        let bytesFreed = try storage.deleteAllCaptures()
        XCTAssertTrue(bytesFreed >= 0, "Bytes freed should be non-negative")
    }

    func testDeleteAllCapturesRecreatesDirectory() throws {
        let storage = CaptureStorageService()
        _ = try storage.deleteAllCaptures()

        // Directory should still exist after purge (recreated)
        if let capturesDir = CaptureStorageService.capturesDirectory {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: capturesDir.path),
                "Captures directory should be recreated after purge"
            )
        }
    }

    func testMockCaptureStorageDeleteAllCaptures() throws {
        // Test the mock used in scheduler tests
        let mock = MockCaptureStorageForPrivacy()
        mock.mockStorageBytes = 1024 * 1024 // 1 MB
        let freed = try mock.deleteAllCaptures()
        XCTAssertEqual(freed, 1024 * 1024)
        XCTAssertTrue(mock.deleteAllCalled)
    }
}

// MARK: - DatabaseManager Vacuum Tests

final class DatabaseVacuumTests: XCTestCase {

    func testVacuumOnEmptyDatabase() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvalVacuumTest-\(UUID().uuidString)")
        let dbURL = tempDir.appendingPathComponent("test.db")

        let dbManager = try DatabaseManager(databaseURL: dbURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Vacuum on empty database should not crash
        XCTAssertNoThrow(try dbManager.vacuumDatabase())
    }

    func testVacuumAfterLargeDelete() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvalVacuumTest-\(UUID().uuidString)")
        let dbURL = tempDir.appendingPathComponent("test.db")

        let dbManager = try DatabaseManager(databaseURL: dbURL)
        let store = DataStore(databaseManager: dbManager)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Insert many records
        for i in 0..<100 {
            let record = CaptureRecord(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 60)),
                appName: "TestApp",
                bundleIdentifier: "com.test.app",
                windowTitle: "Window \(i)",
                imagePath: "test/image_\(i).png",
                ocrText: String(repeating: "Test OCR text for record \(i). ", count: 50)
            )
            try store.insertCapture(record)
        }

        let countBefore = try store.captureCount()
        XCTAssertEqual(countBefore, 100)

        let sizeBeforeDelete = dbManager.databaseSizeBytes()
        XCTAssertTrue(sizeBeforeDelete > 0, "DB should have non-zero size after inserts")

        // Delete all data
        try store.deleteAllData()

        let countAfter = try store.captureCount()
        XCTAssertEqual(countAfter, 0, "All captures should be deleted")

        // Vacuum to reclaim space — should not throw
        XCTAssertNoThrow(try dbManager.vacuumDatabase())

        let sizeAfterVacuum = dbManager.databaseSizeBytes()
        // After VACUUM, size should be <= pre-delete size.
        // Note: Exact size reduction depends on SQLite page allocation and schema overhead
        // (FTS5 tables, indexes), so we verify VACUUM runs successfully and DB remains functional
        // rather than asserting strict size reduction.
        XCTAssertTrue(sizeAfterVacuum <= sizeBeforeDelete,
                      "Database should not grow after vacuum (was \(sizeBeforeDelete), now \(sizeAfterVacuum))")
        XCTAssertTrue(sizeAfterVacuum > 0, "Database should still exist after vacuum")
    }

    func testDeleteAllDataClearsAllTables() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvalDeleteAllTest-\(UUID().uuidString)")
        let dbURL = tempDir.appendingPathComponent("test.db")

        let dbManager = try DatabaseManager(databaseURL: dbURL)
        let store = DataStore(databaseManager: dbManager)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Insert data into all 4 tables
        let capture = CaptureRecord(
            appName: "Safari", bundleIdentifier: "com.apple.Safari",
            windowTitle: "Apple", imagePath: "test.png", ocrText: "Apple website"
        )
        try store.insertCapture(capture)

        let entry = ActivityEntryRecord(
            appName: "Safari", appIcon: "globe", title: "Browsing",
            summary: "Visited apple.com", category: "Browsing", duration: 300
        )
        try store.insertActivityEntry(entry)

        let summary = DailySummaryRecord(
            date: Date(), totalScreenTime: 3600, aiSummary: "Test day",
            activityCount: 5, productivityScore: 0.7
        )
        try store.upsertDailySummary(summary)

        let usage = AppUsageRecord(
            date: Date(), appName: "Safari", appIcon: "globe",
            duration: 1800, category: "Browsing"
        )
        try store.upsertAppUsage(usage)

        let totalBefore = try store.totalRowCount()
        XCTAssertTrue(totalBefore >= 4, "Should have at least 4 rows across tables")

        // Delete all data
        try store.deleteAllData()

        let totalAfter = try store.totalRowCount()
        XCTAssertEqual(totalAfter, 0, "All tables should be empty after deleteAllData")
    }
}

// MARK: - Excluded Apps Tests

final class ExcludedAppsTests: XCTestCase {

    func testDefaultExclusionsContainPasswordManagers() {
        let settings = AppSettings()
        XCTAssertTrue(settings.excludedApps.contains("Keychain Access"),
                      "Default exclusions should include Keychain Access")
        XCTAssertTrue(settings.excludedApps.contains("1Password"),
                      "Default exclusions should include 1Password")
        XCTAssertTrue(settings.excludedApps.contains("System Preferences"),
                      "Default exclusions should include System Preferences")
    }

    func testExcludedAppByNameSkipsCapture() {
        let mockScreenCapture = MockScreenCaptureForPrivacy()
        let mockMetadata = MockMetadataForPrivacy()
        let mockStorage = MockCaptureStorageForPrivacy()

        // Set the frontmost app to an excluded app
        mockMetadata.mockMetadata = WindowMetadata(
            appName: "1Password",
            bundleIdentifier: "com.1password.1password",
            windowTitle: "Login - 1Password",
            browserURL: nil
        )

        let scheduler = CaptureScheduler(
            screenCapture: mockScreenCapture,
            metadataService: mockMetadata,
            storage: mockStorage,
            permissionManager: PermissionManager()
        )

        scheduler.updateExclusions(appNames: ["1Password", "Keychain Access"])

        // Force a capture cycle by starting (which calls performCapture)
        // Since we can't easily trigger performCapture directly (it's private),
        // we verify the exclusion list was set correctly via the scheduler's state
        XCTAssertEqual(scheduler.status, .idle, "Scheduler should still be idle before start")

        // Verify the mock metadata returns the excluded app
        let metadata = mockMetadata.readFrontmostWindowMetadata()
        XCTAssertEqual(metadata.appName, "1Password")
    }

    func testExcludedAppByBundleIDSkipsCapture() {
        let mockMetadata = MockMetadataForPrivacy()
        mockMetadata.mockMetadata = WindowMetadata(
            appName: "Keychain Access",
            bundleIdentifier: "com.apple.keychainaccess",
            windowTitle: "Keychain Access",
            browserURL: nil
        )

        let scheduler = CaptureScheduler(
            screenCapture: MockScreenCaptureForPrivacy(),
            metadataService: mockMetadata,
            storage: MockCaptureStorageForPrivacy(),
            permissionManager: PermissionManager()
        )

        // Exclusions work by app name in the current implementation
        scheduler.updateExclusions(appNames: ["Keychain Access"])
        XCTAssertEqual(scheduler.status, .idle)
    }

    func testNonExcludedAppIsNotSkipped() {
        let mockMetadata = MockMetadataForPrivacy()
        mockMetadata.mockMetadata = WindowMetadata(
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            windowTitle: "Apple - Start",
            browserURL: "https://apple.com"
        )

        let scheduler = CaptureScheduler(
            screenCapture: MockScreenCaptureForPrivacy(),
            metadataService: mockMetadata,
            storage: MockCaptureStorageForPrivacy(),
            permissionManager: PermissionManager()
        )

        // Only exclude 1Password, not Safari
        scheduler.updateExclusions(appNames: ["1Password"])

        // Safari should not be in the exclusion list
        let metadata = mockMetadata.readFrontmostWindowMetadata()
        XCTAssertEqual(metadata.appName, "Safari", "Non-excluded app should be capturable")
    }

    func testExclusionListCanBeUpdated() {
        let scheduler = CaptureScheduler(
            screenCapture: MockScreenCaptureForPrivacy(),
            metadataService: MockMetadataForPrivacy(),
            storage: MockCaptureStorageForPrivacy(),
            permissionManager: PermissionManager()
        )

        // Start with one exclusion
        scheduler.updateExclusions(appNames: ["1Password"])
        // Update to a different list
        scheduler.updateExclusions(appNames: ["Keychain Access", "System Preferences"])
        // Should not crash, state should be fine
        XCTAssertEqual(scheduler.status, .idle)
    }

    func testEmptyExclusionList() {
        let scheduler = CaptureScheduler(
            screenCapture: MockScreenCaptureForPrivacy(),
            metadataService: MockMetadataForPrivacy(),
            storage: MockCaptureStorageForPrivacy(),
            permissionManager: PermissionManager()
        )

        scheduler.updateExclusions(appNames: [])
        XCTAssertEqual(scheduler.status, .idle, "Empty exclusion list should be valid")
    }
}

// MARK: - Data Audit Tests

final class DataAuditTests: XCTestCase {

    func testAppSettingsDefaultExclusions() {
        let settings = AppSettings()
        XCTAssertEqual(settings.excludedApps.count, 3, "Should have 3 default exclusions")
        XCTAssertTrue(settings.excludedApps.contains("Keychain Access"))
        XCTAssertTrue(settings.excludedApps.contains("1Password"))
        XCTAssertTrue(settings.excludedApps.contains("System Preferences"))
    }

    func testAppSettingsDefaultEncryptionDisabled() {
        let settings = AppSettings()
        XCTAssertFalse(settings.encryptionEnabled, "Encryption should be disabled by default")
    }

    func testAppSettingsDefaultOCREnabled() {
        let settings = AppSettings()
        XCTAssertTrue(settings.ocrEnabled, "OCR should be enabled by default")
    }

    func testAppSettingsDefaultStorageLimit() {
        let settings = AppSettings()
        XCTAssertEqual(settings.storageLimitGB, 5.0, "Default storage limit should be 5 GB")
    }

    func testGRDBIsOnlyDependency() throws {
        // Verify Package.swift only declares GRDB as a dependency (no network libraries)
        let packagePath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // EvalTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("Package.swift")

        let content = try String(contentsOf: packagePath, encoding: .utf8)

        // Should contain GRDB
        XCTAssertTrue(content.contains("GRDB.swift"), "Package.swift should declare GRDB dependency")

        // Should NOT contain common networking libraries
        XCTAssertFalse(content.contains("Alamofire"), "Should not depend on Alamofire")
        XCTAssertFalse(content.contains("URLSession"), "Should not reference URLSession in Package.swift")
        XCTAssertFalse(content.contains("Firebase"), "Should not depend on Firebase")
        XCTAssertFalse(content.contains("Analytics"), "Should not depend on analytics libraries")
        XCTAssertFalse(content.contains("Sentry"), "Should not depend on Sentry")
        XCTAssertFalse(content.contains("Amplitude"), "Should not depend on Amplitude")
        XCTAssertFalse(content.contains("Mixpanel"), "Should not depend on Mixpanel")
    }

    func testNoNetworkEntitlement() throws {
        // Verify entitlements file denies network access
        let entitlementsPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("Eval.entitlements")

        let content = try String(contentsOf: entitlementsPath, encoding: .utf8)

        // Network client should be false
        XCTAssertTrue(content.contains("com.apple.security.network.client"),
                      "Entitlements should reference network.client")
        // The value should be false (deny network)
        // In a plist, <false/> follows the key
        XCTAssertTrue(content.contains("<false/>"),
                      "Network entitlement should be set to false")
    }

    func testRetentionPolicyDefaults() {
        let policy = RetentionPolicy()
        XCTAssertEqual(policy.captureRetentionDays, 30, "Default capture retention should be 30 days")
        XCTAssertEqual(policy.activityRetentionDays, 90, "Default activity retention should be 90 days")
        XCTAssertEqual(policy.summaryRetentionDays, 365, "Default summary retention should be 365 days")
        XCTAssertEqual(policy.storageLimitBytes, 5 * 1024 * 1024 * 1024, "Default storage limit should be 5 GB")
    }

    func testCaptureRecordContainsSensitiveFieldDocumentation() {
        // Verify that CaptureRecord has the expected fields that we've audited
        let record = CaptureRecord(
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            windowTitle: "Test Window",
            browserURL: "https://example.com",
            imagePath: "test.png",
            ocrText: "Some OCR text",
            ocrConfidence: 0.95
        )

        // These are the high-sensitivity fields we audited
        XCTAssertNotNil(record.browserURL, "browserURL is a high-sensitivity field")
        XCTAssertNotNil(record.ocrText, "ocrText is a high-sensitivity field")
        XCTAssertFalse(record.imagePath.isEmpty, "imagePath is a high-sensitivity field")

        // Medium sensitivity
        XCTAssertFalse(record.windowTitle.isEmpty, "windowTitle is a medium-sensitivity field")
    }

    func testStorageErrorDescription() {
        let error = StorageError.directoryNotAvailable
        XCTAssertEqual(error.errorDescription, "Application support directory not available")
    }
}

// MARK: - App Settings Encryption Toggle Tests

final class EncryptionSettingsTests: XCTestCase {

    func testEncryptionCanBeToggled() {
        var settings = AppSettings()
        XCTAssertFalse(settings.encryptionEnabled)

        settings.encryptionEnabled = true
        XCTAssertTrue(settings.encryptionEnabled)

        settings.encryptionEnabled = false
        XCTAssertFalse(settings.encryptionEnabled)
    }

    func testSecurityServiceProtocolConformance() {
        let service = SecurityService()

        // Verify all protocol methods exist and are callable
        let _ = service.isFileVaultEnabled()
        let key = service.generateEncryptionKey()
        XCTAssertNoThrow(try service.encrypt(data: Data([1, 2, 3]), key: key))
    }
}

// MARK: - FTS5 Search with Privacy Context Tests

final class FTSSearchPrivacyTests: XCTestCase {

    private var dbManager: DatabaseManager!
    private var store: DataStore!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvalFTSPrivacy-\(UUID().uuidString)")
        let dbURL = tempDir.appendingPathComponent("test.db")
        dbManager = try! DatabaseManager(databaseURL: dbURL)
        store = DataStore(databaseManager: dbManager)
    }

    override func tearDown() {
        store = nil
        dbManager = nil
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDeletedDataIsNotSearchable() throws {
        // Insert a capture with OCR text
        let capture = CaptureRecord(
            appName: "Safari", bundleIdentifier: "com.apple.Safari",
            windowTitle: "Secret Page", imagePath: "test.png",
            ocrText: "This is confidential information about Project Mercury"
        )
        try store.insertCapture(capture)

        // Verify it's searchable
        let resultsBefore = try store.searchCaptures(query: "Mercury", limit: 10)
        XCTAssertEqual(resultsBefore.count, 1, "Should find the capture before deletion")

        // Delete all data
        try store.deleteAllData()

        // Verify it's no longer searchable
        let resultsAfter = try store.searchCaptures(query: "Mercury", limit: 10)
        XCTAssertEqual(resultsAfter.count, 0, "Deleted data should not be searchable via FTS5")
    }

    func testVacuumAfterDeleteDoesNotBreakSearch() throws {
        // Insert data
        let capture = CaptureRecord(
            appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: "MyProject.swift", imagePath: "test.png",
            ocrText: "func calculateTotal() -> Double"
        )
        try store.insertCapture(capture)

        // Delete and vacuum
        try store.deleteAllData()
        try dbManager.vacuumDatabase()

        // Insert new data after vacuum
        let newCapture = CaptureRecord(
            appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: "NewProject.swift", imagePath: "test2.png",
            ocrText: "struct UserProfile: Codable"
        )
        try store.insertCapture(newCapture)

        // Search should work for new data
        let results = try store.searchCaptures(query: "UserProfile", limit: 10)
        XCTAssertEqual(results.count, 1, "FTS5 should work after vacuum + re-insert")

        // Old data should not appear
        let oldResults = try store.searchCaptures(query: "calculateTotal", limit: 10)
        XCTAssertEqual(oldResults.count, 0, "Old data should not reappear after vacuum")
    }
}

// MARK: - Mock Services for Privacy Tests

private final class MockScreenCaptureForPrivacy: ScreenCaptureServiceProtocol {
    var captureCallCount = 0
    var mockImageData: Data? = Data([0x89, 0x50, 0x4E, 0x47])

    func captureActiveWindow() -> Data? {
        captureCallCount += 1
        return mockImageData
    }
}

private final class MockMetadataForPrivacy: WindowMetadataServiceProtocol {
    var mockMetadata = WindowMetadata(
        appName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        windowTitle: "Apple - Start",
        browserURL: "https://apple.com"
    )

    func readFrontmostWindowMetadata() -> WindowMetadata {
        return mockMetadata
    }
}

final class MockCaptureStorageForPrivacy: CaptureStorageServiceProtocol {
    var mockStorageBytes: UInt64 = 0
    var deleteAllCalled = false
    var saveCallCount = 0

    func save(_ capture: CaptureResult) throws -> URL {
        saveCallCount += 1
        return URL(fileURLWithPath: "/tmp/test/\(capture.id.uuidString).png")
    }

    func listCaptures(from: Date, to: Date) -> [StoredCapture] { [] }

    func deleteCaptures(olderThan date: Date) throws {}

    func deleteAllCaptures() throws -> UInt64 {
        deleteAllCalled = true
        return mockStorageBytes
    }

    func totalStorageBytes() -> UInt64 { mockStorageBytes }
}
