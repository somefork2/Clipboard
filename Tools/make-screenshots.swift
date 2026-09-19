#!/usr/bin/env swift
// Composes App Store screenshots from the panes rendered by the app itself.
//
// Nothing here invents UI: every pixel of the app comes from a PNG the app
// produced of its own views. This only places those images on a background and
// writes the caption over them, at the 2880×1800 the Mac App Store asks for.

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: make-screenshots <input dir> <output dir>\n".utf8))
    exit(2)
}
let input = URL(fileURLWithPath: arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let canvas = CGSize(width: 2880, height: 1800)

func load(_ name: String) -> NSImage? {
    NSImage(contentsOf: input.appendingPathComponent(name + ".png"))
}

enum Mood {
    case light, dark

    var background: [NSColor] {
        switch self {
        case .light: return [NSColor(srgbRed: 0.94, green: 0.95, blue: 0.98, alpha: 1),
                             NSColor(srgbRed: 0.87, green: 0.90, blue: 0.97, alpha: 1)]
        case .dark: return [NSColor(srgbRed: 0.09, green: 0.10, blue: 0.13, alpha: 1),
                            NSColor(srgbRed: 0.05, green: 0.06, blue: 0.09, alpha: 1)]
        }
    }

    var title: NSColor { self == .light ? NSColor(white: 0.10, alpha: 1) : NSColor(white: 0.97, alpha: 1) }
    var subtitle: NSColor { self == .light ? NSColor(white: 0.32, alpha: 1) : NSColor(white: 0.70, alpha: 1) }
    var chrome: NSColor { self == .light ? NSColor(white: 0.90, alpha: 1) : NSColor(white: 0.20, alpha: 1) }
    var chromeLine: NSColor { self == .light ? NSColor(white: 0.78, alpha: 1) : NSColor(white: 0.30, alpha: 1) }
}

/// Draws an image inside a rounded rectangle with a soft shadow.
func drawPanel(_ image: NSImage, in rect: NSRect, radius: CGFloat, shadow: Bool = true) {
    NSGraphicsContext.saveGraphicsState()
    if shadow {
        let drop = NSShadow()
        drop.shadowColor = NSColor.black.withAlphaComponent(0.34)
        drop.shadowBlurRadius = 56
        drop.shadowOffset = NSSize(width: 0, height: -18)
        drop.set()
    }
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

/// A macOS window frame with a title bar, holding the sidebar and the list.
func drawWindow(sidebar: NSImage, list: NSImage, in rect: NSRect, mood: Mood) {
    let radius: CGFloat = 20
    NSGraphicsContext.saveGraphicsState()
    let drop = NSShadow()
    drop.shadowColor = NSColor.black.withAlphaComponent(0.36)
    drop.shadowBlurRadius = 60
    drop.shadowOffset = NSSize(width: 0, height: -20)
    drop.set()
    let outline = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    mood.chrome.setFill()
    outline.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    outline.addClip()

    let barHeight: CGFloat = 56
    let barRect = NSRect(x: rect.minX, y: rect.maxY - barHeight, width: rect.width, height: barHeight)
    mood.chrome.setFill()
    barRect.fill()
    mood.chromeLine.setStroke()
    let separator = NSBezierPath()
    separator.move(to: NSPoint(x: rect.minX, y: barRect.minY))
    separator.line(to: NSPoint(x: rect.maxX, y: barRect.minY))
    separator.lineWidth = 1
    separator.stroke()

    for (index, colour) in [NSColor(srgbRed: 1.0, green: 0.37, blue: 0.34, alpha: 1),
                            NSColor(srgbRed: 1.0, green: 0.74, blue: 0.19, alpha: 1),
                            NSColor(srgbRed: 0.16, green: 0.79, blue: 0.25, alpha: 1)].enumerated() {
        let dot = NSRect(x: rect.minX + 24 + CGFloat(index) * 28, y: barRect.midY - 8, width: 16, height: 16)
        colour.setFill()
        NSBezierPath(ovalIn: dot).fill()
    }

    let title = "CopyWell"
    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
        .foregroundColor: mood.title.withAlphaComponent(0.75),
    ]
    let titleSize = title.size(withAttributes: titleAttributes)
    title.draw(at: NSPoint(x: rect.midX - titleSize.width / 2, y: barRect.midY - titleSize.height / 2),
               withAttributes: titleAttributes)

    let bodyRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - barHeight)
    let sidebarWidth = bodyRect.width * 0.197
    sidebar.draw(in: NSRect(x: bodyRect.minX, y: bodyRect.minY, width: sidebarWidth, height: bodyRect.height),
                 from: .zero, operation: .sourceOver, fraction: 1)
    list.draw(in: NSRect(x: bodyRect.minX + sidebarWidth, y: bodyRect.minY,
                         width: bodyRect.width - sidebarWidth, height: bodyRect.height),
              from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func draw(headline: String, subhead: String, mood: Mood, body: (NSRect) -> Void, to name: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = canvas
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let colours = mood.background
    let gradient = NSGradient(starting: colours[0], ending: colours[1])!
    gradient.draw(in: NSRect(origin: .zero, size: canvas), angle: -90)

    let headlineAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 92, weight: .bold),
        .foregroundColor: mood.title,
        .kern: -1.6,
    ]
    let subheadAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 44, weight: .regular),
        .foregroundColor: mood.subtitle,
    ]
    let headlineSize = headline.size(withAttributes: headlineAttributes)
    headline.draw(at: NSPoint(x: canvas.width / 2 - headlineSize.width / 2, y: canvas.height - 214),
                  withAttributes: headlineAttributes)
    let subheadSize = subhead.size(withAttributes: subheadAttributes)
    subhead.draw(at: NSPoint(x: canvas.width / 2 - subheadSize.width / 2, y: canvas.height - 292),
                 withAttributes: subheadAttributes)

    body(NSRect(x: 0, y: 0, width: canvas.width, height: canvas.height - 340))

    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: output.appendingPathComponent(name))
    print("  \(name) \(rep.pixelsWide)×\(rep.pixelsHigh)")
}

/// Centres an image inside `area`, scaled to a target height.
func centred(_ image: NSImage, in area: NSRect, height: CGFloat, lift: CGFloat = 0) -> NSRect {
    let aspect = image.size.width / image.size.height
    let width = height * aspect
    return NSRect(x: area.midX - width / 2, y: area.midY - height / 2 + lift, width: width, height: height)
}

// MARK: - The five screens

if let sidebar = load("sidebar-light"), let list = load("list-light") {
    draw(headline: "Everything you copy, kept and searchable.",
         subhead: "Text, links, images and code — found in a second, weeks later.",
         mood: .light,
         body: { area in
            let frame = NSRect(x: 240, y: area.midY - 560, width: canvas.width - 480, height: 1120)
            drawWindow(sidebar: sidebar, list: list, in: frame, mood: .light)
         },
         to: "01-history.png")
}

if let palette = load("palette-dark") {
    draw(headline: "Press ⌥⌘V. Never break your flow.",
         subhead: "The palette opens at your cursor, in any app, and closes the moment you pick.",
         mood: .dark,
         body: { area in
            drawPanel(palette, in: centred(palette, in: area, height: 1180), radius: 22)
         },
         to: "02-palette.png")
}

if let sidebar = load("sidebar-dark"), let list = load("list-dark") {
    draw(headline: "A working day, kept in order.",
         subhead: "Pinboards for what you reuse. Favourites that are never cleared away.",
         mood: .dark,
         body: { area in
            let frame = NSRect(x: 240, y: area.midY - 560, width: canvas.width - 480, height: 1120)
            drawWindow(sidebar: sidebar, list: list, in: frame, mood: .dark)
         },
         to: "03-pinboards.png")
}

if let menubar = load("menubar-light") {
    draw(headline: "Always one click away.",
         subhead: "Recent clips live in the menu bar, and in the right-click menu of every app.",
         mood: .light,
         body: { area in
            drawPanel(menubar, in: centred(menubar, in: area, height: 1120), radius: 22)
         },
         to: "04-menubar.png")
}

print("composed into \(output.path)")
