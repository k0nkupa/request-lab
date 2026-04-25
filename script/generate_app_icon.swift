#!/usr/bin/env swift

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let buildURL = rootURL
    .appendingPathComponent(".build", isDirectory: true)
    .appendingPathComponent("icon-generation", isDirectory: true)
let iconsetURL = buildURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let outputURL = resourcesURL.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconSize {
    let points: Int
    let scale: Int

    var pixels: Int { points * scale }
    var filename: String {
        scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@\(scale)x.png"
    }
}

let sizes = [
    IconSize(points: 16, scale: 1),
    IconSize(points: 16, scale: 2),
    IconSize(points: 32, scale: 1),
    IconSize(points: 32, scale: 2),
    IconSize(points: 128, scale: 1),
    IconSize(points: 128, scale: 2),
    IconSize(points: 256, scale: 1),
    IconSize(points: 256, scale: 2),
    IconSize(points: 512, scale: 1),
    IconSize(points: 512, scale: 2)
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawRoundedRect(_ context: CGContext, _ rect: CGRect, radius: CGFloat, fill: CGColor) {
    context.setFillColor(fill)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

func drawParallelogram(_ context: CGContext, points: [CGPoint], fill: CGColor) {
    guard let first = points.first else { return }
    context.beginPath()
    context.move(to: first)
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.closePath()
    context.setFillColor(fill)
    context.fillPath()
}

func makeIcon(pixelSize: Int) throws -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "RequestLabIcon", code: 1)
    }

    let scale = CGFloat(pixelSize) / 1024
    context.scaleBy(x: scale, y: scale)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let background = color(14, 14, 12)
    let foreground = color(239, 230, 208)
    let softHighlight = color(255, 252, 244, 0.08)

    drawRoundedRect(
        context,
        CGRect(x: 64, y: 64, width: 896, height: 896),
        radius: 210,
        fill: background
    )

    drawRoundedRect(
        context,
        CGRect(x: 84, y: 760, width: 856, height: 146),
        radius: 128,
        fill: softHighlight
    )

    drawRoundedRect(context, CGRect(x: 242, y: 238, width: 116, height: 548), radius: 30, fill: foreground)
    drawRoundedRect(context, CGRect(x: 242, y: 668, width: 332, height: 118), radius: 30, fill: foreground)
    drawRoundedRect(context, CGRect(x: 242, y: 456, width: 310, height: 104), radius: 30, fill: foreground)
    drawRoundedRect(context, CGRect(x: 502, y: 552, width: 116, height: 234), radius: 30, fill: foreground)
    drawParallelogram(
        context,
        points: [
            CGPoint(x: 423, y: 456),
            CGPoint(x: 550, y: 456),
            CGPoint(x: 694, y: 238),
            CGPoint(x: 564, y: 238)
        ],
        fill: foreground
    )

    drawRoundedRect(context, CGRect(x: 384, y: 570, width: 118, height: 94), radius: 24, fill: background)

    drawRoundedRect(context, CGRect(x: 700, y: 238, width: 116, height: 548), radius: 30, fill: foreground)
    drawRoundedRect(context, CGRect(x: 700, y: 238, width: 218, height: 116), radius: 30, fill: foreground)

    guard let image = context.makeImage() else {
        throw NSError(domain: "RequestLabIcon", code: 2)
    }

    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RequestLabIcon", code: 3)
    }

    return png
}

for size in sizes {
    let data = try makeIcon(pixelSize: size.pixels)
    try data.write(to: iconsetURL.appendingPathComponent(size.filename), options: .atomic)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c",
    "icns",
    "-o",
    outputURL.path,
    iconsetURL.path
]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "RequestLabIcon", code: Int(process.terminationStatus))
}

print("Generated \(outputURL.path)")
