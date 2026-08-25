#!/usr/bin/env swift
//
//  make-app-icon.swift — draw the Lab flask badge onto the base icon and write
//  every size the asset catalog needs.
//
//  Usage: Scripts/make-app-icon.swift
//
//  Reads Design/AppIcon-base-1024.png, the socket artwork without the badge,
//  and writes MiniproUIIcon.appiconset and VisualMiniproIconImage.imageset.
//  The badge is a drawn path, not an SF Symbol - Apple does not allow those in
//  app icons.
//

import AppKit
import Foundation

let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let assets = projectRoot.appendingPathComponent("MiniproUI/Assets.xcassets")
let basePath = projectRoot.appendingPathComponent("Design/AppIcon-base-1024.png")

guard let base = NSImage(contentsOf: basePath) else {
    FileHandle.standardError.write(Data("error: no base icon at \(basePath.path)\n".utf8))
    exit(1)
}

/// An Erlenmeyer flask: narrow neck flaring out to a flat base.
func flaskPath(in rect: CGRect) -> NSBezierPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + (1 - y) * rect.height)
    }
    let path = NSBezierPath()
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    path.move(to: p(0.40, 0.14))
    path.line(to: p(0.60, 0.14))
    path.line(to: p(0.60, 0.42))
    path.line(to: p(0.84, 0.82))
    path.curve(to: p(0.74, 0.90), controlPoint1: p(0.86, 0.88), controlPoint2: p(0.82, 0.90))
    path.line(to: p(0.26, 0.90))
    path.curve(to: p(0.16, 0.82), controlPoint1: p(0.18, 0.90), controlPoint2: p(0.14, 0.88))
    path.line(to: p(0.40, 0.42))
    path.close()
    return path
}

func render(size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    let full = CGRect(x: 0, y: 0, width: size, height: size)

    base.draw(in: full)

    let diameter = size * 0.38
    let inset = size * 0.045
    let badge = CGRect(
        x: full.maxX - diameter - inset, y: full.minY + inset,
        width: diameter, height: diameter)

    // White ring, drawn as a shadowed disc the gradient then sits inside of.
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.03,
        color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: badge).fill()
    context.restoreGState()

    let ring = size * 0.022
    let inner = badge.insetBy(dx: ring, dy: ring)
    // The blue of the socket lever in the base artwork.
    NSGradient(
        starting: NSColor(srgbRed: 0.24, green: 0.65, blue: 0.94, alpha: 1),
        ending: NSColor(srgbRed: 0.07, green: 0.36, blue: 0.80, alpha: 1)
    )!.draw(in: NSBezierPath(ovalIn: inner), angle: -90)

    NSColor.white.setFill()
    flaskPath(in: inner.insetBy(dx: inner.width * 0.21, dy: inner.height * 0.17)).fill()

    return rep.representation(using: .png, properties: [:])!
}

// Sizes are rendered once and written under every name the catalogs use.
let appIconNames: [CGFloat: [String]] = [
    16: ["icon_16.png"],
    32: ["icon_32.png", "icon_32 1.png"],
    64: ["icon_64.png"],
    128: ["icon_128.png"],
    256: ["icon_256.png", "icon_256 1.png"],
    512: ["icon_512.png", "icon_512 1.png"],
    1024: ["icon_1024.png"],
]
let imageSetNames: [CGFloat: [String]] = [
    32: ["icon_32.png"],
    64: ["icon_64.png"],
    256: ["icon_256.png"],
]

var written = 0
for (size, names) in appIconNames.sorted(by: { $0.key < $1.key }) {
    let png = render(size: size)
    for name in names {
        let url = assets.appendingPathComponent("MiniproUIIcon.appiconset/\(name)")
        try png.write(to: url)
        written += 1
    }
    for name in imageSetNames[size] ?? [] {
        let url = assets.appendingPathComponent("VisualMiniproIconImage.imageset/\(name)")
        try png.write(to: url)
        written += 1
    }
}
print("wrote \(written) icon files")
