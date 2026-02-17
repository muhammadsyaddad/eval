import XCTest
import AppKit
import CoreGraphics
@testable import Eval

// MARK: - OCR Benchmark Tests (Intel)
//
// These tests measure OCR latency on the current hardware.
// Run with: swift test --filter OCRBenchmarkTests
//
// Results are printed to stdout and recorded in test output.

final class OCRBenchmarkTests: XCTestCase {

    private var ocrService: OCRService!

    override func setUp() {
        super.setUp()
        ocrService = OCRService(
            minimumConfidence: 0.3,
            recognitionLevel: .accurate,
            languageHints: ["en"]
        )
    }

    // MARK: - Helper: Generate test image with text

    /// Creates a PNG image with rendered text to simulate a screen capture.
    private func createTestImage(width: Int, height: Int, lines: [String]) -> Data? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // White background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw text lines
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext

        let font = NSFont.systemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        var y = CGFloat(height) - 30
        for line in lines {
            let str = NSAttributedString(string: line, attributes: attributes)
            let lineRect = CGRect(x: 20, y: y, width: CGFloat(width) - 40, height: 20)
            str.draw(in: lineRect)
            y -= 22
        }

        NSGraphicsContext.current = nil

        guard let cgImage = context.makeImage() else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }

    // MARK: - Benchmark: Small image (simulates a focused window)

    func testBenchmarkSmallImage() throws {
        let lines = [
            "Eval - Privacy-focused activity recorder",
            "Today's screen time: 4h 32m",
            "Top apps: Safari (1h 20m), Xcode (2h 10m), Terminal (45m)",
            "Productivity score: 78%",
        ]

        guard let imageData = createTestImage(width: 800, height: 600, lines: lines) else {
            XCTFail("Failed to create test image")
            return
        }

        let iterations = 5
        var totalTime: TimeInterval = 0
        var results: [OCRResult] = []

        for i in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            let result = ocrService.recognizeText(from: imageData)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            totalTime += elapsed
            results.append(result)

            print("  [Small 800x600] Iteration \(i+1): \(String(format: "%.3f", elapsed))s — \(result.observations.count) observations, confidence: \(String(format: "%.2f", result.averageConfidence))")
        }

        let avgTime = totalTime / Double(iterations)
        print("\n  [Small 800x600] Average latency: \(String(format: "%.3f", avgTime))s over \(iterations) iterations")
        print("  [Small 800x600] Text found: \(results.last?.fullText.prefix(80) ?? "none")...")

        // Sanity check: OCR should complete in reasonable time
        XCTAssertLessThan(avgTime, 10.0, "OCR on small image should complete within 10 seconds")
    }

    // MARK: - Benchmark: Medium image (simulates a typical desktop window)

    func testBenchmarkMediumImage() throws {
        let lines = [
            "import Foundation",
            "import SwiftUI",
            "",
            "struct ContentView: View {",
            "    @EnvironmentObject var appState: AppState",
            "    ",
            "    var body: some View {",
            "        NavigationSplitView {",
            "            List(SidebarTab.allCases) { tab in",
            "                Label(tab.rawValue, systemImage: tab.icon)",
            "            }",
            "        } detail: {",
            "            switch appState.selectedTab {",
            "            case .today: TodayView()",
            "            case .history: HistoryView()",
            "            case .insights: InsightsView()",
            "            case .settings: SettingsView()",
            "            }",
            "        }",
            "    }",
            "}",
        ]

        guard let imageData = createTestImage(width: 1440, height: 900, lines: lines) else {
            XCTFail("Failed to create test image")
            return
        }

        let iterations = 5
        var totalTime: TimeInterval = 0
        var results: [OCRResult] = []

        for i in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            let result = ocrService.recognizeText(from: imageData)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            totalTime += elapsed
            results.append(result)

            print("  [Medium 1440x900] Iteration \(i+1): \(String(format: "%.3f", elapsed))s — \(result.observations.count) observations, confidence: \(String(format: "%.2f", result.averageConfidence))")
        }

        let avgTime = totalTime / Double(iterations)
        print("\n  [Medium 1440x900] Average latency: \(String(format: "%.3f", avgTime))s over \(iterations) iterations")
        print("  [Medium 1440x900] Text found: \(results.last?.fullText.prefix(80) ?? "none")...")

        XCTAssertLessThan(avgTime, 15.0, "OCR on medium image should complete within 15 seconds")
    }

    // MARK: - Benchmark: Large image (simulates a Retina full-screen capture)

    func testBenchmarkLargeImage() throws {
        var lines: [String] = []
        for i in 0..<40 {
            lines.append("Line \(i+1): The quick brown fox jumps over the lazy dog. Lorem ipsum dolor sit amet.")
        }

        guard let imageData = createTestImage(width: 2560, height: 1440, lines: lines) else {
            XCTFail("Failed to create test image")
            return
        }

        let iterations = 3
        var totalTime: TimeInterval = 0
        var results: [OCRResult] = []

        for i in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            let result = ocrService.recognizeText(from: imageData)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            totalTime += elapsed
            results.append(result)

            print("  [Large 2560x1440] Iteration \(i+1): \(String(format: "%.3f", elapsed))s — \(result.observations.count) observations, confidence: \(String(format: "%.2f", result.averageConfidence))")
        }

        let avgTime = totalTime / Double(iterations)
        print("\n  [Large 2560x1440] Average latency: \(String(format: "%.3f", avgTime))s over \(iterations) iterations")
        print("  [Large 2560x1440] Text found: \(results.last?.fullText.prefix(80) ?? "none")...")

        XCTAssertLessThan(avgTime, 30.0, "OCR on large image should complete within 30 seconds")
    }

    // MARK: - Benchmark: Fast recognition level comparison

    func testBenchmarkFastVsAccurate() throws {
        let lines = [
            "Eval Settings",
            "Capture interval: 30 seconds",
            "OCR enabled: true",
            "Storage limit: 5.0 GB",
            "AI Model: Llama 3.2 1B (Ready)",
        ]

        guard let imageData = createTestImage(width: 1024, height: 768, lines: lines) else {
            XCTFail("Failed to create test image")
            return
        }

        let fastService = OCRService(minimumConfidence: 0.3, recognitionLevel: .fast, languageHints: ["en"])
        let accurateService = OCRService(minimumConfidence: 0.3, recognitionLevel: .accurate, languageHints: ["en"])

        let iterations = 3

        // Fast mode
        var fastTotal: TimeInterval = 0
        var fastResult: OCRResult?
        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            fastResult = fastService.recognizeText(from: imageData)
            fastTotal += CFAbsoluteTimeGetCurrent() - start
        }
        let fastAvg = fastTotal / Double(iterations)

        // Accurate mode
        var accurateTotal: TimeInterval = 0
        var accurateResult: OCRResult?
        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            accurateResult = accurateService.recognizeText(from: imageData)
            accurateTotal += CFAbsoluteTimeGetCurrent() - start
        }
        let accurateAvg = accurateTotal / Double(iterations)

        print("\n  [1024x768] Fast mode:     \(String(format: "%.3f", fastAvg))s avg — \(fastResult?.observations.count ?? 0) observations, confidence: \(String(format: "%.2f", fastResult?.averageConfidence ?? 0))")
        print("  [1024x768] Accurate mode: \(String(format: "%.3f", accurateAvg))s avg — \(accurateResult?.observations.count ?? 0) observations, confidence: \(String(format: "%.2f", accurateResult?.averageConfidence ?? 0))")
        print("  [1024x768] Speedup: \(String(format: "%.1f", accurateAvg / max(fastAvg, 0.001)))x")

        // Both should produce some results
        XCTAssertFalse(fastResult?.isEmpty ?? true, "Fast mode should find text")
        XCTAssertFalse(accurateResult?.isEmpty ?? true, "Accurate mode should find text")
    }

    // MARK: - Benchmark: Empty image (no text)

    func testBenchmarkEmptyImage() throws {
        guard let imageData = createTestImage(width: 800, height: 600, lines: []) else {
            XCTFail("Failed to create test image")
            return
        }

        let start = CFAbsoluteTimeGetCurrent()
        let result = ocrService.recognizeText(from: imageData)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        print("\n  [Empty 800x600] Latency: \(String(format: "%.3f", elapsed))s — \(result.observations.count) observations")

        XCTAssertTrue(result.isEmpty, "Empty image should produce no text")
        XCTAssertLessThan(elapsed, 10.0, "OCR on empty image should complete within 10 seconds (includes Vision framework cold start)")
    }
}
