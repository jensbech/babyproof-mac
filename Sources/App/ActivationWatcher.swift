import Cocoa
import CoreGraphics

private let watcherCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let watcher = Unmanaged<ActivationWatcher>.fromOpaque(refcon).takeUnretainedValue()
    return watcher.handle(type: type, event: event)
}

final class ActivationWatcher {
    var onActivate: (() -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var tracker = KeyBindings.defaults.activationMatcher()

    func setMatcher(_ matcher: KeySequenceMatcher) {
        tracker = matcher
    }

    var isHealthy: Bool {
        guard let tap = tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    func start() -> Bool {
        guard tap == nil else { return true }
        tracker.reset()
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: watcherCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
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

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let now = ProcessInfo.processInfo.systemUptime
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            _ = tracker.handle(.modifiersChanged, at: now)
        case .keyDown:
            let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
            if !event.flags.intersection(modifiers).isEmpty {
                _ = tracker.handle(.modifiersChanged, at: now)
                break
            }
            let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if tracker.handle(.keyDown(code: code, isRepeat: isRepeat), at: now) {
                DispatchQueue.main.async { [weak self] in self?.onActivate?() }
                return nil
            }
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }
}
