@testable import RepoPrompt
import XCTest

@MainActor
final class MentionOverlayControllerTests: XCTestCase {
    func testVisibleRowLimitDefaultsToFiveAndNormalizesInvalidValues() {
        let overlay = MentionOverlayController()

        XCTAssertEqual(overlay.visibleRowLimit, 5)

        let expandedVisibleRows = FileMentionPickerStyle.expanded.configuration.visibleRows
        overlay.visibleRowLimit = expandedVisibleRows
        XCTAssertEqual(overlay.visibleRowLimit, expandedVisibleRows)

        overlay.visibleRowLimit = 0
        XCTAssertEqual(overlay.visibleRowLimit, 1)

        overlay.visibleRowLimit = -4
        XCTAssertEqual(overlay.visibleRowLimit, 1)
    }

    func testSuggestionWindowDisablesNativeShadowForRoundedPopup() {
        let window = MentionOverlayController.SuggestionWindow(
            parent: nil,
            placement: .below
        )

        XCTAssertFalse(
            window.hasShadow,
            "Native NSWindow shadows are rectangular and can show through around the rounded mention popup."
        )
    }

    func testExpandedRootFrameClampsToVisibleScreenArea() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1000, height: 800)
        let caret = NSRect(x: 900, y: 10, width: 1, height: 18)
        let popupSize = NSSize(width: 480, height: 400)

        let frame = MentionOverlayController.positionedRootFrame(
            caret: caret,
            popupSize: popupSize,
            placement: .below,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.width, popupSize.width)
        XCTAssertEqual(frame.height, popupSize.height)
        XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX)
        XCTAssertLessThanOrEqual(frame.maxX, visibleFrame.maxX)
        XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY)
        XCTAssertLessThanOrEqual(frame.maxY, visibleFrame.maxY)
    }

    func testChildFrameOpensLeftWhenRightSideWouldOverflow() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1000, height: 800)
        let parentFrame = NSRect(x: 700, y: 300, width: 240, height: 240)
        let childSize = NSSize(width: 240, height: 240)

        let childFrame = MentionOverlayController.positionedChildFrame(
            after: parentFrame,
            popupSize: childSize,
            placement: .below,
            visibleFrame: visibleFrame
        )

        XCTAssertLessThan(childFrame.maxX, parentFrame.minX)
        XCTAssertGreaterThanOrEqual(childFrame.minX, visibleFrame.minX)
        XCTAssertLessThanOrEqual(childFrame.maxX, visibleFrame.maxX)
    }
}
