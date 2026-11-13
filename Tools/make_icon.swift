// Draws Resources/AppIcon.icns. Run: swiftc -O Tools/make_icon.swift -o /tmp/make_icon && /tmp/make_icon
import AppKit

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
        let u = s / 1024
        // macOS icon grid: the shape fills 824 of 1024 points.
        let shape = NSBezierPath(roundedRect: NSRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u),
                                 xRadius: 185 * u, yRadius: 185 * u)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -12 * u)
        shadow.shadowBlurRadius = 24 * u
        shadow.set()
        NSColor.black.setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        NSGradient(colors: [NSColor(red: 0.36, green: 0.55, blue: 1.0, alpha: 1),
                            NSColor(red: 0.30, green: 0.22, blue: 0.82, alpha: 1)])!
            .draw(in: shape.bounds, angle: -70)
        // soft highlight
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
            .draw(in: NSRect(x: 100 * u, y: 512 * u, width: 824 * u, height: 412 * u), angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        // The "a"
        let font = NSFont.systemFont(ofSize: 640 * u, weight: .heavy)
        let rounded = NSFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: 640 * u) ?? font
        let attributes: [NSAttributedString.Key: Any] = [.font: rounded, .foregroundColor: NSColor.white]
        let letter = NSAttributedString(string: "a", attributes: attributes)
        let letterSize = letter.size()
        let origin = NSPoint(x: 512 * u - letterSize.width / 2 - 14 * u, y: 512 * u - letterSize.height / 2 - 36 * u)
        NSGraphicsContext.saveGraphicsState()
        let letterShadow = NSShadow()
        letterShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        letterShadow.shadowOffset = NSSize(width: 0, height: -10 * u)
        letterShadow.shadowBlurRadius = 16 * u
        letterShadow.set()
        letter.draw(at: origin)
        NSGraphicsContext.restoreGraphicsState()

        // The accent
        let accent = NSBezierPath()
        accent.lineWidth = 92 * u
        accent.lineCapStyle = .round
        accent.move(to: NSPoint(x: 452 * u, y: 671 * u))
        accent.line(to: NSPoint(x: 572 * u, y: 773 * u))
        NSGraphicsContext.saveGraphicsState()
        letterShadow.set()
        NSColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 1).setStroke()
        accent.stroke()
        NSGraphicsContext.restoreGraphicsState()
        return true
    }
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (name, size) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                     ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(size: size).write(to: iconset.appendingPathComponent("icon_\(name).png"))
}
try! render(size: 1024).write(to: URL(fileURLWithPath: NSTemporaryDirectory() + "AppIcon-preview.png"))
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! task.run(); task.waitUntilExit()
print("Resources/AppIcon.icns written; preview at \(NSTemporaryDirectory())AppIcon-preview.png")
