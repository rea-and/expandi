import AppKit
import CoreGraphics

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let margin = size * 0.1
    let contentRect = rect.insetBy(dx: margin, dy: margin)
    let cornerRadius = contentRect.width * 0.225
    
    let path = CGPath(roundedRect: contentRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // Background shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.03), blur: size * 0.06, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(path)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    
    // Clip to squircle
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    
    // Gradient Background (Electric Deep Indigo to Vibrant Cyan/Blue)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(red: 0.12, green: 0.20, blue: 0.85, alpha: 1.0).cgColor,
        NSColor(red: 0.25, green: 0.55, blue: 0.98, alpha: 1.0).cgColor
    ] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: contentRect.midX, y: contentRect.maxY), end: CGPoint(x: contentRect.midX, y: contentRect.minY), options: [])
    }
    
    // Inner Glow Highlight
    let innerBorderPath = CGPath(roundedRect: contentRect.insetBy(dx: 1.5, dy: 1.5), cornerWidth: cornerRadius - 1.5, cornerHeight: cornerRadius - 1.5, transform: nil)
    ctx.addPath(innerBorderPath)
    ctx.setLineWidth(size * 0.008)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
    ctx.strokePath()
    
    ctx.restoreGState()
    
    // Draw Symbol: Stylized Fast Expansion Sparkle & Cursor Bracket
    ctx.saveGState()
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.45, weight: .bold)
    if let starSymbol = NSImage(systemSymbolName: "text.badge.star", accessibilityDescription: nil)?.withSymbolConfiguration(symbolConfig) {
        let symbolSize = starSymbol.size
        let drawOrigin = CGPoint(
            x: (size - symbolSize.width) / 2.0,
            y: (size - symbolSize.height) / 2.0 - (size * 0.02)
        )
        
        // Draw white symbol with subtle drop shadow
        ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.02), blur: size * 0.04, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        starSymbol.draw(at: drawOrigin, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    ctx.restoreGState()
    
    image.unlockFocus()
    return image
}

let iconsetDir = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, size: CGFloat)] = [
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

for item in sizes {
    let img = createIcon(size: item.size)
    if let tiff = img.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        let path = "\(iconsetDir)/\(item.name)"
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

print("Iconset created. Generating .icns...")
