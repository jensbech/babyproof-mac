import Cocoa
import QuartzCore

final class OverlayWindow: NSWindow {
    let effectView: NSView

    init(screen: NSScreen) {
        effectView = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        effectView.wantsLayer = true
        effectView.layer?.backgroundColor = NSColor.clear.cgColor
        effectView.autoresizingMask = [.width, .height]
        contentView = effectView
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class Effect {
    let id: Int
    let root: CALayer
    init(id: Int, root: CALayer) {
        self.id = id
        self.root = root
    }
}

final class EffectsEngine {
    static let maxLiveEffects = 5
    static let letterLifetime: CFTimeInterval = 4.0
    static let fontSize: CGFloat = 170
    static let minSpawnInterval: CFTimeInterval = 0.35

    private(set) var windows: [OverlayWindow] = []
    private var live: [Effect] = []
    private var nextID = 0
    private var lastSpawn: CFTimeInterval = 0
    private var pathCache: [Character: CGPath] = [:]
    private let font: CTFont = EffectsEngine.makeFont()
    private let confettiCells: [CAEmitterCell] = EffectsEngine.makeConfettiCells()
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    private static let palette: [NSColor] = [
        NSColor(hue: 0.58, saturation: 0.30, brightness: 0.92, alpha: 1),
        NSColor(hue: 0.40, saturation: 0.28, brightness: 0.88, alpha: 1),
        NSColor(hue: 0.12, saturation: 0.30, brightness: 0.95, alpha: 1),
        NSColor(hue: 0.75, saturation: 0.24, brightness: 0.90, alpha: 1),
        NSColor(hue: 0.02, saturation: 0.28, brightness: 0.95, alpha: 1),
    ]

    func rebuild() {
        removeAllEffects()
        for window in windows { window.orderOut(nil); window.close() }
        windows = NSScreen.screens.map { OverlayWindow(screen: $0) }
        for (index, window) in windows.enumerated() {
            if index == 0 {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
        }
    }

    func teardown() {
        removeAllEffects()
        for window in windows { window.orderOut(nil); window.close() }
        windows = []
    }

    static func randomCharacter() -> Character {
        alphabet.randomElement() ?? "A"
    }

    func spawn(_ character: Character?) {
        let spawnTime = CACurrentMediaTime()
        guard spawnTime - lastSpawn >= EffectsEngine.minSpawnInterval else { return }
        lastSpawn = spawnTime
        guard let window = windows.randomElement() else { return }
        let bounds = window.effectView.bounds
        guard bounds.width > 400, bounds.height > 400 else { return }
        var char = character ?? EffectsEngine.randomCharacter()
        var path = glyphPath(for: char)
        if path == nil {
            char = EffectsEngine.randomCharacter()
            path = glyphPath(for: char)
        }
        guard let glyph = path, let hostLayer = window.effectView.layer else { return }

        let point = CGPoint(
            x: CGFloat.random(in: 200...(bounds.width - 200)),
            y: CGFloat.random(in: 200...(bounds.height - 200))
        )

        while live.count >= EffectsEngine.maxLiveEffects {
            remove(live[0])
        }

        nextID += 1
        let root = CALayer()
        root.position = point
        root.bounds = .zero

        let box = glyph.boundingBoxOfPath
        let shifted = glyph.copy(using: [CGAffineTransform(translationX: -box.midX, y: -box.midY)]) ?? glyph

        let holder = CALayer()
        let glyphLayer = CALayer()

        let color = EffectsEngine.palette.randomElement() ?? .systemPink
        let rim = CAShapeLayer()
        rim.path = shifted
        rim.fillColor = NSColor(white: 0.2, alpha: 0.5).cgColor
        rim.strokeColor = NSColor(white: 0.2, alpha: 0.5).cgColor
        rim.lineWidth = 6
        rim.lineJoin = .round

        let fill = CAShapeLayer()
        fill.path = shifted
        fill.fillColor = color.cgColor

        glyphLayer.addSublayer(rim)
        glyphLayer.addSublayer(fill)
        holder.addSublayer(glyphLayer)
        root.addSublayer(holder)

        let emitter = CAEmitterLayer()
        emitter.bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        emitter.position = .zero
        emitter.emitterPosition = CGPoint(x: 0.5, y: 0.5)
        emitter.emitterShape = .point
        emitter.emitterSize = .zero
        emitter.renderMode = .unordered
        emitter.emitterCells = confettiCells
        emitter.birthRate = 1
        root.addSublayer(emitter)

        hostLayer.addSublayer(root)
        let effect = Effect(id: nextID, root: root)
        live.append(effect)

        let appear = CABasicAnimation(keyPath: "opacity")
        appear.fromValue = 0.0
        appear.toValue = 1.0
        appear.duration = 0.6
        appear.timingFunction = CAMediaTimingFunction(name: .easeOut)
        glyphLayer.add(appear, forKey: "appear")

        let now = root.convertTime(CACurrentMediaTime(), from: nil)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        fade.beginTime = now + EffectsEngine.letterLifetime - 2.0
        fade.duration = 2.0
        fade.fillMode = .both
        fade.isRemovedOnCompletion = false
        holder.add(fade, forKey: "fade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak emitter] in
            emitter?.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + EffectsEngine.letterLifetime) { [weak self] in
            self?.remove(effect)
        }
    }

    private func remove(_ effect: Effect) {
        guard let index = live.firstIndex(where: { $0.id == effect.id }) else { return }
        live.remove(at: index)
        effect.root.removeAllAnimations()
        effect.root.removeFromSuperlayer()
    }

    private func removeAllEffects() {
        for effect in live { effect.root.removeFromSuperlayer() }
        live.removeAll()
    }

    private func glyphPath(for character: Character) -> CGPath? {
        if let cached = pathCache[character] { return cached }
        var units = Array(String(character).utf16)
        guard units.count == 1 else { return nil }
        var glyphs = [CGGlyph](repeating: 0, count: 1)
        guard CTFontGetGlyphsForCharacters(font, &units, &glyphs, 1), glyphs[0] != 0 else { return nil }
        guard let path = CTFontCreatePathForGlyph(font, glyphs[0], nil) else { return nil }
        pathCache[character] = path
        return path
    }

    private static func makeFont() -> CTFont {
        let base = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        if let rounded = base.fontDescriptor.withDesign(.rounded),
           let font = NSFont(descriptor: rounded, size: fontSize) {
            return font as CTFont
        }
        return (NSFont(name: "Arial Rounded MT Bold", size: fontSize) ?? base) as CTFont
    }

    private static func makeConfettiCells() -> [CAEmitterCell] {
        let width = 24
        let height = 14
        let space = CGColorSpaceCreateDeviceRGB()
        let image: CGImage? = {
            guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: height), cornerWidth: 4, cornerHeight: 4, transform: nil))
            ctx.fillPath()
            return ctx.makeImage()
        }()
        return palette.map { color in
            let cell = CAEmitterCell()
            cell.contents = image
            cell.color = color.cgColor
            cell.birthRate = 20
            cell.lifetime = 2.5
            cell.lifetimeRange = 0.5
            cell.velocity = 60
            cell.velocityRange = 30
            cell.emissionRange = .pi * 2
            cell.yAcceleration = -20
            cell.spin = 0.4
            cell.spinRange = 0.6
            cell.scale = 0.5
            cell.scaleRange = 0.1
            cell.alphaSpeed = -0.4
            return cell
        }
    }
}
