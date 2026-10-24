// The Mac OS 8/9 look, drawn. One theme holds the colours (GershwinChrome's Palette) and the few shapes everything is
// built from (a raised bevel, a sunken one, an etched line), so a title bar box and a push button can't drift
// apart. Grown from chezmoi's SketchyBar helpers (helpers/shared/Platinum.swift), which draw the menus the same way.
//
// Text is ChicagoFLF, a free revival of Chicago, when it is installed (chezmoi puts it in ~/Library/Fonts), and
// otherwise the system font. Charcoal, the real Mac OS 8/9 font, was never free. Small text is Geneva, which macOS
// still ships.

import AppKit
import GershwinChrome

public struct ClassicTheme: Sendable, Equatable {
    public let chrome: ChromeTheme
    /// Points to a pixel of chrome: everything is drawn in Mac OS 9 pixels, and a window scales them by this (the
    /// terminal itself isn't scaled).
    public let scale: CGFloat
    public var palette: Palette { chrome.palette }

    public init(_ chrome: ChromeTheme, scale: CGFloat = 1) {
        self.chrome = chrome
        self.scale = scale
    }

    public static let platinum = ClassicTheme(.platinum)
    public static let hiTech = ClassicTheme(.hiTech)
    public static let all = ChromeTheme.builtIn.map { ClassicTheme($0) }

    public var background: NSColor { NSColor(palette.background) }
    public var light: NSColor { NSColor(palette.light) }
    public var dark: NSColor { NSColor(palette.dark) }
    public var border: NSColor { NSColor(palette.border) }
    public var well: NSColor { NSColor(palette.well) }
    public var highlight: NSColor { NSColor(palette.highlight) }
    public var text: NSColor { NSColor(palette.text) }
    public var selectedText: NSColor { NSColor(palette.selectedText) }
    public var disabledText: NSColor { NSColor(palette.disabledText) }
    public var pinstripe: NSColor { NSColor(palette.pinstripe) }
    public var thumb: NSColor { NSColor(palette.thumb) }

    /// For the things macOS draws around ours (sheets, the font panel).
    public var nsAppearance: NSAppearance? {
        NSAppearance(named: chrome.isDark ? .darkAqua : .aqua)
    }

    /// ChicagoFLF, or the system font if it isn't installed: titles, buttons, menus.
    public static func systemFont(size: CGFloat = 12) -> NSFont {
        NSFont(name: "ChicagoFLF", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    }

    /// The font of titles and controls in this appearance: Chicago for the Mac's, and for BeOS the bold sans its tabs
    /// were set in (Swiss 721, which isn't free; Helvetica is its model).
    public func font(size: CGFloat = 12) -> NSFont {
        guard chrome.family == .beos else { return Self.systemFont(size: size) }
        return NSFont(name: "Helvetica-Bold", size: size) ?? .boldSystemFont(ofSize: size)
    }

    /// Geneva: placards, captions and the small print in dialogs.
    public static func smallFont(size: CGFloat = 10) -> NSFont {
        NSFont(name: "Geneva", size: size) ?? .systemFont(ofSize: size)
    }
}

public extension NSColor {
    convenience init(_ rgb: RGB) {
        self.init(srgbRed: CGFloat(rgb.red) / 255, green: CGFloat(rgb.green) / 255, blue: CGFloat(rgb.blue) / 255,
                  alpha: 1)
    }
}

public extension NSView {
    /// Gives this view bounds in Mac OS 9 pixels: its frame over the theme's scale, less whatever scale the views
    /// it's in already apply (a button in an alert that is itself scaled isn't scaled twice).
    func setClassicBounds(scale: CGFloat) {
        let inherited = superview.map { $0.convert(NSSize(width: 1, height: 1), to: nil).width } ?? 1
        let factor = scale / max(inherited, 0.0001)
        setBoundsSize(NSSize(width: frame.width / factor, height: frame.height / factor))
    }
}

// Drawing, in a flipped view (y grows down), one-point lines on whole-point rects.
public extension ClassicTheme {
    /// A raised edge just inside `rect`: light on the top and left, dark on the bottom and right.
    func drawRaisedBevel(_ rect: NSRect, depth: Int = 1) {
        for i in 0..<depth {
            drawBevel(rect.insetBy(dx: CGFloat(i), dy: CGFloat(i)), topLeft: light, bottomRight: dark)
        }
    }

    /// A sunken edge just inside `rect`: dark on the top and left, light on the bottom and right.
    func drawSunkenBevel(_ rect: NSRect) {
        drawBevel(rect, topLeft: dark, bottomRight: light)
    }

    private func drawBevel(_ rect: NSRect, topLeft: NSColor, bottomRight: NSColor) {
        guard rect.width >= 2, rect.height >= 2 else { return }
        topLeft.setFill()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width - 1, height: 1).fill()
        NSRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height - 1).fill()
        bottomRight.setFill()
        NSRect(x: rect.minX + 1, y: rect.maxY - 1, width: rect.width - 1, height: 1).fill()
        NSRect(x: rect.maxX - 1, y: rect.minY + 1, width: 1, height: rect.height - 1).fill()
    }

    /// A sunken area: `well`, or for a one-bit appearance a 50% checkerboard of black and white, a point a square.
    func fillWell(_ rect: NSRect) {
        guard palette.dithersWells else {
            well.setFill()
            rect.fill()
            return
        }
        background.setFill()
        rect.fill()
        border.setFill()
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX + ((y - rect.minY).truncatingRemainder(dividingBy: 2))
            while x < rect.maxX {
                NSRect(x: x, y: y, width: 1, height: 1).fill()
                x += 2
            }
            y += 1
        }
    }

    /// A one-point outline just inside `rect`.
    func drawOutline(_ rect: NSRect, color: NSColor? = nil) {
        (color ?? border).setFill()
        rect.frame(withWidth: 1)
    }

    /// A separator: a dark line over a light one, starting at `y`.
    func drawEtchedLine(x: CGFloat, y: CGFloat, width: CGFloat) {
        dark.setFill()
        NSRect(x: x, y: y, width: width, height: 1).fill()
        light.setFill()
        NSRect(x: x, y: y + 1, width: width, height: 1).fill()
    }

    /// A raised button face: an outline, a bevel inside it and a fill, or sunken and darker while pressed.
    func drawButtonFace(_ rect: NSRect, pressed: Bool, fill: NSColor? = nil) {
        (pressed ? well : (fill ?? background)).setFill()
        rect.fill()
        drawOutline(rect)
        let inner = rect.insetBy(dx: 1, dy: 1)
        if pressed { drawSunkenBevel(inner) } else { drawRaisedBevel(inner) }
    }

    /// Text in `rect`, truncated at the end to fit, vertically centred.
    func drawText(_ string: String, in rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        let height = ceil(font.ascender - font.descender)
        let line = NSRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
        (string as NSString).draw(with: line, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                  attributes: attributes)
    }

    func textWidth(_ string: String, font: NSFont) -> CGFloat {
        ceil((string as NSString).size(withAttributes: [.font: font]).width)
    }
}
