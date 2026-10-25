// Aqua's look, drawn: gel (a colour under a gloss that catches the light along its top and glows again along its
// bottom, as if lit through), pinstripes, the traffic lights and the resize grip. Mac OS X drew these from bitmaps;
// these are gradients that come close. In a flipped view, as everything here is.

import AppKit
import GershwinChrome

public extension ClassicTheme {
    var isAqua: Bool { chrome.family == .aqua }

    /// Graphite turns the traffic lights grey too, not only the blue.
    private var isGraphite: Bool { palette == .aquaGraphite }

    /// A window's outline: `rect` with its top corners rounded.
    func aquaWindowShape(_ rect: NSRect) -> NSBezierPath {
        let r = AquaMetrics.cornerRadius
        let path = NSBezierPath()
        let box = rect.insetBy(dx: 0.5, dy: 0.5)
        path.move(to: NSPoint(x: box.minX, y: box.maxY))
        path.line(to: NSPoint(x: box.minX, y: box.minY + r))
        path.appendArc(withCenter: NSPoint(x: box.minX + r, y: box.minY + r), radius: r, startAngle: 180, endAngle: 270)
        path.line(to: NSPoint(x: box.maxX - r, y: box.minY))
        path.appendArc(withCenter: NSPoint(x: box.maxX - r, y: box.minY + r), radius: r, startAngle: 270, endAngle: 360)
        path.line(to: NSPoint(x: box.maxX, y: box.maxY))
        path.close()
        return path
    }

    /// Aqua's pinstripes over `rect`: bands of the background and a lighter grey. Fainter in a window behind.
    func drawAquaPinstripes(_ rect: NSRect, faded: Bool = false) {
        background.setFill()
        rect.fill()
        let band = AquaMetrics.pinstripe
        (faded ? light.withAlphaComponent(0.35) : light.withAlphaComponent(0.6)).setFill()
        var y = (rect.minY / (band * 2)).rounded(.down) * band * 2
        while y < rect.maxY {
            NSRect(x: rect.minX, y: y, width: rect.width, height: band).fill()
            y += band * 2
        }
    }

    /// `path` filled with gel of `color`: lighter at the top, the colour itself through the middle, glowing again at
    /// the bottom, with a gloss across its upper half and an edge of the colour, darker. Darker all over while pressed.
    func drawGel(_ path: NSBezierPath, in rect: NSRect, color base: NSColor, pressed: Bool = false) {
        let color = pressed ? (base.blended(withFraction: 0.25, of: .black) ?? base) : base
        let top = color.blended(withFraction: 0.45, of: .white) ?? color
        let glow = color.blended(withFraction: 0.35, of: .white) ?? color
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSGradient(colorsAndLocations: (top, 0), (color, 0.5), (color, 0.75), (glow, 1))?.draw(in: rect, angle: 90)
        // The gloss: white fading out, over the top half, inset from the sides.
        let gloss = NSRect(x: rect.minX + rect.width * 0.1, y: rect.minY + 1, width: rect.width * 0.8,
                           height: rect.height * 0.45)
        let radius = min(gloss.height, gloss.width) / 2
        NSGradient(starting: NSColor(white: 1, alpha: 0.85), ending: NSColor(white: 1, alpha: 0.15))?
            .draw(in: NSBezierPath(roundedRect: gloss, xRadius: radius, yRadius: radius), angle: 90)
        NSGraphicsContext.restoreGraphicsState()
        (color.blended(withFraction: 0.45, of: .black) ?? color).withAlphaComponent(0.8).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    /// Aqua's white gel, for a button that isn't the default and a scroll bar's arrows.
    var aquaWhite: NSColor { NSColor(white: 0.9, alpha: 1) }

    /// A push button: a capsule of white gel, or blue for the default button.
    func drawAquaButton(_ rect: NSRect, isDefault: Bool, pressed: Bool) {
        let face = rect.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: face, xRadius: face.height / 2, yRadius: face.height / 2)
        drawGel(path, in: face, color: isDefault ? thumb : aquaWhite, pressed: pressed)
    }

    enum TrafficLight { case close, minimize, zoom }

    /// One of a window's three buttons: red, yellow or green gel (all grey in Graphite, and in a window behind),
    /// with its sign in it while pressed.
    func drawTrafficLight(_ rect: NSRect, _ light: TrafficLight, pressed: Bool, active: Bool) {
        let color: NSColor
        if !active {
            color = NSColor(white: 0.82, alpha: 1)
        } else if isGraphite {
            color = thumb
        } else {
            color = switch light {
            case .close: NSColor(srgbRed: 0.88, green: 0.27, blue: 0.24, alpha: 1)
            case .minimize: NSColor(srgbRed: 0.87, green: 0.63, blue: 0.14, alpha: 1)
            case .zoom: NSColor(srgbRed: 0.10, green: 0.67, blue: 0.16, alpha: 1)
            }
        }
        let circle = rect.insetBy(dx: 0.5, dy: 0.5)
        drawGel(NSBezierPath(ovalIn: circle), in: circle, color: color, pressed: pressed)
        guard pressed else { return }
        // Its sign: ×, − or +, in the colour, darkened.
        let ink = (color.blended(withFraction: 0.6, of: .black) ?? color)
        ink.setStroke()
        let c = NSPoint(x: rect.midX, y: rect.midY), r = rect.width * 0.22
        let strokes: [(CGPoint, CGPoint)] = switch light {
        case .close: [(CGPoint(x: c.x - r, y: c.y - r), CGPoint(x: c.x + r, y: c.y + r)),
                      (CGPoint(x: c.x - r, y: c.y + r), CGPoint(x: c.x + r, y: c.y - r))]
        case .minimize: [(CGPoint(x: c.x - r, y: c.y), CGPoint(x: c.x + r, y: c.y))]
        case .zoom: [(CGPoint(x: c.x - r, y: c.y), CGPoint(x: c.x + r, y: c.y)),
                     (CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x, y: c.y + r))]
        }
        let sign = NSBezierPath()
        for (from, to) in strokes {
            sign.move(to: from)
            sign.line(to: to)
        }
        sign.lineWidth = 1.5
        sign.stroke()
    }

    /// The resize grip in a window's bottom-right corner: three diagonal grooves.
    func drawAquaGrip(_ rect: NSRect) {
        for i in 0..<3 {
            let inset = CGFloat(3 + i * 4)
            let groove = NSBezierPath()
            groove.move(to: NSPoint(x: rect.maxX - inset, y: rect.maxY - 2))
            groove.line(to: NSPoint(x: rect.maxX - 2, y: rect.maxY - inset))
            groove.lineWidth = 1
            dark.withAlphaComponent(0.7).setStroke()
            groove.stroke()
            let shine = NSBezierPath()
            shine.move(to: NSPoint(x: rect.maxX - inset + 1, y: rect.maxY - 2))
            shine.line(to: NSPoint(x: rect.maxX - 2, y: rect.maxY - inset + 1))
            shine.lineWidth = 1
            light.setStroke()
            shine.stroke()
        }
    }
}
