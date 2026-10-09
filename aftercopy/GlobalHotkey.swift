import Carbon

final class GlobalHotkey {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: 0x41464350, id: 1) // AFCP
    private(set) var registrationStatus: OSStatus = noErr
    var onInvoke: (() -> Void)?

    func configure(_ configuration: ShortcutConfiguration) {
        stop()
        guard configuration != .off else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            // GetApplicationEventTarget delivers on the application's main event loop.
            return MainActor.assumeIsolated {
                let owner = Unmanaged<GlobalHotkey>.fromOpaque(context).takeUnretainedValue()
                return owner.handle(event)
            }
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        registrationStatus = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, context, &eventHandler)
        guard registrationStatus == noErr else {
            releaseResources()
            return
        }

        let keyCode = configuration == .controlOptionV ? UInt32(kVK_ANSI_V) : UInt32(kVK_ANSI_H)
        registrationStatus = RegisterEventHotKey(keyCode, UInt32(controlKey | optionKey), hotKeyID,
                                                GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &hotKey)
        if registrationStatus != noErr { releaseResources() }
    }

    func stop() {
        releaseResources()
        registrationStatus = noErr
    }

    private func releaseResources() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
    }

    private func handle(_ event: EventRef) -> OSStatus {
        var identifier = EventHotKeyID()
        let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                       nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
        guard status == noErr, identifier.signature == hotKeyID.signature, identifier.id == hotKeyID.id else {
            return OSStatus(eventNotHandledErr)
        }
        onInvoke?()
        return noErr
    }
}
