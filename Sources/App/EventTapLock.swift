import Cocoa
import CoreGraphics

enum KeyInput {
    case keyDown(code: Int, isRepeat: Bool, character: Character?)
    case keyUp(code: Int)
    case flagsChanged(CGEventFlags)
}

private let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let lock = Unmanaged<EventTapLock>.fromOpaque(refcon).takeUnretainedValue()
    return lock.handle(type: type, event: event)
}

final class EventTapLock {
    var onKey: ((KeyInput) -> Void)?
    var onFatal: (() -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isHealthy: Bool {
        guard let tap = tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask = ~0
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: refcon
        ) else { return false }
        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0) else {
            CFMachPortInvalidate(created)
            return false
        }
        tap = created
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        if !CGEvent.tapIsEnabled(tap: created) {
            stop()
            return false
        }
        return true
    }

    func stop() {
        if let source = source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        source = nil
        tap = nil
    }

    @discardableResult
    func reenable() -> Bool {
        guard let tap = tap else { return false }
        CGEvent.tapEnable(tap: tap, enable: true)
        return CGEvent.tapIsEnabled(tap: tap)
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if !reenable() { onFatal?() }
            return Unmanaged.passUnretained(event)
        case .keyDown:
            let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            onKey?(.keyDown(code: code, isRepeat: isRepeat, character: isRepeat ? nil : EventTapLock.character(of: event)))
        case .keyUp:
            onKey?(.keyUp(code: Int(event.getIntegerValueField(.keyboardEventKeycode))))
        case .flagsChanged:
            onKey?(.flagsChanged(event.flags))
        default:
            break
        }
        return nil
    }

    private static func character(of event: CGEvent) -> Character? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return nil }
        let string = String(utf16CodeUnits: buffer, count: length)
        guard let first = string.first, first.isLetter || first.isNumber else { return nil }
        return String(first).uppercased().first
    }
}
