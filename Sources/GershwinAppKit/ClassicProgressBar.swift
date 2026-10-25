import AppKit
import GershwinChrome

/// How far along something is, for a bar that shows it: a fraction from 0 to 1, or not known (the barber pole).
public enum ClassicProgress: Equatable, Sendable {
    case fraction(Double)
    case indeterminate

    /// The fraction, or nil for the barber pole, as ClassicProgressBar's `value` has it.
    public var fraction: Double? {
        if case .fraction(let value) = self { value } else { nil }
    }
}

/// A progress bar in the theme's style: Mac OS 8 and 9's sunken well with a bevelled bar in the highlight colour;
/// System 7's outlined white track filled in dark grey; BeOS's status bar in blue. When how far along isn't known, the
/// barber pole that System 7 introduced: diagonal stripes, moving.
@MainActor
public final class ClassicProgressBar: NSView {
    public var theme: ClassicTheme { didSet { needsLayout = true; needsDisplay = true } }

    /// From 0 to 1, or nil for the barber pole.
    public var value: Double? {
        didSet {
            needsDisplay = true
            updateAnimation()
        }
    }

    private var phase: CGFloat = 0
    private var timer: Timer?

    /// Sizes in Mac OS 9 pixels.
    private enum Metrics {
        static let height: CGFloat = 12
    }

    public init(value: Double? = 0, theme: ClassicTheme) {
        self.value = value
        self.theme = theme
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.progressIndicator)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var isFlipped: Bool { true }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Metrics.height * theme.scale)
    }

    public override func layout() {
        super.layout()
        setClassicBounds(scale: theme.scale)
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAnimation()
    }

    public override func accessibilityValue() -> Any? { value.map { NSNumber(value: $0) } }

    /// The barber pole moves while it shows; nothing ticks otherwise.
    private func updateAnimation() {
        let animate = value == nil && window != nil && !isHidden
        if animate, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.phase = (self.phase + 1).truncatingRemainder(dividingBy: Self.stripe * 2)
                    self.needsDisplay = true
                }
            }
        } else if !animate {
            timer?.invalidate()
            timer = nil
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        Self.draw(value: value, phase: phase,
                  in: NSRect(x: 0, y: 0, width: floor(bounds.width), height: Metrics.height), theme: theme)
    }

    /// Draws a bar, its track filling `track` (Mac OS 9 pixels), for ClassicProgressBar and the parts of a window
    /// that show one of their own, like the placard. `phase` moves the barber pole.
    static func draw(value: Double?, phase: CGFloat, in track: NSRect, theme t: ClassicTheme) {
        if t.isAqua { return drawAqua(value: value, phase: phase, in: track, theme: t) }
        let style = MenuStyle(t.chrome)
        // The bar's own colour: the highlight, black for System 1 and 7, and blue for BeOS.
        let fill: NSColor = switch style {
        case .platinum: t.highlight
        case .classic: t.border
        case .beos: NSColor(srgbRed: 0.31, green: 0.5, blue: 0.85, alpha: 1)
        }
        // The track.
        switch style {
        case .platinum:
            t.well.setFill()
            track.fill()
            t.drawSunkenBevel(track)
            t.drawOutline(track.insetBy(dx: 1, dy: 1))
        case .classic:
            t.light.setFill()
            track.fill()
            t.drawOutline(track)
        case .beos:
            t.light.setFill()
            track.fill()
            t.drawSunkenBevel(track)
        }
        let inside = track.insetBy(dx: style == .platinum ? 2 : 1, dy: style == .platinum ? 2 : 1)

        NSGraphicsContext.saveGraphicsState()
        inside.clip()
        if let value {
            let done = NSRect(x: inside.minX, y: inside.minY, width: (inside.width * min(max(value, 0), 1)).rounded(),
                              height: inside.height)
            fill.setFill()
            done.fill()
            if style != .classic, done.width > 2 {
                // A highlight along its top and a shade along its bottom.
                NSColor(white: 1, alpha: 0.35).setFill()
                NSRect(x: done.minX, y: done.minY, width: done.width, height: 1).fill()
                NSColor(white: 0, alpha: 0.3).setFill()
                NSRect(x: done.minX, y: done.maxY - 1, width: done.width, height: 1).fill()
            }
        } else {
            // The barber pole: stripes leaning right, drawn a pixel row at a time so they stay crisp.
            let light = style == .classic ? t.light : t.light.blended(withFraction: 0.3, of: fill) ?? t.light
            light.setFill()
            inside.fill()
            fill.setFill()
            let period = stripe * 2
            for row in 0..<Int(inside.height) {
                var x = inside.minX - period + phase - CGFloat(row)
                while x < inside.maxX {
                    NSRect(x: x, y: inside.minY + CGFloat(row), width: stripe, height: 1).fill()
                    x += period
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Aqua's: a white capsule, filled with blue gel as far as it has got; or, not knowing, the blue and white stripes
    /// under the same gloss, moving.
    private static func drawAqua(value: Double?, phase: CGFloat, in track: NSRect, theme t: ClassicTheme) {
        let radius = track.height / 2
        let shape = NSBezierPath(roundedRect: track.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
        t.drawGel(shape, in: track, color: t.aquaWhite)
        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        if let value {
            let done = NSRect(x: track.minX, y: track.minY, width: (track.width * min(max(value, 0), 1)).rounded(),
                              height: track.height)
            if done.width > 1 {
                t.drawGel(NSBezierPath(roundedRect: done.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius),
                          in: done, color: t.thumb)
            }
        } else {
            t.drawGel(NSBezierPath(rect: track), in: track, color: t.thumb)
            NSColor(white: 1, alpha: 0.45).setFill()
            let period = stripe * 2
            for row in 0..<Int(track.height) {
                var x = track.minX - period + phase - CGFloat(row)
                while x < track.maxX {
                    NSRect(x: x, y: track.minY + CGFloat(row), width: stripe, height: 1).fill()
                    x += period
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    /// The barber pole's stripe width, in pixels; its phase runs from 0 to twice this.
    static let stripe: CGFloat = 8
}
