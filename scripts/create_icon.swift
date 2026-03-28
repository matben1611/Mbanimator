#!/usr/bin/env swift
import AppKit

let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Hintergrund: dunkles Blau-Schwarz, abgerundet
let bg = NSBezierPath(
    roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
    xRadius: size * 0.22,
    yRadius: size * 0.22
)
NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1).setFill()
bg.fill()

// Drei horizontale Balken (Animation / Wellenform)
let barColor = NSColor(white: 1.0, alpha: 0.9)
barColor.setFill()

let barWidth = size * 0.52
let barHeight = size * 0.065
let spacing = size * 0.095
let cx = size / 2
let cy = size / 2

let heights: [CGFloat] = [barHeight * 0.6, barHeight, barHeight * 0.75]
let offsets: [CGFloat] = [-spacing, 0, spacing]

for (h, dy) in zip(heights, offsets) {
    let rect = NSRect(
        x: cx - barWidth / 2,
        y: cy + dy - h / 2,
        width: barWidth,
        height: h
    )
    NSBezierPath(roundedRect: rect, xRadius: h / 2, yRadius: h / 2).fill()
}

image.unlockFocus()

// Als PNG speichern
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("Fehler beim Erstellen des Icons")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Icon gespeichert: \(outputPath)")
