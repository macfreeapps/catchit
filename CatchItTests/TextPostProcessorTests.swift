import XCTest
@testable import CatchIt

final class TextPostProcessorTests: XCTestCase {
    func testKeepsRecognizedLineBreaks() {
        let input = [line("First", x: 0.1, y: 0.8), line("Second", x: 0.1, y: 0.78)]
        XCTAssertEqual(TextPostProcessor.format(input, keepLineBreaks: true), "First\nSecond")
    }

    func testJoinsLinesAndFixesLineEndHyphenation() {
        let input = [line("recogni-", x: 0.1, y: 0.8), line("tion works", x: 0.1, y: 0.78)]
        XCTAssertEqual(TextPostProcessor.format(input, keepLineBreaks: false), "recognition works")
    }

    func testDoesNotTreatEmDashAsHyphenation() {
        let input = [line("A thought—", x: 0.1, y: 0.8), line("continued here", x: 0.1, y: 0.78)]
        XCTAssertEqual(TextPostProcessor.format(input, keepLineBreaks: false), "A thought— continued here")
    }

    func testDetectsParagraphGap() {
        let input = [
            line("Paragraph one", x: 0.1, y: 0.8),
            line("continues", x: 0.1, y: 0.77),
            line("Paragraph two", x: 0.1, y: 0.67)
        ]
        XCTAssertEqual(TextPostProcessor.format(input, keepLineBreaks: true), "Paragraph one\ncontinues\n\nParagraph two")
    }

    func testOrdersClearTwoColumnLayoutByColumn() {
        let input = [
            line("Left one", x: 0.05, y: 0.82), line("Right one", x: 0.65, y: 0.82),
            line("Left two", x: 0.05, y: 0.79), line("Right two", x: 0.65, y: 0.79)
        ]
        XCTAssertEqual(TextPostProcessor.format(input, keepLineBreaks: true), "Left one\nLeft two\n\nRight one\nRight two")
    }

    func testKeepsIsolatedSingleDigitRows() {
        let input = [line("1", x: 0.1, y: 0.8), line("2", x: 0.1, y: 0.78)]
        XCTAssertEqual(TextPostProcessor.format(input, keepLineBreaks: true), "1\n2")
    }

    private func line(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat = 0.25, height: CGFloat = 0.025) -> RecognizedLine {
        RecognizedLine(text: text, bounds: CGRect(x: x, y: y, width: width, height: height))
    }
}

final class CollectionTextTests: XCTestCase {
    func testAppendsWithConfiguredSeparators() {
        XCTAssertEqual(CollectionText.appending("second", to: "first", separator: "\n"), "first\nsecond")
        XCTAssertEqual(CollectionText.appending("second", to: "first", separator: "\n\n"), "first\n\nsecond")
        XCTAssertEqual(CollectionText.appending("second", to: "first", separator: " "), "first second")
    }

    func testEmptyCollectionHasNoLeadingSeparator() {
        XCTAssertEqual(CollectionText.appending("first", to: "", separator: "\n\n"), "first")
    }
}


@MainActor
final class CaptureOverlayCoordinatorTests: XCTestCase {
    func testCaptureOverlayReceivesClicksBeforeAnySelectionIsDrawn() async throws {
        let coordinator = CaptureOverlayCoordinator()
        await coordinator.beginCaptureAfterCurrentEvent(toggles: CaptureToggles(
            keepLineBreaks: true, additiveMode: false, speakAfterCapture: false
        ))
        defer { coordinator.cancelCapture() }

        let panel = try XCTUnwrap(NSApp.windows.first { $0.isVisible && $0.level == .screenSaver })
        panel.displayIfNeeded()
        let point = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
        // Ordering and backing-store updates reach WindowServer asynchronously.
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        var hitWindow = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        while hitWindow != panel.windowNumber, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
            hitWindow = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        }
        XCTAssertEqual(
            hitWindow,
            panel.windowNumber,
            "The initial capture surface must receive clicks rather than pass them to the app underneath."
        )
    }

    func testDraggingSelectionDeliversTheChosenAreaAndDismissesOverlay() async throws {
        let coordinator = CaptureOverlayCoordinator()
        var selection: CaptureSelection?
        coordinator.onSelection = { selection = $0 }
        await coordinator.beginCaptureAfterCurrentEvent(toggles: CaptureToggles(
            keepLineBreaks: true, additiveMode: false, speakAfterCapture: false
        ))
        defer { coordinator.cancelCapture() }
        let panel = try XCTUnwrap(NSApp.windows.first { $0.isVisible && $0.level == .screenSaver })
        let rect = CGRect(x: 40, y: 80, width: 220, height: 90)
        let expected = panel.convertToScreen(rect)
        for (type, point) in [(NSEvent.EventType.leftMouseDown, rect.origin),
                              (.leftMouseDragged, CGPoint(x: rect.maxX, y: rect.maxY)),
                              (.leftMouseUp, CGPoint(x: rect.maxX, y: rect.maxY))] {
            let event = try XCTUnwrap(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1
            ))
            panel.sendEvent(event)
        }
        XCTAssertEqual(try XCTUnwrap(selection).globalRect, expected)
        XCTAssertFalse(coordinator.isCapturing)
    }

    func testCaptureOverlayCanBeOpenedAndDismissedAfterMenuActionReturns() async {
        let coordinator = CaptureOverlayCoordinator()
        await coordinator.beginCaptureAfterCurrentEvent(toggles: CaptureToggles(
            keepLineBreaks: true,
            additiveMode: false,
            speakAfterCapture: false
        ))

        XCTAssertTrue(coordinator.isCapturing)
        coordinator.cancelCapture()
        XCTAssertFalse(coordinator.isCapturing)
    }
}

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import PDFKit
import UniformTypeIdentifiers

final class RecognitionFeatureTests: XCTestCase {
    func testRecognizesGeneratedTextImage() async throws {
        let image = try makeTextImage("CATCH IT 123")
        let result = try await TextRecognizer().recognize(in: image, preferences: OCRPreferences(
            primaryLanguage: "en-US",
            automaticallyDetectsLanguage: true,
            codeSymbolsMode: false,
            customWords: [],
            keepLineBreaks: true
        ))
        XCTAssertTrue(result.localizedCaseInsensitiveContains("CATCH"), "Recognized: \(result)")
        XCTAssertTrue(result.contains("123"), "Recognized: \(result)")
    }

    func testRecognizesGeneratedQRCode() async throws {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("catchit-test-payload".utf8)
        filter.correctionLevel = "M"
        let output = try XCTUnwrap(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let image = try XCTUnwrap(CIContext().createCGImage(output, from: output.extent))
        let values = try await BarcodeRecognizer().recognize(in: image)
        XCTAssertEqual(values, ["catchit-test-payload"])
    }

    func testImportsImageAndMultiPagePDF() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let image = try makeTextImage("PAGE ONE")
        let imageURL = directory.appendingPathComponent("fixture.png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(imageURL as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        XCTAssertEqual(try FileRecognitionService().images(from: imageURL).count, 1)

        let pdfURL = directory.appendingPathComponent("fixture.pdf")
        let document = PDFDocument()
        for _ in 0..<2 {
            let pageImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            document.insert(try XCTUnwrap(PDFPage(image: pageImage)), at: document.pageCount)
        }
        XCTAssertTrue(document.write(to: pdfURL))
        XCTAssertEqual(try FileRecognitionService().images(from: pdfURL).count, 2)
    }

    private func makeTextImage(_ value: String) throws -> CGImage {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 900,
            pixelsHigh: 220,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 900, height: 220)).fill()
        (value as NSString).draw(at: NSPoint(x: 36, y: 70), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 72),
            .foregroundColor: NSColor.black
        ])
        graphics.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return try XCTUnwrap(bitmap.cgImage)
    }
}

final class SmartActionTests: XCTestCase {
    func testFindsLinksAndEmailAddressesWithoutOpeningThem() {
        let actions = SmartActionDetector.detect(in: "Visit https://example.com and contact team@example.com")
        XCTAssertTrue(actions.contains { $0.kind == .url && $0.value == "https://example.com" })
        XCTAssertTrue(actions.contains { $0.kind == .email && $0.value == "team@example.com" })
    }
}

final class HotKeyBindingTests: XCTestCase {
    func testCatchTextShortcutUsesControlOptionSpace() {
        XCTAssertEqual(HotKeyBinding.defaults[.catchText]?.displayName, "⌃⌥Space key")
    }
}
