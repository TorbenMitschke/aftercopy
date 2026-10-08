import XCTest
@testable import aftercopy

final class PasteEligibilityTests: XCTestCase {
    private func ready() -> PasteEligibility.Snapshot {
        PasteEligibility.Snapshot(destinationPID: 20, ownPID: 10, frontmostPID: 20,
            destinationRunning: true, permissionGranted: true, copySucceeded: true,
            currentSession: true, alreadyPosted: false, clipboardUnchanged: true,
            menuClosed: true, modifiersHeld: false, deadlineReached: false)
    }

    func test_readySelectionPosts() {
        XCTAssertEqual(PasteEligibility.evaluate(ready()), .post)
    }
    func test_missingPermissionCopiesOnlyEvenWhileModifiersAreHeld() {
        var state = ready(); state.permissionGranted = false; state.modifiersHeld = true
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.permission))
    }
    func test_missingDestinationCopiesOnly() {
        var state = ready(); state.destinationPID = nil
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.destination))
    }
    func test_terminatedDestinationCopiesOnly() {
        var state = ready(); state.destinationRunning = false
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.destination))
    }
    func test_selfDestinationIsRejected() {
        var state = ready(); state.destinationPID = state.ownPID
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.destination))
    }
    func test_foreignFocusIsNotStolen() {
        var state = ready(); state.frontmostPID = 30
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.focus))
    }
    func test_unknownFocusCopiesOnly() {
        var state = ready(); state.frontmostPID = nil
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.focus))
    }
    func test_selfFocusRequestsDestinationActivationBeforePosting() {
        var state = ready(); state.frontmostPID = state.ownPID
        XCTAssertEqual(PasteEligibility.evaluate(state), .activateDestination)
        state.frontmostPID = state.destinationPID
        XCTAssertEqual(PasteEligibility.evaluate(state), .post)
    }
    func test_waitsUntilMenuCloses() {
        var state = ready(); state.menuClosed = false
        XCTAssertEqual(PasteEligibility.evaluate(state), .wait)
    }
    func test_waitsForModifierRelease() {
        var state = ready(); state.modifiersHeld = true
        XCTAssertEqual(PasteEligibility.evaluate(state), .wait)
        state.modifiersHeld = false
        XCTAssertEqual(PasteEligibility.evaluate(state), .post)
    }
    func test_timeoutAbandonsHeldShortcut() {
        var state = ready(); state.modifiersHeld = true; state.deadlineReached = true
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.timeout))
    }
    func test_newClipboardContentsPreventPaste() {
        var state = ready(); state.clipboardUnchanged = false
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.clipboard))
    }
    func test_staleSessionCannotPost() {
        var state = ready(); state.currentSession = false
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.cancelled))
    }
    func test_postedSelectionCannotReplay() {
        var state = ready(); state.alreadyPosted = true
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.cancelled))
    }
    func test_failedClipboardWriteCannotPost() {
        var state = ready(); state.copySucceeded = false
        XCTAssertEqual(PasteEligibility.evaluate(state), .copyOnly(.copyFailed))
    }
}
