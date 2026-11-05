import AppKit

/// Draws the menu bar glyph: a small toggle switch.
///
/// The switch is "on" when Git is configured as expected and "off" when
/// SwitchMyGit isn't set up or something overrides the default identity.
/// The image is a template, so macOS tints it for every menu bar appearance.
enum MenuBarIcon {
    static func image(isOn: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 14), flipped: false) { _ in
            NSColor.black.set()

            let track = NSBezierPath(roundedRect: NSRect(x: 1.25, y: 2.25, width: 17.5, height: 9.5), xRadius: 4.75, yRadius: 4.75)
            track.lineWidth = 1.5
            track.stroke()

            let knobX: CGFloat = isOn ? 10.5 : 3.5
            NSBezierPath(ovalIn: NSRect(x: knobX, y: 4, width: 6, height: 6)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "SwitchMyGit"
        return image
    }
}
