import Foundation

nonisolated enum PasteEligibility {
    nonisolated enum Reason: String {
        case permission = "enable Accessibility"
        case destination = "destination unavailable"
        case focus = "destination focus changed"
        case clipboard = "clipboard changed"
        case timeout = "paste readiness timed out"
        case cancelled = "selection superseded"
        case copyFailed = "clipboard write failed"
    }

    nonisolated enum Decision: Equatable {
        case wait
        case activateDestination
        case post
        case copyOnly(Reason)
    }

    nonisolated struct Snapshot {
        var destinationPID: Int32?
        var ownPID: Int32
        var frontmostPID: Int32?
        var destinationRunning: Bool
        var permissionGranted: Bool
        var copySucceeded: Bool
        var currentSession: Bool
        var alreadyPosted: Bool
        var clipboardUnchanged: Bool
        var menuClosed: Bool
        var modifiersHeld: Bool
        var deadlineReached: Bool
    }

    static func evaluate(_ state: Snapshot) -> Decision {
        guard state.currentSession, !state.alreadyPosted else { return .copyOnly(.cancelled) }
        guard state.copySucceeded else { return .copyOnly(.copyFailed) }
        guard state.permissionGranted else { return .copyOnly(.permission) }
        guard let destination = state.destinationPID, destination != state.ownPID,
              state.destinationRunning else { return .copyOnly(.destination) }
        guard state.clipboardUnchanged else { return .copyOnly(.clipboard) }
        guard !state.deadlineReached else { return .copyOnly(.timeout) }
        guard state.menuClosed else { return .wait }
        if state.frontmostPID == state.ownPID { return .activateDestination }
        guard state.frontmostPID == destination else { return .copyOnly(.focus) }
        guard !state.modifiersHeld else { return .wait }
        return .post
    }
}
