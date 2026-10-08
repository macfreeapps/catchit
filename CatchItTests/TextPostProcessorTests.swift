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
