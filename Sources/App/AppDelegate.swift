import Cocoa
import ApplicationServices
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var tapLock: EventTapLock?
    private let watcher = ActivationWatcher()
    private var watchTimer: Timer?
    private var statusItem: NSStatusItem?
    private var nsCursorHides = 0
    private var displayCursorHides = 0
    private let engine = EffectsEngine()
    private var bindings = KeyBindings.load()
    private lazy var tracker = bindings.unlockMatcher()
    private var settingsWindow: SettingsWindowController?
    private var startItem: NSMenuItem?
    private var recordingKeys: Bool { settingsWindow?.isRecording ?? false }
    private let power = PowerAssertion()
    private var permissionWindow: PermissionWindowController?
    private var pollTimer: Timer?
    private var tickTimer: Timer?
    private var tickCount = 0
    private var lastFlags: CGEventFlags = []
    private var locked = false
    private var screenObserver: NSObjectProtocol?

    private static let lockPresentationOptions: NSApplication.PresentationOptions = [
        .hideDock, .hideMenuBar,
        .disableProcessSwitching, .disableForceQuit,
        .disableSessionTermination, .disableHideApplication,
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installStatusItem()
        watcher.setMatcher(bindings.activationMatcher())
        watcher.onActivate = { [weak self] in self?.activateFromWatcher() }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options), startWatching() { return }
        showPermissionWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        stopWatching()
        pollTimer?.invalidate()
        teardownLock()
        permissionWindow?.dismiss()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "Baby Mode")
        let menu = NSMenu()
        let start = NSMenuItem(title: "", action: #selector(startFromMenu), keyEquivalent: "")
        start.target = self
        menu.addItem(start)
        startItem = start
        updateStartTitle()
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Baby Mode", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        item.menu = menu
        statusItem = item
    }

    private func updateStartTitle() {
        startItem?.title = "Start Baby Mode (\(KeyNames.describe(bindings.activation)))"
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let controller = SettingsWindowController(bindings: bindings)
            controller.onSave = { [weak self] in self?.apply($0) }
            controller.onRecordingChanged = { [weak self] recording in
                guard let self = self, !self.locked else { return }
                if recording {
                    self.stopWatching()
                } else if self.permissionWindow == nil {
                    self.resumeWatching()
                }
            }
            settingsWindow = controller
        }
        settingsWindow?.show()
    }

    private func apply(_ newBindings: KeyBindings) {
        bindings = newBindings
        bindings.save()
        watcher.setMatcher(bindings.activationMatcher())
        tracker = bindings.unlockMatcher()
        updateStartTitle()
    }

    @objc private func startFromMenu() {
        guard !locked, !recordingKeys else { return }
        stopWatching()
        if enterLock() { return }
        resumeWatching()
        let alert = NSAlert()
        alert.messageText = "Baby Mode can't start right now"
        alert.informativeText = "Close any password field or password manager, and check that Baby Mode is allowed under Accessibility."
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func activateFromWatcher() {
        guard !locked, !recordingKeys else { return }
        stopWatching()
        if !enterLock() { resumeWatching() }
    }

    private func startWatching() -> Bool {
        guard watcher.start() else { return false }
        watchTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkWatcher()
        }
        RunLoop.main.add(watchTimer!, forMode: .common)
        return true
    }

    private func stopWatching() {
        watchTimer?.invalidate()
        watchTimer = nil
        watcher.stop()
    }

    private func resumeWatching() {
        if !startWatching() { showPermissionWindow() }
    }

    private func checkWatcher() {
        if recordingKeys { return }
        if AXIsProcessTrusted() && watcher.isHealthy { return }
        stopWatching()
        resumeWatching()
    }

    private func showPermissionWindow() {
        guard permissionWindow == nil else { return }
        let controller = PermissionWindowController(startDescription: KeyNames.describe(bindings.activation))
        controller.onQuit = { NSApp.terminate(nil) }
        permissionWindow = controller
        controller.show(status: "Waiting for permission...")
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollPermission()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    private func pollPermission() {
        guard !locked, !recordingKeys, AXIsProcessTrusted(), startWatching() else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        permissionWindow?.dismiss()
        permissionWindow = nil
    }

    private func enterLock() -> Bool {
        guard !IsSecureEventInputEnabled() else { return false }
        let lock = EventTapLock()
        lock.onKey = { [weak self] input in self?.handle(input) }
        lock.onFatal = { [weak self] in DispatchQueue.main.async { self?.leaveLock() } }
        settingsWindow?.close()
        guard lock.start() else { return false }
        tapLock = lock
        locked = true
        tracker.reset()
        lastFlags = []

        NSApp.activate(ignoringOtherApps: true)
        engine.rebuild()
        NSApp.presentationOptions = AppDelegate.lockPresentationOptions
        power.acquire()
        hideCursor()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.engine.rebuild()
            self?.hideCursor()
        }

        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
        return true
    }

    private func hideCursor() {
        NSCursor.hide()
        nsCursorHides += 1
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        if CGGetActiveDisplayList(16, &ids, &count) == .success {
            for id in ids.prefix(Int(count)) {
                CGDisplayHideCursor(id)
                displayCursorHides += 1
            }
        }
    }

    private func showCursor() {
        for _ in 0..<displayCursorHides { CGDisplayShowCursor(CGMainDisplayID()) }
        for _ in 0..<nsCursorHides { NSCursor.unhide() }
        displayCursorHides = 0
        nsCursorHides = 0
    }

    private func handle(_ input: KeyInput) {
        var unlockRequested = false
        switch input {
        case let .keyDown(code, isRepeat, character):
            if tracker.handle(.keyDown(code: code, isRepeat: isRepeat)) { unlockRequested = true }
            if !isRepeat { engine.spawn(character) }
        case .keyUp:
            break
        case let .flagsChanged(flags):
            _ = tracker.handle(.modifiersChanged)
            let watched: UInt64 = CGEventFlags.maskShift.rawValue | CGEventFlags.maskControl.rawValue
                | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue
                | CGEventFlags.maskSecondaryFn.rawValue | CGEventFlags.maskAlphaShift.rawValue
            let added = (flags.rawValue & watched) & ~(lastFlags.rawValue & watched)
            lastFlags = flags
            if added != 0 { engine.spawn(nil) }
        }
        if unlockRequested { DispatchQueue.main.async { [weak self] in self?.leaveLock() } }
    }

    private func tick() {
        tickCount += 1
        if tickCount % 5 == 0 {
            guard let lock = tapLock, lock.isHealthy || lock.reenable(), AXIsProcessTrusted(), !IsSecureEventInputEnabled() else {
                leaveLock()
                return
            }
        }
    }

    private func leaveLock() {
        guard locked else { return }
        teardownLock()
        NSApp.hide(nil)
        if !recordingKeys { resumeWatching() }
    }

    private func teardownLock() {
        guard locked else { return }
        locked = false
        tickTimer?.invalidate()
        tickTimer = nil
        if let observer = screenObserver { NotificationCenter.default.removeObserver(observer) }
        screenObserver = nil
        tapLock?.stop()
        tapLock = nil
        NSApp.presentationOptions = []
        showCursor()
        engine.teardown()
        power.release()
    }
}
