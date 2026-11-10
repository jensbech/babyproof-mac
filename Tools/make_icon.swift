import AppKit

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func linearGradient(_ ctx: CGContext, _ colors: [CGColor], from start: CGPoint, to end: CGPoint) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
}

func drawIcon(_ ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.3))
    ctx.addPath(squircle)
    ctx.setFillColor(rgb(0x9CC9FF))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    linearGradient(ctx, [rgb(0xA8D8FF), rgb(0xC7B3FF), rgb(0xFFB8D9)], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))

    let confetti: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
        (210, 790, 0.5, 0xFF6B8B), (330, 860, -0.4, 0x4FD1A5), (700, 860, 0.3, 0xFFC93C),
        (820, 770, -0.6, 0x6C8CFF), (190, 560, 0.9, 0xFFC93C), (840, 560, 0.2, 0xFF6B8B),
        (220, 300, -0.3, 0x6C8CFF), (330, 190, 0.7, 0xFFC93C), (700, 190, -0.8, 0x4FD1A5),
        (820, 310, 0.4, 0xB57CFF), (520, 880, 1.2, 0xB57CFF), (160, 430, -1.0, 0x4FD1A5),
    ]
    for (x, y, angle, color) in confetti {
        ctx.saveGState()
        ctx.translateBy(x: x, y: y)
        ctx.rotate(by: angle)
        ctx.addPath(CGPath(roundedRect: CGRect(x: -30, y: -15, width: 60, height: 30), cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.setFillColor(rgb(color))
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.restoreGState()

    let center = CGPoint(x: 512, y: 520)
    let radius: CGFloat = 255
    let face = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x5A3E8C, 0.35))
    ctx.addEllipse(in: face)
    ctx.setFillColor(rgb(0xFFD54F))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addEllipse(in: face)
    ctx.clip()
    linearGradient(ctx, [rgb(0xFFE57A), rgb(0xFFB938)], from: CGPoint(x: 512, y: center.y + radius), to: CGPoint(x: 512, y: center.y - radius))
    ctx.restoreGState()

    let ink = rgb(0x3D2C5E)
    ctx.setFillColor(ink)
    ctx.fillEllipse(in: CGRect(x: 405, y: 560, width: 58, height: 82))
    ctx.fillEllipse(in: CGRect(x: 561, y: 560, width: 58, height: 82))
    ctx.setFillColor(rgb(0xFFFFFF, 0.9))
    ctx.fillEllipse(in: CGRect(x: 425, y: 608, width: 20, height: 20))
    ctx.fillEllipse(in: CGRect(x: 581, y: 608, width: 20, height: 20))

    ctx.setFillColor(rgb(0xFF7FA3, 0.55))
    ctx.fillEllipse(in: CGRect(x: 330, y: 470, width: 80, height: 50))
    ctx.fillEllipse(in: CGRect(x: 614, y: 470, width: 80, height: 50))

    ctx.setStrokeColor(ink)
    ctx.setLineWidth(34)
    ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: 512, y: 520), radius: 140, startAngle: -.pi * 0.18, endAngle: -.pi * 0.82, clockwise: true)
    ctx.strokePath()
}

func renderPNG(size: Int, to url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "icon", code: 1)
    }
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    let scale = CGFloat(size) / 1024
    ctx.scaleBy(x: scale, y: scale)
    drawIcon(ctx)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "icon", code: 2)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw NSError(domain: "icon", code: 3) }
}

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write("usage: make_icon <output.iconset>\n".data(using: .utf8)!)
    exit(1)
}
let dir = URL(fileURLWithPath: args[1])
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try renderPNG(size: base, to: dir.appendingPathComponent("icon_\(base)x\(base).png"))
    try renderPNG(size: base * 2, to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
