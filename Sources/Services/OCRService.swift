import Foundation
import Vision
import AppKit

// MARK: - OCR Result

/// The result of OCR text extraction from a captured screenshot.
struct OCRResult: Codable {
    /// All recognized text concatenated into a single string.
    let fullText: String

    /// Individual text observations with position and confidence.
    let observations: [TextObservation]

    /// The detected language (best guess from Vision, nil if undetermined).
    let detectedLanguage: String?

    /// Processing time in seconds.
    let processingTime: TimeInterval

    /// Whether any text was found.
    var isEmpty: Bool { fullText.isEmpty }

    /// Average confidence across all observations.
    var averageConfidence: Float {
        guard !observations.isEmpty else { return 0 }
        return observations.map(\.confidence).reduce(0, +) / Float(observations.count)
    }
}

/// A single recognized text region from OCR.
struct TextObservation: Codable {
    let text: String
    let confidence: Float          // 0.0 – 1.0
    let boundingBox: CGRect        // Normalized coordinates (0–1)
}

// CGRect is already Codable via CoreGraphics — no extension needed.

// MARK: - OCR Service Protocol

protocol OCRServiceProtocol {
    /// Extract text from image data (PNG/JPEG). Runs synchronously — call from a background queue.
    func recognizeText(from imageData: Data) -> OCRResult

    /// Extract text from a CGImage. Runs synchronously — call from a background queue.
    func recognizeText(from image: CGImage) -> OCRResult
}

// MARK: - OCR Service (Apple Vision)

/// On-device OCR using Apple's Vision framework (VNRecognizeTextRequest).
/// All processing is local — no network access.
final class OCRService: OCRServiceProtocol {

    /// Minimum confidence threshold for including a text observation.
    let minimumConfidence: Float

    /// Recognition level: .accurate (slower, better) or .fast.
    let recognitionLevel: VNRequestTextRecognitionLevel

    /// Optional language hints to improve recognition accuracy.
    let languageHints: [String]

    init(
        minimumConfidence: Float = 0.3,
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate,
        languageHints: [String] = ["en"]
    ) {
        self.minimumConfidence = minimumConfidence
        self.recognitionLevel = recognitionLevel
        self.languageHints = languageHints
    }

    // MARK: - Public API

    func recognizeText(from imageData: Data) -> OCRResult {
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return emptyResult(processingTime: 0)
        }
        return recognizeText(from: cgImage)
    }

    func recognizeText(from image: CGImage) -> OCRResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        var recognizedObservations: [TextObservation] = []
        var detectedLanguage: String?

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let results = request.results as? [VNRecognizedTextObservation]
            else { return }

            for observation in results {
                guard let topCandidate = observation.topCandidates(1).first,
                      topCandidate.confidence >= self.minimumConfidence
                else { continue }

                recognizedObservations.append(TextObservation(
                    text: topCandidate.string,
                    confidence: topCandidate.confidence,
                    boundingBox: observation.boundingBox
                ))
            }
        }

        // Configure the request
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = true

        if !languageHints.isEmpty {
            request.recognitionLanguages = languageHints
        }

        // Perform the request
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            return emptyResult(processingTime: elapsed)
        }

        // Try to detect language from the recognized text on macOS 14+
        if #available(macOS 14.0, *) {
            detectedLanguage = detectLanguage(from: recognizedObservations.map(\.text).joined(separator: " "))
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Sort observations top-to-bottom (by Y descending in normalized coords, since Vision uses bottom-left origin)
        let sorted = recognizedObservations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }

        let fullText = sorted.map(\.text).joined(separator: "\n")

        return OCRResult(
            fullText: fullText,
            observations: sorted,
            detectedLanguage: detectedLanguage,
            processingTime: elapsed
        )
    }

    // MARK: - Private

    private func emptyResult(processingTime: TimeInterval) -> OCRResult {
        OCRResult(
            fullText: "",
            observations: [],
            detectedLanguage: nil,
            processingTime: processingTime
        )
    }

    /// Best-effort language detection using NLLanguageRecognizer (macOS 14+ for improved accuracy).
    @available(macOS 14.0, *)
    private func detectLanguage(from text: String) -> String? {
        guard !text.isEmpty else { return nil }

        // Use NLLanguageRecognizer for language detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }
}

// Import needed for NLLanguageRecognizer
import NaturalLanguage
