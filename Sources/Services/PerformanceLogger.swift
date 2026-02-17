import Foundation

// MARK: - Performance Logger

/// Lightweight performance profiling service for Eval.
///
/// Provides timing utilities for the capture pipeline, database queries, OCR processing,
/// and summarization. Also tracks memory usage over long capture sessions.
///
/// All measurements are stored in-memory with a configurable buffer size and optionally
/// logged to the system console. No data leaves the device.
///
/// Usage:
/// ```
/// let duration = PerformanceLogger.shared.measure(.capturePipeline) {
///     performCapture()
/// }
///
/// // Or manual start/stop:
/// let token = PerformanceLogger.shared.startMeasurement(.dbQuery)
/// // ... do work ...
/// PerformanceLogger.shared.endMeasurement(token)
/// ```
final class PerformanceLogger {

    // MARK: - Singleton

    static let shared = PerformanceLogger()

    // MARK: - Types

    /// Categories of operations that can be profiled.
    enum OperationCategory: String, CaseIterable {
        case capturePipeline = "capture_pipeline"
        case screenshot = "screenshot"
        case metadata = "metadata"
        case ocr = "ocr"
        case dbRead = "db_read"
        case dbWrite = "db_write"
        case dbSearch = "db_search"
        case summarization = "summarization"
        case uiRender = "ui_render"
        case retention = "retention"
        case export = "export"
    }

    /// A single timing measurement.
    struct Measurement: Identifiable {
        let id: UUID
        let category: OperationCategory
        let label: String
        let duration: TimeInterval   // seconds
        let timestamp: Date
        let memoryBytes: UInt64?     // resident memory at time of measurement

        init(
            id: UUID = UUID(),
            category: OperationCategory,
            label: String,
            duration: TimeInterval,
            timestamp: Date = Date(),
            memoryBytes: UInt64? = nil
        ) {
            self.id = id
            self.category = category
            self.label = label
            self.duration = duration
            self.timestamp = timestamp
            self.memoryBytes = memoryBytes
        }
    }

    /// Token returned by `startMeasurement` for manual start/stop timing.
    struct MeasurementToken {
        let id: UUID
        let category: OperationCategory
        let label: String
        let startTime: UInt64     // mach_absolute_time for precision
        let startMemory: UInt64?
    }

    /// Aggregated statistics for an operation category.
    struct CategoryStats {
        let category: OperationCategory
        let count: Int
        let totalDuration: TimeInterval
        let averageDuration: TimeInterval
        let minDuration: TimeInterval
        let maxDuration: TimeInterval
        let p95Duration: TimeInterval   // 95th percentile
    }

    /// Snapshot of current memory usage.
    struct MemorySnapshot {
        let residentBytes: UInt64     // Physical memory in use
        let virtualBytes: UInt64      // Virtual memory size
        let timestamp: Date

        var residentMB: Double { Double(residentBytes) / (1024.0 * 1024.0) }
        var virtualMB: Double { Double(virtualBytes) / (1024.0 * 1024.0) }
    }

    // MARK: - Configuration

    /// Maximum number of measurements to keep in the buffer. Oldest are evicted first.
    var maxBufferSize: Int = 1000

    /// Whether to log measurements to the console via print.
    var consoleLoggingEnabled: Bool = false

    /// Duration threshold (seconds) above which a warning is logged regardless of `consoleLoggingEnabled`.
    var slowOperationThreshold: TimeInterval = 2.0

    /// Whether to track memory alongside timing measurements.
    var trackMemory: Bool = true

    // MARK: - State

    private var measurements: [Measurement] = []
    private var memorySnapshots: [MemorySnapshot] = []
    private let lock = NSLock()

    // MARK: - Mach Timebase

    private let machTimebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    // MARK: - Init

    init() {}

    // MARK: - Synchronous Measurement

    /// Measure the duration of a synchronous closure.
    ///
    /// - Parameters:
    ///   - category: The operation category for grouping.
    ///   - label: A human-readable label for this specific operation.
    ///   - operation: The closure to measure.
    /// - Returns: The result of the closure.
    @discardableResult
    func measure<T>(_ category: OperationCategory, label: String = "", operation: () throws -> T) rethrows -> T {
        let startTime = mach_absolute_time()
        let startMemory = trackMemory ? currentResidentMemory() : nil

        let result = try operation()

        let endTime = mach_absolute_time()
        let duration = machTimeToDuration(start: startTime, end: endTime)
        let endMemory = trackMemory ? currentResidentMemory() : nil

        let effectiveLabel = label.isEmpty ? category.rawValue : label
        let measurement = Measurement(
            category: category,
            label: effectiveLabel,
            duration: duration,
            memoryBytes: endMemory
        )

        record(measurement)
        logIfNeeded(measurement, startMemory: startMemory, endMemory: endMemory)

        return result
    }

    /// Measure the duration of a synchronous throwing closure, returning the duration alongside the result.
    func measureWithDuration<T>(_ category: OperationCategory, label: String = "", operation: () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
        let startTime = mach_absolute_time()
        let startMemory = trackMemory ? currentResidentMemory() : nil

        let result = try operation()

        let endTime = mach_absolute_time()
        let duration = machTimeToDuration(start: startTime, end: endTime)
        let endMemory = trackMemory ? currentResidentMemory() : nil

        let effectiveLabel = label.isEmpty ? category.rawValue : label
        let measurement = Measurement(
            category: category,
            label: effectiveLabel,
            duration: duration,
            memoryBytes: endMemory
        )

        record(measurement)
        logIfNeeded(measurement, startMemory: startMemory, endMemory: endMemory)

        return (result, duration)
    }

    // MARK: - Manual Start/Stop

    /// Begin a manual timing measurement. Call `endMeasurement(_:)` with the returned token to record.
    func startMeasurement(_ category: OperationCategory, label: String = "") -> MeasurementToken {
        MeasurementToken(
            id: UUID(),
            category: category,
            label: label.isEmpty ? category.rawValue : label,
            startTime: mach_absolute_time(),
            startMemory: trackMemory ? currentResidentMemory() : nil
        )
    }

    /// End a manual timing measurement and record the result.
    /// - Returns: The measured duration in seconds.
    @discardableResult
    func endMeasurement(_ token: MeasurementToken) -> TimeInterval {
        let endTime = mach_absolute_time()
        let duration = machTimeToDuration(start: token.startTime, end: endTime)
        let endMemory = trackMemory ? currentResidentMemory() : nil

        let measurement = Measurement(
            id: token.id,
            category: token.category,
            label: token.label,
            duration: duration,
            memoryBytes: endMemory
        )

        record(measurement)
        logIfNeeded(measurement, startMemory: token.startMemory, endMemory: endMemory)

        return duration
    }

    // MARK: - Memory Monitoring

    /// Take a snapshot of current memory usage.
    @discardableResult
    func takeMemorySnapshot() -> MemorySnapshot {
        let snapshot = MemorySnapshot(
            residentBytes: currentResidentMemory() ?? 0,
            virtualBytes: currentVirtualMemory() ?? 0,
            timestamp: Date()
        )

        lock.lock()
        memorySnapshots.append(snapshot)
        // Keep last 100 snapshots
        if memorySnapshots.count > 100 {
            memorySnapshots.removeFirst(memorySnapshots.count - 100)
        }
        lock.unlock()

        if consoleLoggingEnabled {
            print("[Eval:Perf] Memory: \(String(format: "%.1f", snapshot.residentMB)) MB resident, \(String(format: "%.1f", snapshot.virtualMB)) MB virtual")
        }

        return snapshot
    }

    /// Current resident memory in bytes (physical memory in use by this process).
    func currentResidentMemory() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : nil
    }

    /// Current virtual memory size in bytes.
    func currentVirtualMemory() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.virtual_size : nil
    }

    // MARK: - Statistics

    /// Get aggregated statistics for a specific operation category.
    func stats(for category: OperationCategory) -> CategoryStats? {
        lock.lock()
        let matching = measurements.filter { $0.category == category }
        lock.unlock()

        guard !matching.isEmpty else { return nil }

        let durations = matching.map(\.duration).sorted()
        let count = durations.count
        let total = durations.reduce(0, +)
        let avg = total / Double(count)
        let min = durations.first ?? 0
        let max = durations.last ?? 0

        // 95th percentile
        let p95Index = Int(Double(count) * 0.95)
        let p95 = durations[Swift.min(p95Index, count - 1)]

        return CategoryStats(
            category: category,
            count: count,
            totalDuration: total,
            averageDuration: avg,
            minDuration: min,
            maxDuration: max,
            p95Duration: p95
        )
    }

    /// Get stats for all categories that have measurements.
    func allStats() -> [CategoryStats] {
        OperationCategory.allCases.compactMap { stats(for: $0) }
    }

    /// Get all recorded measurements (thread-safe copy).
    func allMeasurements() -> [Measurement] {
        lock.lock()
        defer { lock.unlock() }
        return measurements
    }

    /// Get all recorded memory snapshots (thread-safe copy).
    func allMemorySnapshots() -> [MemorySnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return memorySnapshots
    }

    /// Get measurements for a specific category.
    func measurements(for category: OperationCategory) -> [Measurement] {
        lock.lock()
        defer { lock.unlock() }
        return measurements.filter { $0.category == category }
    }

    /// Get the most recent measurement for a category.
    func lastMeasurement(for category: OperationCategory) -> Measurement? {
        lock.lock()
        defer { lock.unlock() }
        return measurements.last { $0.category == category }
    }

    // MARK: - Report

    /// Generate a human-readable performance report.
    func generateReport() -> String {
        var lines: [String] = []
        lines.append("=== Eval Performance Report ===")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")

        // Memory
        if let snapshot = allMemorySnapshots().last {
            lines.append("-- Memory --")
            lines.append("  Resident: \(String(format: "%.1f", snapshot.residentMB)) MB")
            lines.append("  Virtual:  \(String(format: "%.1f", snapshot.virtualMB)) MB")
            lines.append("")
        }

        // Per-category stats
        let stats = allStats()
        if !stats.isEmpty {
            lines.append("-- Timing (by category) --")
            for stat in stats.sorted(by: { $0.totalDuration > $1.totalDuration }) {
                lines.append("  \(stat.category.rawValue):")
                lines.append("    Count: \(stat.count)")
                lines.append("    Avg:   \(String(format: "%.3f", stat.averageDuration))s")
                lines.append("    Min:   \(String(format: "%.3f", stat.minDuration))s")
                lines.append("    Max:   \(String(format: "%.3f", stat.maxDuration))s")
                lines.append("    P95:   \(String(format: "%.3f", stat.p95Duration))s")
                lines.append("    Total: \(String(format: "%.3f", stat.totalDuration))s")
            }
            lines.append("")
        }

        // Slow operations
        lock.lock()
        let slowOps = measurements.filter { $0.duration >= slowOperationThreshold }
        lock.unlock()

        if !slowOps.isEmpty {
            lines.append("-- Slow Operations (>= \(String(format: "%.1f", slowOperationThreshold))s) --")
            for op in slowOps.suffix(20) {
                let dateStr = ISO8601DateFormatter().string(from: op.timestamp)
                lines.append("  [\(dateStr)] \(op.category.rawValue)/\(op.label): \(String(format: "%.3f", op.duration))s")
            }
        }

        lines.append("=== End Report ===")
        return lines.joined(separator: "\n")
    }

    // MARK: - Reset

    /// Clear all recorded measurements and memory snapshots.
    func reset() {
        lock.lock()
        measurements.removeAll()
        memorySnapshots.removeAll()
        lock.unlock()
    }

    // MARK: - Private

    private func record(_ measurement: Measurement) {
        lock.lock()
        measurements.append(measurement)
        if measurements.count > maxBufferSize {
            measurements.removeFirst(measurements.count - maxBufferSize)
        }
        lock.unlock()
    }

    private func machTimeToDuration(start: UInt64, end: UInt64) -> TimeInterval {
        let elapsed = end - start
        let nanos = elapsed * UInt64(machTimebaseInfo.numer) / UInt64(machTimebaseInfo.denom)
        return TimeInterval(nanos) / 1_000_000_000
    }

    private func logIfNeeded(_ measurement: Measurement, startMemory: UInt64?, endMemory: UInt64?) {
        let isSlow = measurement.duration >= slowOperationThreshold

        if consoleLoggingEnabled || isSlow {
            var msg = "[Eval:Perf] \(measurement.category.rawValue)"
            if measurement.label != measurement.category.rawValue {
                msg += "/\(measurement.label)"
            }
            msg += ": \(String(format: "%.3f", measurement.duration))s"

            if let start = startMemory, let end = endMemory {
                let deltaBytes = Int64(end) - Int64(start)
                let deltaMB = Double(deltaBytes) / (1024.0 * 1024.0)
                if abs(deltaMB) > 0.1 {
                    msg += " (mem delta: \(String(format: "%+.1f", deltaMB)) MB)"
                }
            }

            if isSlow {
                msg += " [SLOW]"
            }

            print(msg)
        }
    }
}
