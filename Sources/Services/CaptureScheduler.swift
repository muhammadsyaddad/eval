import Foundation
import Combine

// MARK: - Capture Scheduler

/// Orchestrates the capture pipeline: on each tick, captures a screenshot + metadata,
/// checks exclusions, and stores the result to disk.
///
/// This is the central coordinator for M1. It owns:
/// - A repeating timer at the user-configured interval
/// - References to ScreenCaptureService, WindowMetadataService, CaptureStorageService
/// - Pause/resume/start/stop lifecycle
///
/// Publishes `status`, `lastCapture`, and `captureCount` for the UI to observe.
final class CaptureScheduler: ObservableObject {

    // MARK: - Published State

    @Published var status: CaptureStatus = .idle
    @Published var lastCapture: CaptureResult?
    @Published var captureCount: Int = 0
    @Published var intervalSeconds: Int = 30

    // MARK: - Dependencies

    private let screenCapture: ScreenCaptureServiceProtocol
    private let metadataService: WindowMetadataServiceProtocol
    private let storage: CaptureStorageServiceProtocol
    private let permissionManager: PermissionManager
    private let ocrService: OCRServiceProtocol?

    // MARK: - Callbacks

    /// Called after each successful capture with the result and image file path.
    /// Set this to wire captures into the DataStore.
    var onCapture: ((CaptureResult, String) -> Void)?

    // MARK: - Internal State

    private var timer: Timer?
    private var excludedBundleIDs: Set<String> = []
    private var excludedAppNames: Set<String> = []
    private var ocrEnabled: Bool = true
    private let captureQueue = DispatchQueue(label: "com.macpulse.capture", qos: .utility)

    // MARK: - Init

    init(
        screenCapture: ScreenCaptureServiceProtocol = ScreenCaptureService(),
        metadataService: WindowMetadataServiceProtocol = WindowMetadataService(),
        storage: CaptureStorageServiceProtocol = CaptureStorageService(),
        permissionManager: PermissionManager = PermissionManager(),
        ocrService: OCRServiceProtocol? = OCRService()
    ) {
        self.screenCapture = screenCapture
        self.metadataService = metadataService
        self.storage = storage
        self.permissionManager = permissionManager
        self.ocrService = ocrService
    }

    // MARK: - Lifecycle

    /// Start the capture loop. Checks permissions first.
    func start() {
        // Check screen recording permission
        permissionManager.checkScreenRecordingPermission()
        guard permissionManager.screenRecordingGranted else {
            status = .permissionDenied
            permissionManager.requestScreenRecordingPermission()
            return
        }

        guard status != .capturing else { return }

        status = .capturing
        scheduleTimer()
    }

    /// Pause capturing (keeps state, stops timer).
    func pause() {
        guard status == .capturing else { return }
        timer?.invalidate()
        timer = nil
        status = .paused
    }

    /// Resume from paused state.
    func resume() {
        guard status == .paused else { return }
        status = .capturing
        scheduleTimer()
    }

    /// Toggle between capturing and paused.
    func toggle() {
        switch status {
        case .capturing:
            pause()
        case .paused:
            resume()
        case .idle, .permissionDenied, .error:
            start()
        }
    }

    /// Stop completely and reset.
    func stop() {
        timer?.invalidate()
        timer = nil
        status = .idle
    }

    /// Update the capture interval. Restarts the timer if currently capturing.
    func updateInterval(_ seconds: Int) {
        intervalSeconds = seconds
        if status == .capturing {
            scheduleTimer()
        }
    }

    /// Update the list of excluded apps.
    func updateExclusions(appNames: [String]) {
        excludedAppNames = Set(appNames)
    }

    /// Enable or disable OCR processing on captures.
    func updateOCREnabled(_ enabled: Bool) {
        ocrEnabled = enabled
    }

    // MARK: - Timer

    private func scheduleTimer() {
        timer?.invalidate()

        let interval = TimeInterval(intervalSeconds)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performCapture()
        }

        // Also capture immediately on start
        performCapture()
    }

    // MARK: - Capture Pipeline

    private func performCapture() {
        captureQueue.async { [weak self] in
            guard let self = self else { return }

            let perfLogger = PerformanceLogger.shared
            let pipelineToken = perfLogger.startMeasurement(.capturePipeline, label: "full_cycle")

            // 1. Read metadata first (to check exclusions before capturing)
            let metadata = perfLogger.measure(.metadata, label: "read_frontmost") {
                self.metadataService.readFrontmostWindowMetadata()
            }

            // 2. Check exclusions
            if self.excludedAppNames.contains(metadata.appName) ||
               self.excludedBundleIDs.contains(metadata.bundleIdentifier) {
                _ = perfLogger.endMeasurement(pipelineToken)
                return // Skip this capture
            }

            // 3. Capture screenshot
            let imageData = perfLogger.measure(.screenshot, label: "active_window") {
                self.screenCapture.captureActiveWindow()
            }

            // 4. Run OCR if enabled and we have image data
            var ocrResult: OCRResult?
            if self.ocrEnabled, let data = imageData, let ocrSvc = self.ocrService {
                ocrResult = perfLogger.measure(.ocr, label: "recognize_text") {
                    ocrSvc.recognizeText(from: data)
                }
            }

            // 5. Build capture result
            let result = CaptureResult(
                imageData: imageData,
                metadata: metadata,
                ocrResult: ocrResult
            )

            // 6. Store to disk
            do {
                let fileURL = try perfLogger.measure(.dbWrite, label: "save_capture_disk") {
                    try self.storage.save(result)
                }
                let relativePath = fileURL.lastPathComponent

                // Notify callback (for DataStore integration)
                self.onCapture?(result, relativePath)

                DispatchQueue.main.async {
                    self.lastCapture = result
                    self.captureCount += 1
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = .error(error.localizedDescription)
                }
            }

            perfLogger.endMeasurement(pipelineToken)

            // Periodic memory snapshot every 10 captures
            if self.captureCount % 10 == 0 {
                perfLogger.takeMemorySnapshot()
            }
        }
    }
}
