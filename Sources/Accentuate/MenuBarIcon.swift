import AppKit

enum MenuBarIcon {
    private static let side: CGFloat = 20

    /// An "a" wearing an acute accent, drawn as a template so it follows the menu bar's colors.
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let font = NSFont.systemFont(ofSize: 18, weight: .bold)
            let rounded = NSFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: 18) ?? font
            let letter = NSAttributedString(string: "a", attributes: [.font: rounded, .foregroundColor: NSColor.black])
            let size = letter.size()
            letter.draw(at: NSPoint(x: (side - size.width) / 2 - 0.6, y: -1.4))

            let accent = NSBezierPath()
            accent.lineWidth = 2.2
            accent.lineCapStyle = .round
            accent.move(to: NSPoint(x: 8.6, y: 13.6))
            accent.line(to: NSPoint(x: 11.6, y: 16.9))
            NSColor.black.setStroke()
            accent.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
