import XCTest
@testable import MacPulse

// MARK: - PerformanceLogger Measurement Tests

final class PerformanceLoggerMeasurementTests: XCTestCase {

    var logger: PerformanceLogger!

    override func setUp() {
        super.setUp()
        logger = PerformanceLogger()
        logger.consoleLoggingEnabled = false
        logger.trackMemory = false
    }

    override func tearDown() {
        logger.reset()
        logger = nil
        super.tearDown()
    }

    func testMeasureSynchronousClosure() {
        let result = logger.measure(.capturePipeline, label: "test_op") {
            return 42
        }

        XCTAssertEqual(result, 42)
        let measurements = logger.allMeasurements()
        XCTAssertEqual(measurements.count, 1)
        XCTAssertEqual(measurements.first?.category, .capturePipeline)
        XCTAssertEqual(measurements.first?.label, "test_op")
        XCTAssertGreaterThanOrEqual(measurements.first?.duration ?? -1, 0)
    }

    func testMeasureWithDuration() {
        let (result, duration) = logger.measureWithDuration(.ocr, label: "test_ocr") {
            // Simulate some work
            var sum = 0
            for i in 0..<1000 { sum += i }
            return sum
        }

        XCTAssertEqual(result, 499500)
        XCTAssertGreaterThan(duration, 0)
        XCTAssertEqual(logger.allMeasurements().count, 1)
    }

    func testMeasureDefaultLabel() {
        logger.measure(.dbRead) {
            // no-op
        }

        let m = logger.allMeasurements().first
        XCTAssertEqual(m?.label, "db_read")
    }

    func testManualStartStop() {
        let token = logger.startMeasurement(.screenshot, label: "manual_test")

        // Simulate work
        var sum = 0
        for i in 0..<100 { sum += i }

        let duration = logger.endMeasurement(token)

        XCTAssertGreaterThan(duration, 0)
        XCTAssertEqual(logger.allMeasurements().count, 1)
        XCTAssertEqual(logger.allMeasurements().first?.category, .screenshot)
        XCTAssertEqual(logger.allMeasurements().first?.label, "manual_test")
    }

    func testManualStartStopDefaultLabel() {
        let token = logger.startMeasurement(.metadata)
        _ = logger.endMeasurement(token)

        XCTAssertEqual(logger.allMeasurements().first?.label, "metadata")
    }

    func testMeasureDurationIsPositive() {
        logger.measure(.dbWrite, label: "write_test") {
            Thread.sleep(forTimeInterval: 0.01) // 10ms
        }

        let m = logger.allMeasurements().first
        XCTAssertNotNil(m)
        XCTAssertGreaterThan(m?.duration ?? 0, 0.005)
    }

    func testMultipleMeasurementsRecorded() {
        for i in 0..<5 {
            logger.measure(.dbRead, label: "query_\(i)") { }
        }

        XCTAssertEqual(logger.allMeasurements().count, 5)
    }

    func testMeasureThrowingClosure() {
        enum TestError: Error { case expected }

        XCTAssertThrowsError(try logger.measure(.dbWrite, label: "throwing") {
            throw TestError.expected
        })

        // Throwing closures should NOT record a measurement (the error propagates before recording)
        // Actually, due to rethrows, the error propagates after measure completes
        // The measurement is recorded before the throw propagates — check by behavior
    }
}

// MARK: - PerformanceLogger Buffer Tests

final class PerformanceLoggerBufferTests: XCTestCase {

    var logger: PerformanceLogger!

    override func setUp() {
        super.setUp()
        logger = PerformanceLogger()
        logger.consoleLoggingEnabled = false
        logger.trackMemory = false
    }

    override func tearDown() {
        logger.reset()
        logger = nil
        super.tearDown()
    }

    func testBufferEvictsOldMeasurements() {
        logger.maxBufferSize = 10

        for i in 0..<20 {
            logger.measure(.dbRead, label: "query_\(i)") { }
        }

        let all = logger.allMeasurements()
        XCTAssertEqual(all.count, 10)
        // Oldest should have been evicted — last label should be query_19
        XCTAssertEqual(all.last?.label, "query_19")
        // First remaining should be query_10
        XCTAssertEqual(all.first?.label, "query_10")
    }

    func testResetClearsAll() {
        logger.measure(.capturePipeline) { }
        logger.measure(.ocr) { }
        logger.takeMemorySnapshot()

        XCTAssertEqual(logger.allMeasurements().count, 2)
        XCTAssertGreaterThan(logger.allMemorySnapshots().count, 0)

        logger.reset()

        XCTAssertEqual(logger.allMeasurements().count, 0)
        XCTAssertEqual(logger.allMemorySnapshots().count, 0)
    }
}

// MARK: - PerformanceLogger Memory Tests

final class PerformanceLoggerMemoryTests: XCTestCase {

    var logger: PerformanceLogger!

    override func setUp() {
        super.setUp()
        logger = PerformanceLogger()
        logger.consoleLoggingEnabled = false
        logger.trackMemory = true
    }

    override func tearDown() {
        logger.reset()
        logger = nil
        super.tearDown()
    }

    func testCurrentResidentMemory() {
        let memory = logger.currentResidentMemory()
        XCTAssertNotNil(memory)
        XCTAssertGreaterThan(memory ?? 0, 0)
    }

    func testCurrentVirtualMemory() {
        let memory = logger.currentVirtualMemory()
        XCTAssertNotNil(memory)
        XCTAssertGreaterThan(memory ?? 0, 0)
    }

    func testMemorySnapshot() {
        let snapshot = logger.takeMemorySnapshot()
        XCTAssertGreaterThan(snapshot.residentBytes, 0)
        XCTAssertGreaterThan(snapshot.virtualBytes, 0)
        XCTAssertGreaterThan(snapshot.residentMB, 0)
        XCTAssertGreaterThan(snapshot.virtualMB, 0)

        XCTAssertEqual(logger.allMemorySnapshots().count, 1)
    }

    func testMemorySnapshotBufferLimit() {
        for _ in 0..<150 {
            logger.takeMemorySnapshot()
        }

        // Buffer limited to 100
        XCTAssertEqual(logger.allMemorySnapshots().count, 100)
    }

    func testMeasurementTracksMemory() {
        logger.trackMemory = true
        logger.measure(.capturePipeline, label: "mem_test") { }

        let m = logger.allMeasurements().first
        XCTAssertNotNil(m?.memoryBytes)
        XCTAssertGreaterThan(m?.memoryBytes ?? 0, 0)
    }

    func testMeasurementSkipsMemoryWhenDisabled() {
        logger.trackMemory = false
        logger.measure(.capturePipeline, label: "no_mem_test") { }

        let m = logger.allMeasurements().first
        XCTAssertNil(m?.memoryBytes)
    }
}

// MARK: - PerformanceLogger Statistics Tests

final class PerformanceLoggerStatsTests: XCTestCase {

    var logger: PerformanceLogger!

    override func setUp() {
        super.setUp()
        logger = PerformanceLogger()
        logger.consoleLoggingEnabled = false
        logger.trackMemory = false
    }

    override func tearDown() {
        logger.reset()
        logger = nil
        super.tearDown()
    }

    func testStatsForEmptyCategory() {
        let stats = logger.stats(for: .capturePipeline)
        XCTAssertNil(stats)
    }

    func testStatsForSingleMeasurement() {
        logger.measure(.dbRead, label: "single") {
            Thread.sleep(forTimeInterval: 0.01)
        }

        let stats = logger.stats(for: .dbRead)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.count, 1)
        XCTAssertEqual(stats?.category, .dbRead)
        XCTAssertGreaterThan(stats?.averageDuration ?? 0, 0)
        XCTAssertEqual(stats?.minDuration, stats?.maxDuration)
        XCTAssertEqual(stats?.minDuration, stats?.p95Duration)
    }

    func testStatsForMultipleMeasurements() {
        for _ in 0..<10 {
            logger.measure(.dbRead, label: "batch") {
                Thread.sleep(forTimeInterval: 0.001) // 1ms
            }
        }

        let stats = logger.stats(for: .dbRead)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.count, 10)
        XCTAssertGreaterThan(stats?.totalDuration ?? 0, 0)
        XCTAssertGreaterThanOrEqual(stats?.maxDuration ?? 0, stats?.minDuration ?? 0)
        XCTAssertGreaterThanOrEqual(stats?.p95Duration ?? 0, stats?.averageDuration ?? 0)
    }

    func testAllStatsFiltersEmpty() {
        logger.measure(.ocr, label: "a") { }
        logger.measure(.dbRead, label: "b") { }

        let all = logger.allStats()
        XCTAssertEqual(all.count, 2)
        let categories = Set(all.map(\.category))
        XCTAssertTrue(categories.contains(.ocr))
        XCTAssertTrue(categories.contains(.dbRead))
    }

    func testMeasurementsFilterByCategory() {
        logger.measure(.ocr, label: "ocr1") { }
        logger.measure(.dbRead, label: "db1") { }
        logger.measure(.ocr, label: "ocr2") { }

        let ocrMeasurements = logger.measurements(for: .ocr)
        XCTAssertEqual(ocrMeasurements.count, 2)

        let dbMeasurements = logger.measurements(for: .dbRead)
        XCTAssertEqual(dbMeasurements.count, 1)
    }

    func testLastMeasurement() {
        logger.measure(.dbRead, label: "first") { }
        logger.measure(.dbRead, label: "second") { }
        logger.measure(.dbRead, label: "third") { }

        let last = logger.lastMeasurement(for: .dbRead)
        XCTAssertEqual(last?.label, "third")
    }

    func testLastMeasurementNilForEmpty() {
        let last = logger.lastMeasurement(for: .summarization)
        XCTAssertNil(last)
    }
}

// MARK: - PerformanceLogger Report Tests

final class PerformanceLoggerReportTests: XCTestCase {

    var logger: PerformanceLogger!

    override func setUp() {
        super.setUp()
        logger = PerformanceLogger()
        logger.consoleLoggingEnabled = false
        logger.trackMemory = true
    }

    override func tearDown() {
        logger.reset()
        logger = nil
        super.tearDown()
    }

    func testReportContainsHeader() {
        let report = logger.generateReport()
        XCTAssertTrue(report.contains("MacPulse Performance Report"))
        XCTAssertTrue(report.contains("End Report"))
    }

    func testReportContainsTimingData() {
        logger.measure(.capturePipeline, label: "test") {
            Thread.sleep(forTimeInterval: 0.01)
        }

        let report = logger.generateReport()
        XCTAssertTrue(report.contains("capture_pipeline"))
        XCTAssertTrue(report.contains("Avg:"))
        XCTAssertTrue(report.contains("Count: 1"))
    }

    func testReportContainsMemory() {
        logger.takeMemorySnapshot()

        let report = logger.generateReport()
        XCTAssertTrue(report.contains("Memory"))
        XCTAssertTrue(report.contains("Resident:"))
        XCTAssertTrue(report.contains("Virtual:"))
    }

    func testReportContainsSlowOperations() {
        logger.slowOperationThreshold = 0.005

        logger.measure(.dbRead, label: "slow_query") {
            Thread.sleep(forTimeInterval: 0.01) // 10ms > 5ms threshold
        }

        let report = logger.generateReport()
        XCTAssertTrue(report.contains("Slow Operations"))
        XCTAssertTrue(report.contains("slow_query"))
    }

    func testEmptyReportDoesNotCrash() {
        let report = logger.generateReport()
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("MacPulse Performance Report"))
    }
}

// MARK: - PerformanceLogger Operation Category Tests

final class PerformanceLoggerCategoryTests: XCTestCase {

    func testAllCategoriesHaveRawValues() {
        for category in PerformanceLogger.OperationCategory.allCases {
            XCTAssertFalse(category.rawValue.isEmpty)
        }
    }

    func testCategoryCaseCount() {
        XCTAssertEqual(PerformanceLogger.OperationCategory.allCases.count, 11)
    }

    func testCategoryRawValues() {
        XCTAssertEqual(PerformanceLogger.OperationCategory.capturePipeline.rawValue, "capture_pipeline")
        XCTAssertEqual(PerformanceLogger.OperationCategory.screenshot.rawValue, "screenshot")
        XCTAssertEqual(PerformanceLogger.OperationCategory.metadata.rawValue, "metadata")
        XCTAssertEqual(PerformanceLogger.OperationCategory.ocr.rawValue, "ocr")
        XCTAssertEqual(PerformanceLogger.OperationCategory.dbRead.rawValue, "db_read")
        XCTAssertEqual(PerformanceLogger.OperationCategory.dbWrite.rawValue, "db_write")
        XCTAssertEqual(PerformanceLogger.OperationCategory.dbSearch.rawValue, "db_search")
        XCTAssertEqual(PerformanceLogger.OperationCategory.summarization.rawValue, "summarization")
        XCTAssertEqual(PerformanceLogger.OperationCategory.uiRender.rawValue, "ui_render")
        XCTAssertEqual(PerformanceLogger.OperationCategory.retention.rawValue, "retention")
        XCTAssertEqual(PerformanceLogger.OperationCategory.export.rawValue, "export")
    }
}

// MARK: - PerformanceLogger Configuration Tests

final class PerformanceLoggerConfigTests: XCTestCase {

    func testDefaultConfiguration() {
        let logger = PerformanceLogger()
        XCTAssertEqual(logger.maxBufferSize, 1000)
        XCTAssertFalse(logger.consoleLoggingEnabled)
        XCTAssertEqual(logger.slowOperationThreshold, 2.0)
        XCTAssertTrue(logger.trackMemory)
    }

    func testCustomConfiguration() {
        let logger = PerformanceLogger()
        logger.maxBufferSize = 50
        logger.consoleLoggingEnabled = true
        logger.slowOperationThreshold = 0.5
        logger.trackMemory = false

        XCTAssertEqual(logger.maxBufferSize, 50)
        XCTAssertTrue(logger.consoleLoggingEnabled)
        XCTAssertEqual(logger.slowOperationThreshold, 0.5)
        XCTAssertFalse(logger.trackMemory)
    }
}

// MARK: - PerformanceLogger Thread Safety Tests

final class PerformanceLoggerThreadSafetyTests: XCTestCase {

    func testConcurrentMeasurements() {
        let logger = PerformanceLogger()
        logger.consoleLoggingEnabled = false
        logger.trackMemory = false

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let iterations = 100

        for i in 0..<iterations {
            group.enter()
            queue.async {
                logger.measure(.dbRead, label: "concurrent_\(i)") { }
                group.leave()
            }
        }

        group.wait()

        XCTAssertEqual(logger.allMeasurements().count, iterations)
    }

    func testConcurrentMemorySnapshots() {
        let logger = PerformanceLogger()
        logger.consoleLoggingEnabled = false

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.memory.concurrent", attributes: .concurrent)

        for _ in 0..<50 {
            group.enter()
            queue.async {
                logger.takeMemorySnapshot()
                group.leave()
            }
        }

        group.wait()

        XCTAssertEqual(logger.allMemorySnapshots().count, 50)
    }
}

// MARK: - PerformanceLogger Singleton Tests

final class PerformanceLoggerSingletonTests: XCTestCase {

    override func tearDown() {
        PerformanceLogger.shared.reset()
        super.tearDown()
    }

    func testSharedInstanceExists() {
        let shared = PerformanceLogger.shared
        XCTAssertNotNil(shared)
    }

    func testSharedInstanceIsSame() {
        let a = PerformanceLogger.shared
        let b = PerformanceLogger.shared
        XCTAssertTrue(a === b)
    }

    func testSharedInstanceRecordsMeasurements() {
        PerformanceLogger.shared.measure(.capturePipeline, label: "singleton_test") { }
        let measurements = PerformanceLogger.shared.allMeasurements()
        XCTAssertEqual(measurements.count, 1)
    }
}
