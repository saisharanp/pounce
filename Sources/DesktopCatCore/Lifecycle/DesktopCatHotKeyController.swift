import Carbon
import Foundation

/// The three documented commands registered as system hot keys. Registration
/// uses Carbon's hot-key service, not an event tap, so it needs neither input
/// monitoring nor Accessibility permission.
public enum DesktopCatSystemHotKey: CaseIterable {
    case summonOrHide
    case pauseOrResume
    case muteOrUnmute

    public static let commandShiftModifiers = UInt32(cmdKey | shiftKey)

    public var action: DesktopCatKeyboardAction {
        switch self {
        case .summonOrHide: .summonOrHide
        case .pauseOrResume: .pauseOrResume
        case .muteOrUnmute: .muteOrUnmute
        }
    }

    public var keyCode: UInt32 {
        switch self {
        case .summonOrHide: UInt32(kVK_ANSI_C)
        case .pauseOrResume: UInt32(kVK_ANSI_P)
        case .muteOrUnmute: UInt32(kVK_ANSI_M)
        }
    }

    public var modifiers: UInt32 { Self.commandShiftModifiers }

    fileprivate var identifier: UInt32 {
        switch self {
        case .summonOrHide: 1
        case .pauseOrResume: 2
        case .muteOrUnmute: 3
        }
    }
}

@MainActor
final class DesktopCatHotKeyController {
    private static let signature = OSType(0x4443_4154) // "DCAT"

    private let menuController: MenuBarController
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []

    init(menuController: MenuBarController) {
        self.menuController = menuController
        registerHotKeys()
    }

    deinit {
        MainActor.assumeIsolated {
            hotKeys.forEach { UnregisterEventHotKey($0) }
            if let eventHandler {
                RemoveEventHandler(eventHandler)
            }
        }
    }

    private func registerHotKeys() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handleHotKeyEvent,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard status == noErr else { return }

        for hotKey in DesktopCatSystemHotKey.allCases {
            var registeredHotKey: EventHotKeyRef?
            let registrationStatus = RegisterEventHotKey(
                hotKey.keyCode,
                DesktopCatSystemHotKey.commandShiftModifiers,
                EventHotKeyID(signature: Self.signature, id: hotKey.identifier),
                GetApplicationEventTarget(),
                0,
                &registeredHotKey
            )
            if registrationStatus == noErr, let registeredHotKey {
                hotKeys.append(registeredHotKey)
            }
        }
    }

    private func performAction(identifier: UInt32) {
        guard let hotKey = DesktopCatSystemHotKey.allCases.first(where: { $0.identifier == identifier }) else {
            return
        }
        switch hotKey {
        case .summonOrHide:
            menuController.toggleVisibility()
        case .pauseOrResume:
            menuController.togglePause()
        case .muteOrUnmute:
            menuController.toggleMuted()
        }
    }

    private static let handleHotKeyEvent: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return noErr }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else { return status }

        let controller = Unmanaged<DesktopCatHotKeyController>
            .fromOpaque(userData)
            .takeUnretainedValue()
        Task { @MainActor [weak controller] in
            controller?.performAction(identifier: hotKeyID.id)
        }
        return noErr
    }
}
