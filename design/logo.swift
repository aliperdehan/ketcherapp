// Draws the icon (a Kekulé benzene ring):  swift design/logo.swift design/out   (writes icon.png 1024x1024 and sheet.png)
import Cocoa

let S: CGFloat = 1024

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

func canvas(_ draw: (CGRect) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // the tile is 880 of 1024, centred: a little above Apple's 824 grid, which sits small next to other Dock icons
    draw(CGRect(x: 72, y: 72, width: 880, height: 880))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func tile(_ r: CGRect, _ top: NSColor, _ bottom: NSColor) {
    let p = NSBezierPath(roundedRect: r, xRadius: r.width * 0.2245, yRadius: r.width * 0.2245)
    let sh = NSShadow()
    sh.shadowOffset = NSSize(width: 0, height: -12); sh.shadowBlurRadius = 28
    sh.shadowColor = NSColor.black.withAlphaComponent(0.35)
    NSGraphicsContext.saveGraphicsState(); sh.set(); top.setFill(); p.fill(); NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: top, ending: bottom)!.draw(in: p, angle: -90)
}

/// Benzene, pointy-top, with the double bonds on alternate edges (drawn as a shortened parallel line inside the ring).
func benzene(center c: CGPoint, radius: CGFloat, width: CGFloat, color: NSColor) {
    let v = (0..<6).map { i -> CGPoint in
        let a = CGFloat.pi / 2 + CGFloat(i) * .pi / 3
        return CGPoint(x: c.x + radius * cos(a), y: c.y + radius * sin(a))
    }
    let ring = NSBezierPath()
    ring.move(to: v[0])
    for p in v.dropFirst() { ring.line(to: p) }
    ring.close()
    ring.lineWidth = width; ring.lineJoinStyle = .round; ring.lineCapStyle = .round
    color.setStroke(); ring.stroke()

    let inner = NSBezierPath()
    for i in stride(from: 0, to: 6, by: 2) {
        let p = v[i], q = v[(i + 1) % 6]
        let m = CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
        let d = hypot(c.x - m.x, c.y - m.y)
        let u = CGPoint(x: (c.x - m.x) / d, y: (c.y - m.y) / d)
        let off = radius * 0.27, cut: CGFloat = 0.16
        func at(_ t: CGFloat) -> CGPoint {
            CGPoint(x: p.x + (q.x - p.x) * t + u.x * off, y: p.y + (q.y - p.y) * t + u.y * off)
        }
        inner.move(to: at(cut)); inner.line(to: at(1 - cut))
    }
    inner.lineWidth = width; inner.lineCapStyle = .round
    color.setStroke(); inner.stroke()
}

let icon = canvas { r in
    tile(r, rgb(74, 141, 153), rgb(43, 96, 107))   // a gradient around #387580, the teal of Ketcher's toolbar
    benzene(center: CGPoint(x: 512, y: 512), radius: 290, width: 46, color: .white)
}

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "design/out"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
try! icon.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/icon.png"))

// a contact sheet: 300 px, then a 64 px and a 32 px copy, as the Dock and Spotlight show them, on light and dark
let sheet = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 640, pixelsHigh: 340, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sheet)
let img = NSImage(size: NSSize(width: S, height: S)); img.addRepresentation(icon)
for (i, bg) in [NSColor(white: 0.93, alpha: 1), NSColor(white: 0.14, alpha: 1)].enumerated() {
    let x = CGFloat(i) * 320
    bg.setFill(); NSBezierPath(rect: CGRect(x: x, y: 0, width: 320, height: 340)).fill()
    img.draw(in: CGRect(x: x + 10, y: 30, width: 300, height: 300))
    img.draw(in: CGRect(x: x + 40, y: 4, width: 64, height: 64))
    img.draw(in: CGRect(x: x + 150, y: 20, width: 32, height: 32))
}
NSGraphicsContext.restoreGraphicsState()
try! sheet.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/sheet.png"))
print("wrote \(dir)")
