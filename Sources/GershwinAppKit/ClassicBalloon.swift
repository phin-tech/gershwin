import AppKit
import GershwinChrome

/// Balloon Help, from System 7 to Mac OS 9: with Help ▸ Show Balloons on, pausing over a part of a window shows what
/// it does in a speech balloon pointing at it. In BeOS themes, a yellow tooltip instead, as Haiku has.
///
/// Views say what they are with `classicHelp(at:)` (ClassicFrameView does for a window's boxes, title bar, scroll
/// bar, grow box and tabs); `ClassicBalloon.shared` shows and hides the one balloon.
@MainActor
public final class ClassicBalloon {
    public static let shared = ClassicBalloon()

    /// Help ▸ Show Balloons. Off by default, as it was.
    public var isEnabled = false {
        didSet { if !isEnabled { hide() } }
    }

    private var panel: BalloonPanel?
    private var shownText: String?

    /// Shows `text` pointing at `target` (a rect in screen coordinates), or keeps it if it's already showing.
    public func show(_ text: String, pointingAt target: NSRect, theme: ClassicTheme) {
        guard isEnabled else { return }
        if shownText == text, panel?.isVisible == true { return }
        hide()
        let panel = BalloonPanel(text: text, theme: theme)
        panel.place(pointingAt: target)
        panel.orderFront(nil)
        self.panel = panel
        shownText = text
    }

    public func hide() {
        panel?.orderOut(nil)
        panel = nil
        shownText = nil
    }

    /// For tests and the gallery: a balloon's view.
    public static func view(text: String, theme: ClassicTheme) -> NSView {
        BalloonView(text: text, theme: theme)
    }
}

/// Sizes in Mac OS 9 pixels.
private enum Metrics {
    static let maxTextWidth: CGFloat = 200
    static let padding: CGFloat = 8
    static let tail: CGFloat = 14
    static let radius: CGFloat = 10
    static let shadow: CGFloat = 2
}

private final class BalloonPanel: NSPanel {
    let balloon: BalloonView

    init(text: String, theme: ClassicTheme) {
        balloon = BalloonView(text: text, theme: theme)
        super.init(contentRect: NSRect(origin: .zero, size: balloon.frame.size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        contentView = balloon
        isOpaque = false
        backgroundColor = .clear
        hasShadow = balloon.isTooltip
        ignoresMouseEvents = true
        level = .floating
        isReleasedWhenClosed = false
    }

    /// Above and to the right of the target, the tail touching its middle; below it if there's no room above.
    func place(pointingAt target: NSRect) {
        let size = frame.size
        let screen = NSScreen.screens.first { $0.frame.intersects(target) }?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var origin = NSPoint(x: target.midX - balloon.tailX, y: target.midY + 2)
        if origin.y + size.height > screen.maxY { origin.y = target.minY - size.height - 2 }
        origin.x = min(max(origin.x, screen.minX), screen.maxX - size.width)
        setFrameOrigin(origin)
    }
}

private final class BalloonView: NSView {
    let text: String
    let theme: ClassicTheme
    let isTooltip: Bool
    private let font: NSFont
    private let textSize: NSSize

    /// Where the tail's point is, from the left, in points.
    var tailX: CGFloat { (isTooltip ? 12 : Metrics.radius + Metrics.tail / 2) * theme.scale }

    init(text: String, theme: ClassicTheme) {
        self.text = text
        self.theme = theme
        isTooltip = theme.chrome.family == .beos || theme.chrome.family == .aqua
        font = isTooltip ? (NSFont(name: "Helvetica", size: 11) ?? .systemFont(ofSize: 11)) : ClassicTheme.smallFont(size: 10)
        let measured = (text as NSString).boundingRect(with: NSSize(width: Metrics.maxTextWidth, height: 1000),
                                                       options: [.usesLineFragmentOrigin], attributes: [.font: font])
        textSize = NSSize(width: ceil(measured.width), height: ceil(measured.height))
        super.init(frame: .zero)
        let pixels = NSSize(width: textSize.width + Metrics.padding * 2 + Metrics.shadow,
                            height: textSize.height + Metrics.padding * 2 + (isTooltip ? 0 : Metrics.tail) + Metrics.shadow)
        setFrameSize(NSSize(width: pixels.width * theme.scale, height: pixels.height * theme.scale))
        setBoundsSize(pixels)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        let body = NSRect(x: 0, y: 0, width: textSize.width + Metrics.padding * 2,
                          height: textSize.height + Metrics.padding * 2)
        let ink = NSColor.black
        if isTooltip {
            NSColor(srgbRed: 1, green: 0.97, blue: 0.7, alpha: 1).setFill()
            body.fill()
            theme.drawOutline(body, color: NSColor(white: 0.4, alpha: 1))
        } else {
            // The balloon: rounded, the tail at its bottom left pointing down at the part, and a hard shadow.
            let path = NSBezierPath(roundedRect: body.insetBy(dx: 0.5, dy: 0.5), xRadius: Metrics.radius,
                                    yRadius: Metrics.radius)
            let tail = NSBezierPath()
            tail.move(to: NSPoint(x: Metrics.radius, y: body.maxY - 0.5))
            tail.line(to: NSPoint(x: Metrics.radius + Metrics.tail / 2, y: body.maxY + Metrics.tail))
            tail.line(to: NSPoint(x: Metrics.radius + Metrics.tail, y: body.maxY - 0.5))
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSAffineTransform()
            shadow.translateX(by: Metrics.shadow, yBy: Metrics.shadow)
            let shadowPath = path.copy() as! NSBezierPath
            shadowPath.append(tail)
            shadowPath.transform(using: shadow as AffineTransform)
            NSColor(white: 0, alpha: 0.4).setFill()
            shadowPath.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSColor.white.setFill()
            path.fill()
            tail.fill()
            ink.setStroke()
            path.lineWidth = 1
            path.stroke()
            tail.lineWidth = 1
            tail.stroke()
            // The tail's join with the body, cleared of the outline.
            NSColor.white.setFill()
            NSRect(x: Metrics.radius + 1, y: body.maxY - 1.5, width: Metrics.tail - 2, height: 2).fill()
        }
        (text as NSString).draw(with: NSRect(x: Metrics.padding, y: Metrics.padding, width: textSize.width,
                                             height: textSize.height),
                                options: [.usesLineFragmentOrigin], attributes: [.font: font, .foregroundColor: ink])
    }
}
