// Renders the ExtraDock app icon at 1024x1024 and writes it as PNG.
// Usage: swift Scripts/IconGen/generate-icon.swift <output-path.png>
//
// Visual language: Apple "clear glass" (Liquid Glass). Both docks are rendered
// as translucent glass you can see the background through — a specular
// highlight hugs the top edge (light catching the material), a bright rim
// gives edge-lensing, and the floating extra dock casts a soft ambient shadow.
import AppKit

let canvasSize: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
image.lockFocus()

let fullRect = NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
let cornerRadius: CGFloat = canvasSize * 0.223

func roundedSquare(x: CGFloat, y: CGFloat, size: CGFloat, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: size, height: size), xRadius: radius, yRadius: radius)
}

// Renders a rounded rect as a sheet of clear glass, layered bottom-to-top:
//   1. a translucent body (also casts the ambient shadow when floating),
//   2. a vertical body gradient that's brightest near the top (specular),
//   3. a broad soft sheen over the upper half,
//   4. a crisp bright line right on the top edge (light catch),
//   5. a bright rim stroke for edge-lensing.
// `intensity` scales every glass alpha — the extra dock reads brighter and
// closer to the light than the dim real dock beneath it.
func drawGlassPill(_ rect: NSRect, radius: CGFloat, floating: Bool, intensity: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // 1. Translucent body. When floating, this same fill casts the drop shadow
    //    so the shadow's shape matches the glass exactly.
    NSGraphicsContext.saveGraphicsState()
    if floating {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.09, alpha: 0.55)
        shadow.shadowOffset = NSSize(width: 0, height: -16)
        shadow.shadowBlurRadius = 38
        shadow.set()
    }
    NSColor(calibratedWhite: 1.0, alpha: 0.10 * intensity).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Layers 2–4 are clipped to the glass shape.
    NSGraphicsContext.saveGraphicsState()
    path.addClip()

    // 2. Body gradient: brighter at the top, thinning toward the bottom.
    let body = NSGradient(colors: [
        NSColor(calibratedWhite: 1.0, alpha: 0.20 * intensity),
        NSColor(calibratedWhite: 1.0, alpha: 0.05 * intensity),
        NSColor(calibratedWhite: 1.0, alpha: 0.11 * intensity)
    ])!
    body.draw(in: rect, angle: -90)

    // 3. Broad soft sheen across the upper half (angle 90 -> bright at top).
    let sheenRect = NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2)
    let sheen = NSGradient(colors: [
        NSColor(calibratedWhite: 1.0, alpha: 0.0),
        NSColor(calibratedWhite: 1.0, alpha: 0.30 * intensity)
    ])!
    sheen.draw(in: sheenRect, angle: 90)

    // 4. Crisp specular line right on the top edge.
    let edgeRect = NSRect(x: rect.minX, y: rect.maxY - 12, width: rect.width, height: 12)
    let edge = NSGradient(colors: [
        NSColor(calibratedWhite: 1.0, alpha: 0.0),
        NSColor(calibratedWhite: 1.0, alpha: 0.65 * intensity)
    ])!
    edge.draw(in: edgeRect, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    // 5. Bright rim for edge-lensing.
    NSColor(calibratedWhite: 1.0, alpha: 0.42 * intensity).setStroke()
    path.lineWidth = 2.5
    path.stroke()
}

// A colored app tile with a glassy top sheen, as seen through/on the glass.
func drawAppTile(centerX cx: CGFloat, y: CGFloat, size: CGFloat, color: NSColor) {
    let path = roundedSquare(x: cx - size / 2, y: y, size: size, radius: size * 0.26)
    color.setFill()
    path.fill()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    let sheen = NSGradient(colors: [
        NSColor(calibratedWhite: 1.0, alpha: 0.0),
        NSColor(calibratedWhite: 1.0, alpha: 0.34)
    ])!
    sheen.draw(in: NSRect(x: cx - size / 2, y: y + size / 2, width: size, height: size / 2), angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedWhite: 1.0, alpha: 0.22).setStroke()
    path.lineWidth = 1.5
    path.stroke()
}

// --- Background: deep indigo with a periwinkle bloom for the glass to refract. ---
let bgPath = NSBezierPath(roundedRect: fullRect, xRadius: cornerRadius, yRadius: cornerRadius)
bgPath.addClip()
let bgGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.21, green: 0.20, blue: 0.42, alpha: 1.0),
    NSColor(calibratedRed: 0.08, green: 0.07, blue: 0.17, alpha: 1.0)
])!
bgGradient.draw(in: fullRect, angle: -90)

// Soft light bloom behind the extra dock, so the clear glass has color to bend.
let bloom = NSGradient(colors: [
    NSColor(calibratedRed: 0.48, green: 0.46, blue: 0.98, alpha: 0.55),
    NSColor(calibratedRed: 0.48, green: 0.46, blue: 0.98, alpha: 0.0)
])!
bloom.draw(in: fullRect, relativeCenterPosition: NSPoint(x: 0.0, y: 0.12))

// --- The real Dock: a dim sheet of clear glass low in the frame. ---
let dockRect = NSRect(x: 202, y: 190, width: 620, height: 140)
drawGlassPill(dockRect, radius: 70, floating: false, intensity: 0.85)

// Three ordinary app icons resting on the real Dock.
let dockIconSize: CGFloat = 92
let dockIconY: CGFloat = dockRect.midY - dockIconSize / 2
let dockColors: [NSColor] = [
    NSColor(calibratedRed: 0.98, green: 0.44, blue: 0.44, alpha: 1.0),
    NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.32, alpha: 1.0),
    NSColor(calibratedRed: 0.24, green: 0.82, blue: 0.56, alpha: 1.0)
]
let dockCenters: [CGFloat] = [340, 512, 684]
for (i, cx) in dockCenters.enumerated() {
    drawAppTile(centerX: cx, y: dockIconY, size: dockIconSize, color: dockColors[i])
}

// Upward chevron: the extra dock rises out of the real one.
let chevron = NSBezierPath()
chevron.move(to: NSPoint(x: 512 - 34, y: 372))
chevron.line(to: NSPoint(x: 512, y: 406))
chevron.line(to: NSPoint(x: 512 + 34, y: 372))
chevron.lineWidth = 18
chevron.lineCapStyle = .round
chevron.lineJoinStyle = .round
NSColor(calibratedRed: 0.72, green: 0.71, blue: 1.0, alpha: 0.85).setStroke()
chevron.stroke()

// --- The extra Dock: a brighter sheet of clear glass floating above. ---
let extraRect = NSRect(x: 322, y: 440, width: 380, height: 150)
drawGlassPill(extraRect, radius: 75, floating: true, intensity: 1.25)

// Two faint empty slots flanking the bright accent tile.
let slotSize: CGFloat = 84
let slotY = extraRect.midY - slotSize / 2
for cx in [CGFloat(512 - 132), CGFloat(512 + 132)] {
    let slot = roundedSquare(x: cx - slotSize / 2, y: slotY, size: slotSize, radius: slotSize * 0.26)
    NSColor(calibratedWhite: 1.0, alpha: 0.14).setFill()
    slot.fill()
    NSColor(calibratedWhite: 1.0, alpha: 0.20).setStroke()
    slot.lineWidth = 1.5
    slot.stroke()
}

// The bright accent tile in the extra dock — frosted-white glass.
let accentSize: CGFloat = 112
let accentX: CGFloat = 512 - accentSize / 2
let accentY: CGFloat = extraRect.midY - accentSize / 2
let accentPath = roundedSquare(x: accentX, y: accentY, size: accentSize, radius: accentSize * 0.27)

NSGraphicsContext.saveGraphicsState()
let accentShadow = NSShadow()
accentShadow.shadowColor = NSColor(calibratedRed: 0.05, green: 0.04, blue: 0.16, alpha: 0.45)
accentShadow.shadowOffset = NSSize(width: 0, height: -6)
accentShadow.shadowBlurRadius = 16
accentShadow.set()
let accentGradient = NSGradient(colors: [
    NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.98),
    NSColor(calibratedRed: 0.86, green: 0.87, blue: 0.98, alpha: 0.94)
])!
accentGradient.draw(in: accentPath, angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Glassy top sheen on the accent tile.
NSGraphicsContext.saveGraphicsState()
accentPath.addClip()
let accentSheen = NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 0.0),
    NSColor(calibratedWhite: 1.0, alpha: 0.55)
])!
accentSheen.draw(in: NSRect(x: accentX, y: extraRect.midY, width: accentSize, height: accentSize / 2), angle: 90)
NSGraphicsContext.restoreGraphicsState()

// Plus glyph inside the accent tile.
let plus = NSBezierPath()
let plusCenter = NSPoint(x: 512, y: extraRect.midY)
let plusArm: CGFloat = 30
plus.move(to: NSPoint(x: plusCenter.x - plusArm, y: plusCenter.y))
plus.line(to: NSPoint(x: plusCenter.x + plusArm, y: plusCenter.y))
plus.move(to: NSPoint(x: plusCenter.x, y: plusCenter.y - plusArm))
plus.line(to: NSPoint(x: plusCenter.x, y: plusCenter.y + plusArm))
plus.lineWidth = 18
plus.lineCapStyle = .round
NSColor(calibratedRed: 0.34, green: 0.30, blue: 0.86, alpha: 1.0).setStroke()
plus.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render PNG")
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
