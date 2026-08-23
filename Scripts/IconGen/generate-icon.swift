// Renders the ExtraDock app icon at 1024x1024 and writes it as PNG.
// Usage: swift Scripts/IconGen/generate-icon.swift <output-path.png>
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

// Background squircle: deep indigo -> near-black, top to bottom.
let bgPath = NSBezierPath(roundedRect: fullRect, xRadius: cornerRadius, yRadius: cornerRadius)
bgPath.addClip()
let bgGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.17, green: 0.15, blue: 0.32, alpha: 1.0),
    NSColor(calibratedRed: 0.06, green: 0.05, blue: 0.11, alpha: 1.0)
])!
bgGradient.draw(in: fullRect, angle: -90)

// Indigo glow pooling up from where the extra dock lives.
let glow = NSGradient(colors: [
    NSColor(calibratedRed: 0.42, green: 0.40, blue: 0.95, alpha: 0.34),
    NSColor(calibratedRed: 0.42, green: 0.40, blue: 0.95, alpha: 0.0)
])!
glow.draw(in: fullRect, relativeCenterPosition: NSPoint(x: 0.0, y: 0.05))

// Faint top highlight for a glassy edge.
let topHighlight = NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 0.10),
    NSColor(calibratedWhite: 1.0, alpha: 0.0)
])!
topHighlight.draw(in: NSRect(x: 0, y: canvasSize * 0.55, width: canvasSize, height: canvasSize * 0.45), angle: -90)

// --- The real Dock: a dim translucent pill low in the frame. ---
let dockRect = NSRect(x: 202, y: 190, width: 620, height: 140)
let dockPath = NSBezierPath(roundedRect: dockRect, xRadius: 70, yRadius: 70)
NSColor(calibratedWhite: 1.0, alpha: 0.08).setFill()
dockPath.fill()
NSColor(calibratedWhite: 1.0, alpha: 0.14).setStroke()
dockPath.lineWidth = 3
dockPath.stroke()

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
    let path = roundedSquare(x: cx - dockIconSize / 2, y: dockIconY, size: dockIconSize, radius: 24)
    dockColors[i].setFill()
    path.fill()
}

// Upward chevron: the extra dock rises out of the real one.
let chevron = NSBezierPath()
chevron.move(to: NSPoint(x: 512 - 34, y: 372))
chevron.line(to: NSPoint(x: 512, y: 406))
chevron.line(to: NSPoint(x: 512 + 34, y: 372))
chevron.lineWidth = 18
chevron.lineCapStyle = .round
chevron.lineJoinStyle = .round
NSColor(calibratedRed: 0.62, green: 0.60, blue: 0.98, alpha: 0.75).setStroke()
chevron.stroke()

// --- The extra Dock: a brighter glass pill floating above, with its own icons. ---
let extraRect = NSRect(x: 322, y: 440, width: 380, height: 150)

NSGraphicsContext.saveGraphicsState()
let dropShadow = NSShadow()
dropShadow.shadowColor = NSColor(calibratedRed: 0.20, green: 0.16, blue: 0.55, alpha: 0.60)
dropShadow.shadowOffset = NSSize(width: 0, height: -14)
dropShadow.shadowBlurRadius = 36
dropShadow.set()

let extraPath = NSBezierPath(roundedRect: extraRect, xRadius: 75, yRadius: 75)
NSColor(calibratedRed: 0.30, green: 0.28, blue: 0.52, alpha: 0.55).setFill()
extraPath.fill()
NSGraphicsContext.restoreGraphicsState()

// Glassy fill on the extra dock (clipped to its rounded shape).
NSGraphicsContext.saveGraphicsState()
extraPath.addClip()
let extraGlass = NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 0.26),
    NSColor(calibratedWhite: 1.0, alpha: 0.10)
])!
extraGlass.draw(in: extraRect, angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Bright rim on the extra dock.
NSColor(calibratedWhite: 1.0, alpha: 0.42).setStroke()
extraPath.lineWidth = 3
extraPath.stroke()

// The bright accent tile in the extra dock, flanked by two faint slots.
let slotY = extraRect.midY - 96 / 2
NSColor(calibratedWhite: 1.0, alpha: 0.16).setFill()
roundedSquare(x: 512 - 150 - 46, y: slotY + 6, size: 84, radius: 22).fill()
roundedSquare(x: 512 + 150 - 38, y: slotY + 6, size: 84, radius: 22).fill()

let accentSize: CGFloat = 112
let accentX: CGFloat = 512 - accentSize / 2
let accentY: CGFloat = extraRect.midY - accentSize / 2
let accentPath = roundedSquare(x: accentX, y: accentY, size: accentSize, radius: 30)
let accentGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.98, green: 0.98, blue: 1.0, alpha: 1.0),
    NSColor(calibratedRed: 0.86, green: 0.87, blue: 0.98, alpha: 1.0)
])!
accentGradient.draw(in: accentPath, angle: -90)

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
