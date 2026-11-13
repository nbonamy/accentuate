import AppKit
import ApplicationServices
import Carbon.HIToolbox
import AccentuateCore

/// Watches typing through an active event tap and, at word boundaries, swaps the
/// unaccented word for its accented form by replaying keystrokes.
final class EventTapController {
    private static let marker: Int64 = 0x41434345 // "ACCE": tags the events we post ourselves

    private let debug = ProcessInfo.processInfo.environment["ACCENTUATE_DEBUG"] != nil
    private var engine: CorrectionEngine
    private var tap: CFMachPort?
    private let source = CGEventSource(stateID: .privateState)

    /// Keystrokes we posted that have not come back through the tap yet. While there are
    /// some, real keystrokes are held back so they cannot interleave with a correction.
    private var pendingSynthetic = 0
    private var pendingSince = Date()
    private var held: [CGEvent] = []

    init(engine: CorrectionEngine) {
        self.engine = engine
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.engine.process(.reset) }
    }

    // MARK: Installation

    func installIfTrusted() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << CGEventMask($1.rawValue)) }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let controller = Unmanaged<EventTapController>.fromOpaque(refcon!).takeUnretainedValue()
            return controller.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        self.tap = tap
        NSLog("Accentuate: event tap installed")
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: Event handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            engine.process(.reset)
            return Unmanaged.passUnretained(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            engine.process(.reset)
            return Unmanaged.passUnretained(event)
        case .keyDown:
            return handleKeyDown(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let passThrough = Unmanaged.passUnretained(event)

        if event.getIntegerValueField(.eventSourceUserData) == Self.marker {
            pendingSynthetic = max(0, pendingSynthetic - 1)
            if pendingSynthetic == 0 { releaseHeldEvents() }
            return passThrough
        }
        if pendingSynthetic > 0 {
            if Date().timeIntervalSince(pendingSince) < 0.5 {
                if let copy = event.copy() { held.append(copy) }
                return nil
            }
            pendingSynthetic = 0 // our events never came back: do not freeze the keyboard
            releaseHeldEvents()
        }

        guard Settings.enabled, !IsSecureEventInputEnabled() else {
            engine.process(.reset)
            return passThrough
        }
        engine.assumeFrench = Settings.assumeFrench

        guard let input = keyInput(for: event) else {
            engine.process(.reset)
            return passThrough
        }

        let action = engine.process(input)
        if debug { NSLog("Accentuate input \(input) -> \(String(describing: action))") }
        switch action {
        case .replace(let original, let replacement)?:
            send(backspaces: original.count)
            type(replacement)
            post(event.copy())
            return nil
        case .revert(let original, let replacement)?:
            send(backspaces: replacement.count + 1)
            type(original)
            return nil
        case nil:
            return passThrough
        }
    }

    private func keyInput(for event: CGEvent) -> KeyInput? {
        if !event.flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate]) { return nil }

        switch Int(event.getIntegerValueField(.keyboardEventKeycode)) {
        case kVK_Delete: return .backspace
        case kVK_Return, kVK_ANSI_KeypadEnter: return .character("\n")
        case kVK_Tab: return .character("\t")
        default: break
        }

        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        let text = String(utf16CodeUnits: buffer, count: length)
        guard text.count == 1, let character = text.first, !character.isNewline,
              character.unicodeScalars.allSatisfy({ $0.value >= 0x20 && !(0xF700...0xF8FF).contains($0.value) })
        else { return nil } // navigation, function keys, escape, dead keys...
        return .character(character)
    }

    // MARK: Posting

    private func post(_ event: CGEvent?) {
        guard let event else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        if event.type == .keyDown { // key-ups never reach our tap, so they are not counted
            if pendingSynthetic == 0 { pendingSince = Date() }
            pendingSynthetic += 1
        }
        event.post(tap: .cgSessionEventTap)
    }

    /// Replays the keystrokes that arrived during a correction, through the tap, in order.
    private func releaseHeldEvents() {
        let events = held
        held = []
        for event in events {
            event.setIntegerValueField(.eventSourceUserData, value: 0)
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func send(backspaces count: Int) {
        for _ in 0..<count {
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: down)
                event?.flags = []
                post(event)
            }
        }
    }

    private func type(_ text: String) {
        for character in text {
            let units = Array(String(character).utf16)
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
                event?.flags = []
                event?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
                post(event)
            }
        }
    }
}
