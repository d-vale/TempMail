import AppKit

// Génère l'icône de l'app : carré arrondi sombre + le symbole `tray.full`,
// le même que celui de la barre de menus.
// Usage : swift Tools/make-icon.swift <chemin AppIcon.appiconset>

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let out = CommandLine.arguments[1]

/// Contexte bitmap à la taille exacte en pixels : dessiner via
/// `NSImage.lockFocus()` produirait du 2× sur écran Retina, et `actool`
/// rejetterait alors silencieusement tout le jeu d'icônes.
func makeRep(_ px: Int) -> NSBitmapImageRep? {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )
    rep?.size = NSSize(width: px, height: px)
    return rep
}

/// Teinte le symbole dans son propre contexte transparent : appliquer la
/// couleur directement sur l'icône peindrait aussi le fond sous le symbole.
func tinted(_ symbol: NSImage, _ color: NSColor) -> NSImage? {
    let w = max(1, Int(symbol.size.width.rounded())), h = max(1, Int(symbol.size.height.rounded()))
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = symbol.size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let box = CGRect(origin: .zero, size: symbol.size)
    symbol.draw(in: box)
    color.set()
    box.fill(using: .sourceAtop)
    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: symbol.size)
    image.addRepresentation(rep)
    return image
}

for px in sizes {
    guard let rep = makeRep(px) else { continue }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    let inset = s * 0.055
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    NSBezierPath(roundedRect: rect, xRadius: s * 0.225, yRadius: s * 0.225).addClip()
    NSGradient(colors: [
        NSColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1),
        NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1),
    ])!.draw(in: rect, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.52, weight: .regular)
    if let symbol = NSImage(systemSymbolName: "tray.full", accessibilityDescription: nil)?
        .withSymbolConfiguration(config),
       let glyph = tinted(symbol, .white) {
        let w = glyph.size.width, h = glyph.size.height
        glyph.draw(in: CGRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h))
    }
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: URL(fileURLWithPath: "\(out)/icon_\(px).png"))
}
print("icônes générées : \(sizes.map(String.init).joined(separator: ", ")) px")
