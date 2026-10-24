import AppKit
import GershwinChrome

/// The frame Mac OS 8's Drag Manager drew inside a window while something dragged over it could be dropped there: a
/// two-pixel band in the highlight colour, inset a pixel from the edge. System 1 and 7 draw it black, BeOS in its blue.
///
/// Lay it over the view that takes the drop and show it while a drag is inside (`isHidden`); the mouse and the drag
/// pass through it to the view below.
@MainActor
public final class ClassicDropHighlight: NSView {
    public var theme: ClassicTheme { didSet { needsDisplay = true } }

    public init(theme: ClassicTheme) {
        self.theme = theme
        super.init(frame: .zero)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func hitTest(_ point: NSPoint) -> NSView? { nil }

    public override func draw(_ dirtyRect: NSRect) {
        let color: NSColor = switch MenuStyle(theme.chrome) {
        case .platinum: theme.highlight
        case .classic: theme.border
        case .beos: NSColor(srgbRed: 0.31, green: 0.5, blue: 0.85, alpha: 1)
        }
        color.setFill()
        let s = theme.scale
        let outer = bounds.insetBy(dx: s, dy: s)
        let band = NSBezierPath(rect: outer)
        band.append(NSBezierPath(rect: outer.insetBy(dx: 2 * s, dy: 2 * s)))
        band.windingRule = .evenOdd
        band.fill()
    }
}
