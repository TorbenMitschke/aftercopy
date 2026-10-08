import AppKit
import Carbon

final class PasteCoordinator {
    private let clipboardWriter = ClipboardWriter()
    private var destination: NSRunningApplication?
    private var sessionID: UInt64 = 0
    private var selectionAccepted = false
    private var menuClosed = false
    private var expectedChangeCount: Int?
    private var deadline: TimeInterval = 0
    private var timer: Timer?
    private var activationRequested = false
    private var alreadyPosted = false
    var onFallback: ((String?) -> Void)?

    var permissionGranted: Bool { CGPreflightPostEventAccess() }

    func requestPermission() {
        // Only called by the explicit Enable Direct Paste menu action.
        CGRequestPostEventAccess()
    }

    func beginSession(destination: NSRunningApplication?) -> UInt64 {
        stop()
        self.destination = destination
        selectionAccepted = false
        menuClosed = false
        activationRequested = false
        alreadyPosted = false
        return sessionID
    }

    func select(_ text: String, session: UInt64) {
        guard session == sessionID, !selectionAccepted else { return }
        selectionAccepted = true
        guard clipboardWriter.copy(text) else {
            finish(reason: PasteEligibility.Reason.copyFailed.rawValue)
            return
        }
        expectedChangeCount = NSPasteboard.general.changeCount
        deadline = ProcessInfo.processInfo.systemUptime + 1.0
        scheduleReadinessCheck()
    }

    func menuDidClose(session: UInt64) {
        guard session == sessionID else { return }
        menuClosed = true
        // The item action may run after menuDidClose. A default-mode timer waits
        // until native menu tracking has unwound before checking selection/readiness.
        scheduleReadinessCheck()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        destination = nil
        expectedChangeCount = nil
        sessionID &+= 1
    }

    private func scheduleReadinessCheck() {
        guard timer == nil else { return }
        let scheduledSession = sessionID
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.sessionID == scheduledSession else { return }
                self.advance()
            }
        }
    }

    private func advance() {
        guard let expectedChangeCount else {
            stop() // Menu dismissal/settings selection: no clipboard write or paste.
            return
        }
        let state = snapshot(expectedChangeCount: expectedChangeCount)
        switch PasteEligibility.evaluate(state) {
        case .wait:
            return
        case .activateDestination:
            guard !activationRequested else { return }
            activationRequested = true
            guard destination?.activate(options: []) == true else {
                finish(reason: PasteEligibility.Reason.focus.rawValue)
                return
            }
        case .copyOnly(let reason):
            finish(reason: reason.rawValue)
        case .post:
            postPaste(expectedChangeCount: expectedChangeCount)
        }
    }

    private func snapshot(expectedChangeCount: Int) -> PasteEligibility.Snapshot {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let held = !flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty
        return PasteEligibility.Snapshot(
            destinationPID: destination?.processIdentifier,
            ownPID: ProcessInfo.processInfo.processIdentifier,
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            destinationRunning: destination?.isTerminated == false,
            permissionGranted: permissionGranted, copySucceeded: true,
            currentSession: selectionAccepted, alreadyPosted: alreadyPosted,
            clipboardUnchanged: NSPasteboard.general.changeCount == expectedChangeCount,
            menuClosed: menuClosed, modifiersHeld: held,
            deadlineReached: ProcessInfo.processInfo.systemUptime >= deadline)
    }

    private func postPaste(expectedChangeCount: Int) {
        guard let destination,
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            finish(reason: "paste event unavailable")
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        // Recheck immediately before posting, after event creation. Never target
        // whichever app happens to be frontmost, and never retry a posted pair.
        guard PasteEligibility.evaluate(snapshot(expectedChangeCount: expectedChangeCount)) == .post else { return }
        alreadyPosted = true
        down.postToPid(destination.processIdentifier)
        up.postToPid(destination.processIdentifier)
        finish(reason: nil)
    }

    private func finish(reason: String?) {
        stop()
        onFallback?(reason)
    }
}
