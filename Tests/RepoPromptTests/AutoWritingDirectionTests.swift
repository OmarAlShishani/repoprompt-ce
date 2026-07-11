import AppKit
@testable import RepoPrompt
import XCTest

final class AutoWritingDirectionTests: XCTestCase {
    // MARK: - Right-to-left detection (any RTL character in the line)

    func testDetectsRightToLeftWhenLineContainsArabicOrHebrew() {
        XCTAssertTrue(BidiScanner.containsStrongRTL("مرحبا"))
        XCTAssertTrue(BidiScanner.containsStrongRTL("שלום"))
        // Key policy: English first, but the line contains an Arabic word -> RTL.
        XCTAssertTrue(BidiScanner.containsStrongRTL("Hello مرحبا"))
        XCTAssertTrue(BidiScanner.containsStrongRTL("Order #42 مرحبا!"))
    }

    func testDetectsLeftToRightWhenNoRTLCharacter() {
        XCTAssertFalse(BidiScanner.containsStrongRTL("Hello"))
        XCTAssertFalse(BidiScanner.containsStrongRTL("Hello world."))
        XCTAssertFalse(BidiScanner.containsStrongRTL("123 !@# …"))
        XCTAssertFalse(BidiScanner.containsStrongRTL(""))
        XCTAssertFalse(BidiScanner.containsStrongRTL("👍🎉"))
    }

    // MARK: - Per-paragraph attributed-string pass

    private func paragraphStyle(_ string: NSAttributedString, at location: Int) -> NSParagraphStyle? {
        string.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
    }

    func testRightToLeftParagraphBecomesRightAligned() {
        let input = NSAttributedString(string: "مرحبا بالعالم")
        let result = input.applyingAutoParagraphWritingDirection()
        let style = paragraphStyle(result, at: 0)
        XCTAssertEqual(style?.baseWritingDirection, .rightToLeft)
        XCTAssertEqual(style?.alignment, .right)
    }

    func testEnglishFirstLineContainingArabicBecomesRightToLeft() {
        // "Hello مرحبا" starts with English but contains an Arabic word -> RTL.
        let input = NSAttributedString(string: "Hello مرحبا")
        let result = input.applyingAutoParagraphWritingDirection()
        let style = paragraphStyle(result, at: 0)
        XCTAssertEqual(style?.baseWritingDirection, .rightToLeft)
        XCTAssertEqual(style?.alignment, .right)
    }

    func testPureLeftToRightParagraphIsLeftUntouched() {
        let input = NSAttributedString(string: "Hello world")
        let result = input.applyingAutoParagraphWritingDirection()
        // No paragraph style is added for pure LTR content, so it renders exactly as before.
        XCTAssertNil(paragraphStyle(result, at: 0))
    }

    func testMixedParagraphsAreDirectedIndependently() {
        // Line 1 "Hello مرحبا" contains Arabic -> RTL; line 2 "Goodbye" is pure LTR -> untouched.
        // "Hello مرحبا\n" occupies UTF-16 range 0..<12; "Goodbye" starts at index 12.
        let input = NSAttributedString(string: "Hello مرحبا\nGoodbye")
        let result = input.applyingAutoParagraphWritingDirection()
        XCTAssertEqual(paragraphStyle(result, at: 0)?.baseWritingDirection, .rightToLeft)
        XCTAssertEqual(paragraphStyle(result, at: 0)?.alignment, .right)
        XCTAssertNil(paragraphStyle(result, at: 12), "Pure LTR line should stay untouched")
    }

    func testCodeBlockParagraphStaysLeftToRight() {
        // A fenced code block tagged with `.codeBlockSource` must never flip, even when it
        // contains right-to-left characters.
        let code = NSMutableAttributedString(string: "let مرحبا = 1")
        code.addAttribute(
            .codeBlockSource,
            value: "let مرحبا = 1",
            range: NSRange(location: 0, length: code.length)
        )
        let result = code.applyingAutoParagraphWritingDirection()
        XCTAssertNotEqual(paragraphStyle(result, at: 0)?.baseWritingDirection, .rightToLeft)
    }
}
