#!/usr/bin/env swift
// Draws the CopyWell app icon at every size the Mac App Store requires.
// Run: swift Tools/make-icon.swift

import AppKit
import Foundation

let sizes: [(px: Int, name: String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]

let outputDir = URL(fileURLWithPath: "Sources/Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

/// Draws at exact pixel dimensions.
///
/// `NSImage.lockFocus` renders through the current display's scale, so on a
/// Retina Mac every icon came out at twice its declared size. actool then found
/// a 32×32 file where the manifest promised 16×16, produced nothing, and the app
/// shipped with the generic icon — silently, with no diagnostic at all.
func drawIcon(size: CGFloat) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
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
    ) else { return nil }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }
    NSGraphicsContext.current = graphicsContext
    let context = graphicsContext.cgContext
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    let unit = size / 1024

    // Rounded-square background, the macOS icon silhouette.
    let inset = 100 * unit
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let background = NSBezierPath(roundedRect: rect, xRadius: 185 * unit, yRadius: 185 * unit)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.31, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.16, alpha: 1)
    ])
    gradient?.draw(in: background, angle: -90)

    // Stacked cards, suggesting clipboard history.
    let cardWidth = 380 * unit
    let cardHeight = 250 * unit
    let centerX = size / 2
    let offsets: [(dx: CGFloat, dy: CGFloat, alpha: CGFloat)] = [
        (0, 130 * unit, 0.30),
        (0, 45 * unit, 0.60),
        (0, -45 * unit, 1.00)
    ]

    for offset in offsets {
        let cardRect = CGRect(
            x: centerX - cardWidth / 2 + offset.dx,
            y: size / 2 - cardHeight / 2 + offset.dy,
            width: cardWidth,
            height: cardHeight
        )
        let path = NSBezierPath(roundedRect: cardRect, xRadius: 46 * unit, yRadius: 46 * unit)
        NSColor.white.withAlphaComponent(offset.alpha).setFill()
        path.fill()
    }

    // Text lines on the front card.
    let frontRect = CGRect(
        x: centerX - cardWidth / 2,
        y: size / 2 - cardHeight / 2 - 45 * unit,
        width: cardWidth,
        height: cardHeight
    )
    NSColor(calibratedRed: 0.14, green: 0.17, blue: 0.23, alpha: 1).setFill()
    for index in 0..<3 {
        let lineWidth = index == 2 ? cardWidth * 0.42 : cardWidth * 0.66
        let line = CGRect(
            x: frontRect.minX + 58 * unit,
            y: frontRect.maxY - CGFloat(index + 1) * 58 * unit,
            width: lineWidth,
            height: 26 * unit
        )
        NSBezierPath(roundedRect: line, xRadius: 13 * unit, yRadius: 13 * unit).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for entry in sizes {
    guard let rep = drawIcon(size: CGFloat(entry.px)),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try png.write(to: outputDir.appendingPathComponent(entry.name))
    print("wrote \(entry.name) — \(rep.pixelsWide)×\(rep.pixelsHigh)")
}

// Asset catalogue manifest.
let contents: [String: Any] = [
    "images": sizes.enumerated().map { index, entry -> [String: String] in
        let idiom = "mac"
        let scale = entry.name.contains("@2x") ? "2x" : "1x"
        let base = entry.name
            .replacingOccurrences(of: "icon_", with: "")
            .replacingOccurrences(of: "@2x", with: "")
            .replacingOccurrences(of: ".png", with: "")
        let dimension = base.components(separatedBy: "x").first ?? "16"
        _ = index
        return [
            "filename": entry.name,
            "idiom": idiom,
            "scale": scale,
            "size": "\(dimension)x\(dimension)"
        ]
    },
    "info": ["author": "xcode", "version": 1]
]
let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try data.write(to: outputDir.appendingPathComponent("Contents.json"))

let rootContents = try JSONSerialization.data(
    withJSONObject: ["info": ["author": "xcode", "version": 1]],
    options: [.prettyPrinted]
)
try rootContents.write(to: outputDir.deletingLastPathComponent().appendingPathComponent("Contents.json"))
print("icon set written to \(outputDir.path)")
