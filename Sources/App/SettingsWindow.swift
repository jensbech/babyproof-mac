import Cocoa

final class SettingsWindowController: NSObject, NSWindowDelegate {
    enum Slot { case activation, unlock }

    var onSave: ((KeyBindings) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?

    private(set) var isRecording = false
    private var bindings: KeyBindings
    private var recordingSlot: Slot?
    private var recorded: [Int] = []
    private var monitor: Any?

    private let window: NSWindow
    private let activationField = NSTextField(labelWithString: "")
    private let unlockField = NSTextField(labelWithString: "")
    private let activationRecord = NSButton(title: "Record", target: nil, action: nil)
    private let unlockRecord = NSButton(title: "Record", target: nil, action: nil)
    private let activationCancel = NSButton(title: "Cancel", target: nil, action: nil)
    private let unlockCancel = NSButton(title: "Cancel", target: nil, action: nil)
    private let defaultsButton = NSButton(title: "Restore Defaults", target: nil, action: nil)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")

    init(bindings: KeyBindings) {
        self.bindings = bindings
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
                          styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "Baby Mode Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self

        for (button, action) in [
            (activationRecord, #selector(recordActivation)),
            (unlockRecord, #selector(recordUnlock)),
            (activationCancel, #selector(cancelRecording)),
            (unlockCancel, #selector(cancelRecording)),
            (defaultsButton, #selector(restoreDefaults)),
        ] {
            button.target = self
            button.action = action
        }
        activationCancel.isHidden = true
        unlockCancel.isHidden = true
        statusLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            section(title: "Start Baby Mode",
                    hint: "Press each key within \(formatSeconds(KeyBindings.activationGap)) of the last, with no modifiers held. The last key is swallowed; the others still reach the app you're in.",
                    field: activationField, buttons: [activationRecord, activationCancel]),
            section(title: "Return to normal",
                    hint: "Press these keys in a row while locked. Any other key starts over.",
                    field: unlockField, buttons: [unlockRecord, unlockCancel]),
            statusLabel,
            defaultsButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            content.widthAnchor.constraint(equalToConstant: 520),
        ])
        window.contentView = content
        refresh()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        stopRecording()
    }

    private func section(title: String, hint: String, field: NSTextField, buttons: [NSButton]) -> NSView {
        let heading = NSTextField(labelWithString: title)
        heading.font = NSFont.boldSystemFont(ofSize: 14)
        field.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        field.lineBreakMode = .byTruncatingTail
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [field] + buttons)
        row.orientation = .horizontal
        row.spacing = 8
        let hintLabel = NSTextField(wrappingLabelWithString: hint)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        hintLabel.preferredMaxLayoutWidth = 472
        let stack = NSStackView(views: [heading, row, hintLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        row.widthAnchor.constraint(equalToConstant: 472).isActive = true
        return stack
    }

    private func formatSeconds(_ value: TimeInterval) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) s"
    }

    @objc private func recordActivation() { toggle(.activation) }
    @objc private func recordUnlock() { toggle(.unlock) }

    private func toggle(_ slot: Slot) {
        if recordingSlot == slot {
            finish()
        } else {
            startRecording(slot)
        }
    }

    private func startRecording(_ slot: Slot) {
        stopRecording()
        recordingSlot = slot
        recorded = []
        isRecording = true
        statusLabel.stringValue = "Type the new sequence, then click Save."
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.capture(event)
            return nil
        }
        onRecordingChanged?(true)
        refresh()
    }

    private func capture(_ event: NSEvent) {
        guard let slot = recordingSlot, !event.isARepeat else { return }
        if !event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            statusLabel.stringValue = "Modifier keys aren't allowed. Press keys on their own."
            return
        }
        let limit = slot == .activation ? KeyBindings.activationLength.upperBound : KeyBindings.unlockLength.upperBound
        guard recorded.count < limit else {
            statusLabel.stringValue = "That's the maximum of \(limit) keys. Click Save or Cancel."
            return
        }
        recorded.append(KeyCode.normalize(Int(event.keyCode)))
        statusLabel.stringValue = "Type the new sequence, then click Save."
        refresh()
    }

    private func finish() {
        guard let slot = recordingSlot else { return }
        let error = slot == .activation ? KeyBindings.validateActivation(recorded) : KeyBindings.validateUnlock(recorded)
        if let error = error {
            statusLabel.stringValue = error + " Try again."
            recorded = []
            refresh()
            return
        }
        switch slot {
        case .activation: bindings.activation = recorded
        case .unlock: bindings.unlock = recorded
        }
        stopRecording()
        statusLabel.stringValue = "Saved."
        onSave?(bindings)
        refresh()
    }

    @objc private func cancelRecording() {
        stopRecording()
        statusLabel.stringValue = ""
        refresh()
    }

    @objc private func restoreDefaults() {
        stopRecording()
        bindings = KeyBindings.defaults
        statusLabel.stringValue = "Defaults restored."
        onSave?(bindings)
        refresh()
    }

    private func stopRecording() {
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recordingSlot = nil
        recorded = []
        if isRecording {
            isRecording = false
            onRecordingChanged?(false)
        }
    }

    private func refresh() {
        let recordingText = recorded.isEmpty ? "Press keys…" : KeyNames.describe(recorded)
        activationField.stringValue = recordingSlot == .activation ? recordingText : KeyNames.describe(bindings.activation)
        unlockField.stringValue = recordingSlot == .unlock ? recordingText : KeyNames.describe(bindings.unlock)
        activationRecord.title = recordingSlot == .activation ? "Save" : "Record"
        unlockRecord.title = recordingSlot == .unlock ? "Save" : "Record"
        activationCancel.isHidden = recordingSlot != .activation
        unlockCancel.isHidden = recordingSlot != .unlock
        activationRecord.isEnabled = recordingSlot != .unlock
        unlockRecord.isEnabled = recordingSlot != .activation
        defaultsButton.isEnabled = recordingSlot == nil
    }
}
