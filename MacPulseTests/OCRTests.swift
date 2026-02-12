import XCTest
@testable import MacPulse

// MARK: - Mock OCR Service

final class MockOCRService: OCRServiceProtocol {
    var recognizeCallCount = 0
    var mockResult = OCRResult(
        fullText: "Hello World\nThis is a test",
        observations: [
            TextObservation(text: "Hello World", confidence: 0.95, boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.05)),
            TextObservation(text: "This is a test", confidence: 0.88, boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.6, height: 0.05)),
        ],
        detectedLanguage: "en",
        processingTime: 0.15
    )

    func recognizeText(from imageData: Data) -> OCRResult {
        recognizeCallCount += 1
        return mockResult
    }

    func recognizeText(from image: CGImage) -> OCRResult {
        recognizeCallCount += 1
        return mockResult
    }
}

// MARK: - OCR Result Tests

final class OCRResultTests: XCTestCase {

    func testEmptyResult() {
        let result = OCRResult(
            fullText: "",
            observations: [],
            detectedLanguage: nil,
            processingTime: 0.01
        )

        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(result.averageConfidence, 0)
        XCTAssertNil(result.detectedLanguage)
    }

    func testNonEmptyResult() {
        let result = OCRResult(
            fullText: "Some text",
            observations: [
                TextObservation(text: "Some", confidence: 0.9, boundingBox: .zero),
                TextObservation(text: "text", confidence: 0.8, boundingBox: .zero),
            ],
            detectedLanguage: "en",
            processingTime: 0.1
        )

        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.fullText, "Some text")
        XCTAssertEqual(result.observations.count, 2)
        XCTAssertEqual(result.detectedLanguage, "en")
    }

    func testAverageConfidence() {
        let result = OCRResult(
            fullText: "a b",
            observations: [
                TextObservation(text: "a", confidence: 0.8, boundingBox: .zero),
                TextObservation(text: "b", confidence: 0.6, boundingBox: .zero),
            ],
            detectedLanguage: nil,
            processingTime: 0
        )

        XCTAssertEqual(result.averageConfidence, 0.7, accuracy: 0.001)
    }

    func testSingleObservationConfidence() {
        let result = OCRResult(
            fullText: "test",
            observations: [
                TextObservation(text: "test", confidence: 0.95, boundingBox: .zero),
            ],
            detectedLanguage: nil,
            processingTime: 0
        )

        XCTAssertEqual(result.averageConfidence, 0.95, accuracy: 0.001)
    }

    func testProcessingTimeRecorded() {
        let result = OCRResult(
            fullText: "",
            observations: [],
            detectedLanguage: nil,
            processingTime: 1.234
        )

        XCTAssertEqual(result.processingTime, 1.234, accuracy: 0.001)
    }

    // MARK: - Codable Tests

    func testOCRResultEncodeDecode() throws {
        let original = OCRResult(
            fullText: "Hello World",
            observations: [
                TextObservation(
                    text: "Hello World",
                    confidence: 0.95,
                    boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.05)
                ),
            ],
            detectedLanguage: "en",
            processingTime: 0.15
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OCRResult.self, from: data)

        XCTAssertEqual(decoded.fullText, original.fullText)
        XCTAssertEqual(decoded.observations.count, 1)
        XCTAssertEqual(decoded.observations[0].text, "Hello World")
        XCTAssertEqual(decoded.observations[0].confidence, 0.95, accuracy: 0.001)
        XCTAssertEqual(decoded.detectedLanguage, "en")
        XCTAssertEqual(decoded.processingTime, 0.15, accuracy: 0.001)
    }

    func testOCRResultEncodeDecodeNilLanguage() throws {
        let original = OCRResult(
            fullText: "test",
            observations: [],
            detectedLanguage: nil,
            processingTime: 0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OCRResult.self, from: data)

        XCTAssertNil(decoded.detectedLanguage)
    }

    func testTextObservationEncodeDecode() throws {
        let original = TextObservation(
            text: "Hello",
            confidence: 0.92,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.03)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextObservation.self, from: data)

        XCTAssertEqual(decoded.text, "Hello")
        XCTAssertEqual(decoded.confidence, 0.92, accuracy: 0.001)
        XCTAssertEqual(decoded.boundingBox.origin.x, 0.1, accuracy: 0.001)
        XCTAssertEqual(decoded.boundingBox.origin.y, 0.2, accuracy: 0.001)
        XCTAssertEqual(decoded.boundingBox.size.width, 0.5, accuracy: 0.001)
        XCTAssertEqual(decoded.boundingBox.size.height, 0.03, accuracy: 0.001)
    }
}

// MARK: - OCR Service Configuration Tests

final class OCRServiceConfigTests: XCTestCase {

    func testDefaultConfiguration() {
        let service = OCRService()
        XCTAssertEqual(service.minimumConfidence, 0.3, accuracy: 0.001)
        XCTAssertEqual(service.recognitionLevel, .accurate)
        XCTAssertEqual(service.languageHints, ["en"])
    }

    func testCustomConfiguration() {
        let service = OCRService(
            minimumConfidence: 0.5,
            recognitionLevel: .fast,
            languageHints: ["en", "de", "fr"]
        )

        XCTAssertEqual(service.minimumConfidence, 0.5, accuracy: 0.001)
        XCTAssertEqual(service.recognitionLevel, .fast)
        XCTAssertEqual(service.languageHints, ["en", "de", "fr"])
    }
}

// MARK: - Scheduler OCR Integration Tests

final class SchedulerOCRTests: XCTestCase {

    func testUpdateOCREnabled() {
        let scheduler = CaptureScheduler(
            screenCapture: MockScreenCaptureService(),
            metadataService: MockWindowMetadataService(),
            storage: MockCaptureStorageService(),
            permissionManager: PermissionManager(),
            ocrService: MockOCRService()
        )

        // Should not crash or change status
        scheduler.updateOCREnabled(false)
        XCTAssertEqual(scheduler.status, .idle)

        scheduler.updateOCREnabled(true)
        XCTAssertEqual(scheduler.status, .idle)
    }

    func testSchedulerCreatedWithOCRService() {
        let ocrService = MockOCRService()
        let scheduler = CaptureScheduler(
            screenCapture: MockScreenCaptureService(),
            metadataService: MockWindowMetadataService(),
            storage: MockCaptureStorageService(),
            permissionManager: PermissionManager(),
            ocrService: ocrService
        )

        // Scheduler should accept the OCR service without issues
        XCTAssertEqual(scheduler.status, .idle)
    }

    func testSchedulerCreatedWithNilOCRService() {
        let scheduler = CaptureScheduler(
            screenCapture: MockScreenCaptureService(),
            metadataService: MockWindowMetadataService(),
            storage: MockCaptureStorageService(),
            permissionManager: PermissionManager(),
            ocrService: nil
        )

        // Scheduler should work without OCR service
        XCTAssertEqual(scheduler.status, .idle)
    }
}

// MARK: - CaptureResult with OCR Tests

final class CaptureResultOCRTests: XCTestCase {

    func testCaptureResultWithOCR() {
        let ocrResult = OCRResult(
            fullText: "Test text",
            observations: [
                TextObservation(text: "Test text", confidence: 0.9, boundingBox: .zero),
            ],
            detectedLanguage: "en",
            processingTime: 0.1
        )

        let result = CaptureResult(
            imageData: Data([0x01]),
            metadata: WindowMetadata.empty,
            ocrResult: ocrResult
        )

        XCTAssertNotNil(result.ocrResult)
        XCTAssertEqual(result.ocrResult?.fullText, "Test text")
    }

    func testCaptureResultWithoutOCR() {
        let result = CaptureResult(
            imageData: Data([0x01]),
            metadata: WindowMetadata.empty
        )

        XCTAssertNil(result.ocrResult)
    }
}
