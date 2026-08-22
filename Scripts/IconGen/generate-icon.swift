// Renders the ExtraDock app icon at 1024x1024 and writes it as PNG.
// Usage: swift Scripts/IconGen/generate-icon.swift <output-path.png>
import AppKit

let canvasSize: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
image.lockFocus()

let fullRect = NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
let cornerRadius: CGFloat = canvasSize * 0.223

// Background squircle with a top-to-bottom indigo -> violet gradient.
let bgPath = NSBezierPath(roundedRect: fullRect, xRadius: cornerRadius, yRadius: cornerRadius)
bgPath.addClip()
let bgGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.45, green: 0.47, blue: 0.98, alpha: 1.0),
    NSColor(calibratedRed: 0.22, green: 0.18, blue: 0.62, alpha: 1.0)
])!
bgGradient.draw(in: fullRect, angle: -90)

// Soft top highlight for depth.
let highlight = NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 0.16),
    NSColor(calibratedWhite: 1.0, alpha: 0.0)
])!
highlight.draw(in: fullRect, angle: -90)

// The dock pill (translucent bar).
let pillRect = NSRect(x: 192, y: 230, width: 640, height: 130)
let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 65, yRadius: 65)
NSColor(calibratedWhite: 1.0, alpha: 0.20).setFill()
pillPath.fill()
NSColor(calibratedWhite: 1.0, alpha: 0.38).setStroke()
pillPath.lineWidth = 4
pillPath.stroke()

// Three regular app icons resting on the pill.
func roundedSquare(x: CGFloat, y: CGFloat, size: CGFloat, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: size, height: size), xRadius: radius, yRadius: radius)
}

let regularIconSize: CGFloat = 108
let regularIconY: CGFloat = pillRect.midY - regularIconSize / 2
let regularColors: [NSColor] = [
    NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.42, alpha: 1.0),
    NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.35, alpha: 1.0),
    NSColor(calibratedRed: 0.02, green: 0.84, blue: 0.63, alpha: 1.0)
]
let regularXs: [CGFloat] = [297, 457, 617]
for (i, x) in regularXs.enumerated() {
    let path = roundedSquare(x: x, y: regularIconY, size: regularIconSize, radius: 26)
    regularColors[i].setFill()
    path.fill()
}

// Connecting chevron hinting the extra icon rises out of the dock.
let chevron = NSBezierPath()
chevron.move(to: NSPoint(x: 512 - 30, y: 388))
chevron.line(to: NSPoint(x: 512, y: 418))
chevron.line(to: NSPoint(x: 512 + 30, y: 388))
chevron.lineWidth = 16
chevron.lineCapStyle = .round
chevron.lineJoinStyle = .round
NSColor(calibratedWhite: 1.0, alpha: 0.55).setStroke()
chevron.stroke()

// The extra icon, elevated above the pill with a soft shadow and glow ring.
let extraSize: CGFloat = 146
let extraX: CGFloat = 512 - extraSize / 2
let extraY: CGFloat = 430

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.35)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 28
shadow.set()

let glowPath = roundedSquare(x: extraX - 10, y: extraY - 10, size: extraSize + 20, radius: 44)
NSColor(calibratedWhite: 1.0, alpha: 0.28).setFill()
glowPath.fill()
NSGraphicsContext.restoreGraphicsState()

let extraPath = roundedSquare(x: extraX, y: extraY, size: extraSize, radius: 36)
NSColor.white.setFill()
extraPath.fill()

// A small plus glyph inside the extra icon.
let plus = NSBezierPath()
let plusCenter = NSPoint(x: extraX + extraSize / 2, y: extraY + extraSize / 2)
let plusArm: CGFloat = 34
plus.move(to: NSPoint(x: plusCenter.x - plusArm, y: plusCenter.y))
plus.line(to: NSPoint(x: plusCenter.x + plusArm, y: plusCenter.y))
plus.move(to: NSPoint(x: plusCenter.x, y: plusCenter.y - plusArm))
plus.line(to: NSPoint(x: plusCenter.x, y: plusCenter.y + plusArm))
plus.lineWidth = 16
plus.lineCapStyle = .round
NSColor(calibratedRed: 0.32, green: 0.28, blue: 0.85, alpha: 1.0).setStroke()
plus.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render PNG")
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
