import AppKit
import GershwinChrome

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
        static let stripe: CGFloat = 8
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
                    self.phase = (self.phase + 1).truncatingRemainder(dividingBy: Metrics.stripe * 2)
                    self.needsDisplay = true
                }
            }
        } else if !animate {
            timer?.invalidate()
            timer = nil
        }
    }

    private var style: MenuStyle { MenuStyle(theme.chrome) }

    /// The bar's own colour: the highlight, black for System 1 and 7, and blue for BeOS.
    private var fill: NSColor {
        switch style {
        case .platinum: theme.highlight
        case .classic: theme.border
        case .beos: NSColor(srgbRed: 0.31, green: 0.5, blue: 0.85, alpha: 1)
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        let t = theme
        let track = NSRect(x: 0, y: 0, width: floor(bounds.width), height: Metrics.height)
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
            let period = Metrics.stripe * 2
            for row in 0..<Int(inside.height) {
                var x = inside.minX - period + phase - CGFloat(row)
                while x < inside.maxX {
                    NSRect(x: x, y: inside.minY + CGFloat(row), width: Metrics.stripe, height: 1).fill()
                    x += period
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
