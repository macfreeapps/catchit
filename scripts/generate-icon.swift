import AppKit
import Foundation

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Could not create the app icon bitmap.\n", stderr)
    exit(1)
}

guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Could not create the app icon drawing context.\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let tile = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 220, yRadius: 220)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.11, green: 0.31, blue: 0.88, alpha: 1),
    NSColor(calibratedRed: 0.25, green: 0.18, blue: 0.66, alpha: 1)
])
if let background {
    background.draw(in: tile, angle: 48)
} else {
    NSColor(calibratedRed: 0.16, green: 0.27, blue: 0.77, alpha: 1).setFill()
    tile.fill()
}

tile.addClip()
NSColor(calibratedRed: 0.33, green: 0.85, blue: 0.96, alpha: 0.16).setFill()
NSBezierPath(ovalIn: NSRect(x: 585, y: 630, width: 560, height: 560)).fill()

let paperRect = NSRect(x: 188, y: 213, width: 520, height: 588)
let paper = NSBezierPath(roundedRect: paperRect, xRadius: 68, yRadius: 68)
let paperShadow = NSShadow()
paperShadow.shadowColor = NSColor(calibratedWhite: 0.04, alpha: 0.3)
paperShadow.shadowBlurRadius = 34
paperShadow.shadowOffset = NSSize(width: 0, height: -18)
NSGraphicsContext.saveGraphicsState()
paperShadow.set()
NSColor(calibratedRed: 0.98, green: 0.99, blue: 1, alpha: 1).setFill()
paper.fill()
NSGraphicsContext.restoreGraphicsState()

let ink = NSColor(calibratedRed: 0.17, green: 0.29, blue: 0.64, alpha: 1)
let softInk = NSColor(calibratedRed: 0.48, green: 0.57, blue: 0.80, alpha: 1)
let rows: [(CGFloat, CGFloat, NSColor)] = [
    (658, 292, ink),
    (554, 235, softInk),
    (450, 180, softInk)
]
for (y, width, color) in rows {
    let mark = NSBezierPath(roundedRect: NSRect(x: 267, y: y, width: width, height: 31), xRadius: 16, yRadius: 16)
    color.setFill()
    mark.fill()
}

let accent = NSColor(calibratedRed: 1, green: 0.43, blue: 0.31, alpha: 1)
accent.setFill()
NSBezierPath(ovalIn: NSRect(x: 267, y: 714, width: 34, height: 34)).fill()

let handle = NSBezierPath()
handle.lineCapStyle = .round
handle.move(to: NSPoint(x: 715, y: 338))
handle.line(to: NSPoint(x: 861, y: 192))
handle.lineWidth = 96
NSColor(calibratedRed: 0.12, green: 0.19, blue: 0.50, alpha: 1).setStroke()
handle.stroke()

let handleInset = NSBezierPath()
handleInset.lineCapStyle = .round
handleInset.move(to: NSPoint(x: 715, y: 338))
handleInset.line(to: NSPoint(x: 861, y: 192))
handleInset.lineWidth = 59
NSColor(calibratedRed: 0.78, green: 0.87, blue: 1, alpha: 1).setStroke()
handleInset.stroke()

let lensCenter = NSPoint(x: 661, y: 446)
let lensRect = NSRect(x: lensCenter.x - 157, y: lensCenter.y - 157, width: 314, height: 314)
let lensShadow = NSShadow()
lensShadow.shadowColor = NSColor(calibratedWhite: 0.04, alpha: 0.28)
lensShadow.shadowBlurRadius = 26
lensShadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.saveGraphicsState()
lensShadow.set()
NSColor(calibratedRed: 0.19, green: 0.75, blue: 0.91, alpha: 1).setFill()
NSBezierPath(ovalIn: lensRect).fill()
NSGraphicsContext.restoreGraphicsState()

let lensRing = NSBezierPath(ovalIn: lensRect.insetBy(dx: 4, dy: 4))
lensRing.lineWidth = 38
NSColor.white.setStroke()
lensRing.stroke()

let lensContent = NSBezierPath()
lensContent.lineCapStyle = .round
lensContent.lineWidth = 17
for (offset, width) in [(34, CGFloat(93)), (0, 70), (-34, 48)] {
    let y = lensCenter.y + CGFloat(offset)
    lensContent.move(to: NSPoint(x: lensCenter.x - width / 2, y: y))
    lensContent.line(to: NSPoint(x: lensCenter.x + width / 2, y: y))
}
NSColor.white.withAlphaComponent(0.96).setStroke()
lensContent.stroke()

let focus = NSBezierPath(ovalIn: NSRect(x: 766, y: 583, width: 56, height: 56))
NSColor.white.setFill()
focus.fill()
let focusDot = NSBezierPath(ovalIn: NSRect(x: 774, y: 591, width: 40, height: 40))
accent.setFill()
focusDot.fill()

graphics.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: swift generate-icon.swift OUTPUT.png\n", stderr)
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
do {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Could not encode the app icon as PNG.\n", stderr)
        exit(1)
    }
    try png.write(to: output)
} catch {
    fputs("Could not write app icon: \(error.localizedDescription)\n", stderr)
    exit(1)
}
