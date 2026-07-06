#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputDirectory = rootURL.appendingPathComponent("Assets/AppIcon", isDirectory: true)
let iconsetURL = rootURL.appendingPathComponent(".build/icon-generation/SmartKeyboard.iconset", isDirectory: true)
let outputURL = outputDirectory.appendingPathComponent("SmartKeyboard.icns")

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try FileManager.default.removeItemIfExists(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconEntries: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for entry in iconEntries {
    let bitmap = drawIcon(size: CGFloat(entry.pixels))
    try writePNG(bitmap, to: iconsetURL.appendingPathComponent(entry.name))
}

try FileManager.default.removeItemIfExists(at: outputURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c",
    "icns",
    iconsetURL.path,
    "-o",
    outputURL.path
]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw IconGenerationError.iconutilFailed(process.terminationStatus)
}

print("Generated \(outputURL.path)")

private func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    guard let context = NSGraphicsContext.current?.cgContext else {
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))

    func scaled(_ value: CGFloat) -> CGFloat {
        value * size / 1024
    }

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    let outer = canvas.insetBy(dx: scaled(64), dy: scaled(64))
    let outerPath = CGPath(
        roundedRect: outer,
        cornerWidth: scaled(216),
        cornerHeight: scaled(216),
        transform: nil
    )

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -scaled(18)),
        blur: scaled(28),
        color: NSColor.black.withAlphaComponent(0.22).cgColor
    )
    context.addPath(outerPath)
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(outerPath)
    context.clip()
    let colors = [
        NSColor(red: 0.12, green: 0.44, blue: 0.92, alpha: 1.0).cgColor,
        NSColor(red: 0.07, green: 0.76, blue: 0.72, alpha: 1.0).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: outer.minX, y: outer.maxY),
        end: CGPoint(x: outer.maxX, y: outer.minY),
        options: []
    )
    context.restoreGState()

    context.saveGState()
    context.addPath(outerPath)
    context.clip()
    let highlight = CGPath(
        roundedRect: CGRect(x: scaled(116), y: scaled(760), width: scaled(792), height: scaled(152)),
        cornerWidth: scaled(76),
        cornerHeight: scaled(76),
        transform: nil
    )
    context.addPath(highlight)
    context.setFillColor(NSColor.white.withAlphaComponent(0.14).cgColor)
    context.fillPath()
    context.restoreGState()

    let keyboard = CGRect(x: scaled(210), y: scaled(336), width: scaled(604), height: scaled(352))
    let keyboardPath = CGPath(
        roundedRect: keyboard,
        cornerWidth: scaled(88),
        cornerHeight: scaled(88),
        transform: nil
    )
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -scaled(18)),
        blur: scaled(24),
        color: NSColor(red: 0.03, green: 0.20, blue: 0.27, alpha: 0.24).cgColor
    )
    context.addPath(keyboardPath)
    context.setFillColor(NSColor.white.cgColor)
    context.fillPath()
    context.restoreGState()

    let keyColorA = NSColor(red: 0.86, green: 0.92, blue: 1.0, alpha: 1.0).cgColor
    let keyColorB = NSColor(red: 0.80, green: 0.98, blue: 0.95, alpha: 1.0).cgColor
    drawKey(CGRect(x: 270, y: 560, width: 92, height: 62), color: keyColorA, scaled: scaled, context: context)
    drawKey(CGRect(x: 396, y: 560, width: 92, height: 62), color: keyColorA, scaled: scaled, context: context)
    drawKey(CGRect(x: 522, y: 560, width: 92, height: 62), color: keyColorB, scaled: scaled, context: context)
    drawKey(CGRect(x: 648, y: 560, width: 106, height: 62), color: keyColorB, scaled: scaled, context: context)
    drawKey(CGRect(x: 282, y: 402, width: 460, height: 62), radius: 28, color: NSColor(red: 0.88, green: 0.96, blue: 1.0, alpha: 1.0).cgColor, scaled: scaled, context: context)

    drawArrow(
        from: CGPoint(x: scaled(360), y: scaled(526)),
        to: CGPoint(x: scaled(610), y: scaled(526)),
        color: NSColor(red: 0.12, green: 0.44, blue: 0.92, alpha: 1.0).cgColor,
        lineWidth: scaled(36),
        headLength: scaled(52),
        context: context
    )
    drawArrow(
        from: CGPoint(x: scaled(664), y: scaled(478)),
        to: CGPoint(x: scaled(414), y: scaled(478)),
        color: NSColor(red: 0.06, green: 0.46, blue: 0.43, alpha: 1.0).cgColor,
        lineWidth: scaled(36),
        headLength: scaled(52),
        context: context
    )

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

private func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.pngEncodingFailed(url.path)
    }

    try pngData.write(to: url)
}

private func drawKey(
    _ rect: CGRect,
    radius: CGFloat = 22,
    color: CGColor,
    scaled: (CGFloat) -> CGFloat,
    context: CGContext
) {
    let scaledRect = CGRect(
        x: scaled(rect.minX),
        y: scaled(rect.minY),
        width: scaled(rect.width),
        height: scaled(rect.height)
    )
    context.addPath(
        CGPath(
            roundedRect: scaledRect,
            cornerWidth: scaled(radius),
            cornerHeight: scaled(radius),
            transform: nil
        )
    )
    context.setFillColor(color)
    context.fillPath()
}

private func drawArrow(
    from: CGPoint,
    to: CGPoint,
    color: CGColor,
    lineWidth: CGFloat,
    headLength: CGFloat,
    context: CGContext
) {
    let angle = atan2(to.y - from.y, to.x - from.x)
    let shaftEnd = CGPoint(
        x: to.x - cos(angle) * headLength * 0.68,
        y: to.y - sin(angle) * headLength * 0.68
    )

    context.saveGState()
    context.setStrokeColor(color)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.move(to: from)
    context.addLine(to: shaftEnd)
    context.strokePath()

    let wingAngle = CGFloat.pi * 0.82
    let left = CGPoint(
        x: to.x + cos(angle + wingAngle) * headLength,
        y: to.y + sin(angle + wingAngle) * headLength
    )
    let right = CGPoint(
        x: to.x + cos(angle - wingAngle) * headLength,
        y: to.y + sin(angle - wingAngle) * headLength
    )

    context.move(to: to)
    context.addLine(to: left)
    context.addLine(to: right)
    context.closePath()
    context.setFillColor(color)
    context.fillPath()
    context.restoreGState()
}

private enum IconGenerationError: Error {
    case iconutilFailed(Int32)
    case pngEncodingFailed(String)
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        guard fileExists(atPath: url.path) else {
            return
        }

        try removeItem(at: url)
    }
}
