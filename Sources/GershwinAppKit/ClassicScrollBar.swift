import AppKit
import GershwinChrome

/// What the user asked a scroll bar for.
public enum ScrollRequest: Equatable, Sendable {
    /// Up (negative) or down by rows, from the arrows.
    case lines(Int)
    /// Up (negative) or down by a screenful, from the track.
    case pages(Int)
    /// Show this row first, from dragging the thumb.
    case offset(UInt64)
}

/// A vertical Platinum scroll bar: arrows at each end, a sunken track and a lavender thumb with grip lines. The
/// arrows and the track repeat while held, and the thumb scrolls live. In an inactive window it is an empty outline,
/// as on Mac OS 9. Its arithmetic is FanfareKit's `ScrollbarGeometry`.
@MainActor
public final class ClassicScrollBar: NSView {
    public var theme: ClassicTheme { didSet { needsDisplay = true } }

    /// Where the content is; nil until it reports, which draws an empty track.
    public var position: ScrollPosition? {
        didSet { if position != oldValue { needsDisplay = true } }
    }

    public var onScroll: ((ScrollRequest) -> Void)?

    /// Drawn as in the frontmost window (or the active pane); otherwise an empty outline, as Mac OS 9's were.
    public var isActive = true { didSet { if isActive != oldValue { needsDisplay = true } } }

    private var pressed: ScrollbarPart?

    public init(theme: ClassicTheme) {
        self.theme = theme
        super.init(frame: .zero)
    }

    /// In Mac OS 9 pixels, whether in a window's (scaled) frame or anywhere else.
    public override func layout() {
        super.layout()
        setClassicBounds(scale: theme.scale)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var isFlipped: Bool { true }
    public override var isOpaque: Bool { true }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var geometry: ScrollbarGeometry { ScrollbarGeometry(bounds: bounds) }

    // MARK: Drawing

    public override func draw(_ dirtyRect: NSRect) {
        let t = theme
        let g = geometry
        guard isActive else {
            t.background.setFill()
            bounds.fill()
            t.drawOutline(bounds)
            return
        }
        let position = position ?? ScrollPosition(total: 0, offset: 0, visible: 0)
        let thumb = g.thumb(for: position)

        // The track: a well, shaded along its top and left.
        if thumb == nil {
            t.background.setFill()
            bounds.fill()
        } else {
            t.fillWell(bounds)
        }
        t.drawOutline(bounds)
        if thumb != nil {
            t.dark.setFill()
            NSRect(x: g.track.minX + 1, y: g.track.minY, width: 1, height: g.track.height).fill()
        }
        if pressed == .pageUp || pressed == .pageDown, let thumb {
            t.dark.setFill()
            let area = pressed == .pageUp
                ? NSRect(x: g.track.minX + 1, y: g.track.minY, width: g.track.width - 2, height: thumb.minY - g.track.minY)
                : NSRect(x: g.track.minX + 1, y: thumb.maxY, width: g.track.width - 2, height: g.track.maxY - thumb.maxY)
            area.fill()
        }

        drawArrow(g.upArrow, pointingUp: true, pressed: pressed == .lineUp, enabled: thumb != nil)
        drawArrow(g.downArrow, pointingUp: false, pressed: pressed == .lineDown, enabled: thumb != nil)

        if let thumb { drawThumb(thumb) }
    }

    private func drawArrow(_ rect: CGRect, pointingUp: Bool, pressed: Bool, enabled: Bool) {
        let t = theme
        t.drawButtonFace(rect, pressed: pressed)
        // A solid triangle, seven wide and four tall, drawn a row at a time so it stays crisp.
        let ink = enabled ? (pressed ? t.light : t.border) : t.disabledText
        ink.setFill()
        let midX = rect.midX.rounded(.down)
        let top = (rect.midY - 2).rounded(.down)
        for row in 0..<4 {
            let half = CGFloat(pointingUp ? row : 3 - row)
            NSRect(x: midX - half, y: top + CGFloat(row), width: half * 2 + 1, height: 1).fill()
        }
    }

    private func drawThumb(_ rect: CGRect) {
        let t = theme
        t.drawButtonFace(rect, pressed: pressed == .thumb, fill: t.thumb)
        // Grip: four etched lines in the middle, if there's room.
        guard rect.height >= 14 else { return }
        let top = (rect.midY - 4).rounded(.down)
        for i in 0..<4 {
            t.drawEtchedLine(x: rect.minX + 4, y: top + CGFloat(i * 2), width: rect.width - 8)
        }
    }

    // MARK: Mouse

    public override func mouseDown(with event: NSEvent) {
        guard isActive, let position, let part = geometry.part(at: point(of: event), position: position) else {
            return
        }
        if part == .thumb {
            trackThumb(from: event, position: position)
        } else {
            trackRepeating(part)
        }
    }

    private func point(of event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    private func request(for part: ScrollbarPart) -> ScrollRequest? {
        switch part {
        case .lineUp: .lines(-1)
        case .lineDown: .lines(1)
        case .pageUp: .pages(-1)
        case .pageDown: .pages(1)
        case .thumb: nil
        }
    }

    /// Arrows and the track: act at once, then again and again while the mouse stays down on the same part.
    private func trackRepeating(_ part: ScrollbarPart) {
        guard let window, let request = request(for: part) else { return }
        pressed = part
        needsDisplay = true
        onScroll?(request)
        NSEvent.startPeriodicEvents(afterDelay: 0.3, withPeriod: 0.05)
        defer {
            NSEvent.stopPeriodicEvents()
            pressed = nil
            needsDisplay = true
        }
        var mouse = window.mouseLocationOutsideOfEventStream
        while let event = window.nextEvent(matching: [.leftMouseUp, .leftMouseDragged, .periodic]) {
            if event.type == .leftMouseUp { return }
            if event.type == .leftMouseDragged { mouse = event.locationInWindow }
            guard event.type == .periodic, let position else { continue }
            // The page area shrinks as the thumb moves towards the mouse; stop once the thumb reaches it.
            let here = geometry.part(at: convert(mouse, from: nil), position: position)
            let still = here == part
            if (pressed != nil) != still {
                pressed = still ? part : nil
                needsDisplay = true
            }
            if still { onScroll?(request) }
        }
    }

    /// The thumb: follows the mouse, scrolling as it goes.
    private func trackThumb(from event: NSEvent, position: ScrollPosition) {
        guard let window, let thumb = geometry.thumb(for: position) else { return }
        let grab = point(of: event).y - thumb.minY
        pressed = .thumb
        needsDisplay = true
        defer {
            pressed = nil
            needsDisplay = true
        }
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let top = point(of: next).y - grab
            let current = self.position ?? position
            onScroll?(.offset(geometry.offset(forThumbTop: top, position: current)))
            if next.type == .leftMouseUp { return }
        }
    }
}
