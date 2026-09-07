import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
        let base = NSBezierPath(roundedRect: NSRect(x: 38, y: 38, width: 948, height: 948), xRadius: 210, yRadius: 210)
        NSColor(srgbRed: 0.10, green: 0.20, blue: 0.18, alpha: 1).setFill(); base.fill()
        let leaf = NSBezierPath(); leaf.move(to: NSPoint(x: 280, y: 745)); leaf.curve(to: NSPoint(x: 747, y: 386), controlPoint1: NSPoint(x: 729, y: 778), controlPoint2: NSPoint(x: 829, y: 629)); leaf.curve(to: NSPoint(x: 280, y: 745), controlPoint1: NSPoint(x: 361, y: 304), controlPoint2: NSPoint(x: 258, y: 449)); leaf.close()
        NSColor(srgbRed: 0.51, green: 0.80, blue: 0.73, alpha: 1).setFill(); leaf.fill()
        let vein = NSBezierPath(); vein.move(to: NSPoint(x: 389, y: 637)); vein.curve(to: NSPoint(x: 774, y: 277), controlPoint1: NSPoint(x: 495, y: 470), controlPoint2: NSPoint(x: 713, y: 516)); vein.lineWidth = 30; vein.lineCapStyle = .round
        NSColor(srgbRed: 0.10, green: 0.20, blue: 0.18, alpha: 1).setStroke(); vein.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
