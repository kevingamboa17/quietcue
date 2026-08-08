import Carbon.HIToolbox

final class GlobalHotKey {
    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private static let hotKeyID = EventHotKeyID(signature: 0x51554355, id: 1)

    private static let eventHandler: EventHandlerUPP = { _, _, userData in
        guard let userData else { return noErr }
        let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
        hotKey.onPress?()
        return noErr
    }

    func register() {
        guard hotKeyRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard handlerStatus == noErr else { return }

        let modifiers = UInt32(cmdKey | optionKey | controlKey)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_Q),
            modifiers,
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if hotKeyStatus != noErr {
            if let handlerRef {
                RemoveEventHandler(handlerRef)
                self.handlerRef = nil
            }
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}
