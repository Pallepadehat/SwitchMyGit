#!/usr/bin/env swift
// Renders the SwitchMyGit logo, app icon set and social preview image.
//
// Usage: swift scripts/generate-icons.swift   (run from the repository root)
//
// The artwork is drawn with Core Graphics so it stays crisp at every size
// and can be tweaked by editing the constants below.

import AppKit

// MARK: - Design tokens

enum Palette {
    static let tileTop = NSColor(white: 1.0, alpha: 1)
    static let tileBottom = NSColor(red: 0.89, green: 0.89, blue: 0.91, alpha: 1)
    static let tileEdge = NSColor(white: 0, alpha: 0.10)
    static let trackTop = NSColor(red: 0.30, green: 0.85, blue: 0.42, alpha: 1)    // system green
    static let trackBottom = NSColor(red: 0.16, green: 0.69, blue: 0.29, alpha: 1)
    static let knobTop = NSColor(white: 1.0, alpha: 1)
    static let knobBottom = NSColor(white: 0.94, alpha: 1)
    static let glyph = NSColor(red: 0.23, green: 0.23, blue: 0.25, alpha: 1)        // graphite
}

// MARK: - Shapes

/// Apple's "continuous corner" squircle, approximated with a superellipse.
func squircle(in rect: CGRect, exponent: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let steps = 720
    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = center.x + a * copysign(pow(abs(c), 2 / exponent), c)
        let y = center.y + b * copysign(pow(abs(s), 2 / exponent), s)
        step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

func linearGradient(_ top: NSColor, _ bottom: NSColor) -> CGGradient {
    CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [top.cgColor, bottom.cgColor] as CFArray,
        locations: [0, 1]
    )!
}

// MARK: - Drawing

/// Draws the icon into a square of `size` points, following Apple's macOS icon
/// grid: an 824 pt tile centred in a 1024 pt canvas.
func drawIcon(in context: CGContext, size: CGFloat) {
    context.saveGState()
    context.scaleBy(x: size / 1024, y: size / 1024)

    let tile = squircle(in: CGRect(x: 100, y: 100, width: 824, height: 824))

    // Tile with Apple's standard soft drop shadow.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: NSColor(white: 0, alpha: 0.3).cgColor)
    context.addPath(tile)
    context.setFillColor(Palette.tileBottom.cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tile)
    context.clip()
    context.drawLinearGradient(linearGradient(Palette.tileTop, Palette.tileBottom),
                               start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    context.restoreGState()

    context.addPath(tile)
    context.setStrokeColor(Palette.tileEdge.cgColor)
    context.setLineWidth(2)
    context.strokePath()

    drawToggle(in: context)
    context.restoreGState()
}

/// A switch in the "on" position. Its knob carries a branch: switching Git identity.
func drawToggle(in context: CGContext) {
    let track = CGRect(x: 192, y: 352, width: 640, height: 320)
    let trackPath = CGPath(roundedRect: track, cornerWidth: 160, cornerHeight: 160, transform: nil)

    // Track.
    context.saveGState()
    context.addPath(trackPath)
    context.clip()
    context.drawLinearGradient(linearGradient(Palette.trackTop, Palette.trackBottom),
                               start: CGPoint(x: 512, y: track.maxY), end: CGPoint(x: 512, y: track.minY), options: [])
    // Inner shadow along the top edge for a recessed look.
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: NSColor(white: 0, alpha: 0.28).cgColor)
    context.addRect(track.insetBy(dx: -60, dy: -60))
    context.addPath(trackPath)
    context.setFillColor(NSColor.black.cgColor)
    context.drawPath(using: .eoFill)
    context.restoreGState()

    // Knob.
    let knob = CGRect(x: track.maxX - 300, y: track.minY + 20, width: 280, height: 280)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: NSColor(white: 0, alpha: 0.32).cgColor)
    context.setFillColor(Palette.knobBottom.cgColor)
    context.fillEllipse(in: knob)
    context.restoreGState()
    context.saveGState()
    context.addEllipse(in: knob)
    context.clip()
    context.drawLinearGradient(linearGradient(Palette.knobTop, Palette.knobBottom),
                               start: CGPoint(x: knob.midX, y: knob.maxY), end: CGPoint(x: knob.midX, y: knob.minY), options: [])
    context.restoreGState()

    drawBranch(in: context, center: CGPoint(x: knob.midX, y: knob.midY), scale: 1.3)
}

/// A minimal branch glyph: trunk, fork and three commits.
func drawBranch(in context: CGContext, center: CGPoint, scale: CGFloat) {
    let x0 = center.x - 30 * scale
    let top = CGPoint(x: x0, y: center.y + 62 * scale)
    let bottom = CGPoint(x: x0, y: center.y - 62 * scale)
    let tip = CGPoint(x: center.x + 44 * scale, y: center.y + 40 * scale)
    let radius = 17 * scale

    let path = CGMutablePath()
    path.move(to: top)
    path.addLine(to: bottom)
    path.move(to: CGPoint(x: x0, y: center.y - 30 * scale))
    path.addCurve(to: CGPoint(x: tip.x, y: tip.y - radius),
                  control1: CGPoint(x: x0, y: center.y + 10 * scale),
                  control2: CGPoint(x: tip.x, y: center.y - 10 * scale))
    context.addPath(path)
    context.setStrokeColor(Palette.glyph.cgColor)
    context.setLineWidth(13 * scale)
    context.setLineCap(.round)
    context.strokePath()

    context.setFillColor(Palette.glyph.cgColor)
    for point in [top, bottom, tip] {
        context.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }
}

// MARK: - Rendering helpers

func renderPNG(width: Int, height: Int, to url: URL, draw: (CGContext) -> Void) throws {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    draw(context)

    let representation = NSBitmapImageRep(cgImage: context.makeImage()!)
    representation.size = NSSize(width: width, height: height)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try representation.representation(using: .png, properties: [:])!.write(to: url)
    print("✓ \(url.path)")
}

/// A 1280×640 image for the GitHub social preview and the README header.
func drawSocialPreview(in context: CGContext) {
    let size = CGSize(width: 1280, height: 640)
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [NSColor(white: 0.97, alpha: 1).cgColor,
                 NSColor(white: 0.90, alpha: 1).cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: .zero, options: [])

    context.saveGState()
    context.translateBy(x: 90, y: 150)
    drawIcon(in: context, size: 340)
    context.restoreGState()

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let title: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 92, weight: .bold),
        .foregroundColor: NSColor(white: 0.11, alpha: 1),
    ]
    let subtitle: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 34, weight: .medium),
        .foregroundColor: NSColor(white: 0.40, alpha: 1),
    ]
    let tagline: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 24, weight: .regular),
        .foregroundColor: Palette.trackBottom,
    ]
    NSAttributedString(string: "SwitchMyGit", attributes: title).draw(at: CGPoint(x: 480, y: 340))
    NSAttributedString(string: "The right Git identity in every repository.", attributes: subtitle).draw(at: CGPoint(x: 484, y: 280))
    NSAttributedString(string: "~/Code/work → work@company.com", attributes: tagline).draw(at: CGPoint(x: 486, y: 214))
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - Main

let root = URL(filePath: FileManager.default.currentDirectoryPath)
let iconSet = root.appending(path: "MacGitSwitcher/Assets.xcassets/AppIcon.appiconset")

struct IconSlot { let points: Int; let scale: Int }
let slots = [16, 32, 128, 256, 512].flatMap { [IconSlot(points: $0, scale: 1), IconSlot(points: $0, scale: 2)] }

var images: [[String: String]] = []
for slot in slots {
    let pixels = slot.points * slot.scale
    let name = "icon_\(slot.points)x\(slot.points)\(slot.scale == 2 ? "@2x" : "").png"
    try renderPNG(width: pixels, height: pixels, to: iconSet.appending(path: name)) { drawIcon(in: $0, size: CGFloat(pixels)) }
    images.append(["filename": name, "idiom": "mac", "scale": "\(slot.scale)x", "size": "\(slot.points)x\(slot.points)"])
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: iconSet.appending(path: "Contents.json"))

try renderPNG(width: 1024, height: 1024, to: root.appending(path: "docs/assets/logo.png")) { drawIcon(in: $0, size: 1024) }
try renderPNG(width: 1280, height: 640, to: root.appending(path: "docs/assets/social-preview.png"), draw: drawSocialPreview)
