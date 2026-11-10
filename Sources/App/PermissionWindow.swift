import Cocoa

final class PermissionWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let statusLabel: NSTextField
    var onQuit: (() -> Void)?

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
                          styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        statusLabel = NSTextField(wrappingLabelWithString: "")
        super.init()
        window.title = "Baby Mode"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let heading = NSTextField(labelWithString: "Baby Mode needs Accessibility permission")
        heading.font = NSFont.boldSystemFont(ofSize: 16)

        let body = NSTextField(wrappingLabelWithString: "To lock the keyboard and trackpad, Baby Mode must be allowed in System Settings > Privacy & Security > Accessibility. Enable \"Baby Mode\" there. This window will close once permission is granted. Then press Enter, V, Enter to start Baby Mode.")
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Waiting for permission..."

        let open = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openSettings))
        let quit = NSButton(title: "Quit", target: self, action: #selector(quit))
        quit.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [open, quit])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        let stack = NSStackView(views: [heading, body, statusLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
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
    }

    func show(status: String? = nil) {
        if let status = status { statusLabel.stringValue = status }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        window.delegate = nil
        window.orderOut(nil)
        window.close()
    }

    @objc private func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        onQuit?()
    }

    func windowWillClose(_ notification: Notification) {
        onQuit?()
    }
}
