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

    /// Both arrows at the bottom in the Amiga's themes and Aqua's, OPEN LOOK's elevator in its, one at each end
    /// elsewhere.
    private var geometry: ScrollbarGeometry {
        let arrows: ScrollArrows = switch theme.chrome.family {
        case .amiga, .aqua: .together
        case .openLook: .elevator
        default: .atEnds
        }
        return ScrollbarGeometry(bounds: bounds, arrows: arrows)
    }

    // MARK: Drawing

    public override func draw(_ dirtyRect: NSRect) {
        let t = theme
        let g = geometry
        if t.isAqua { return drawAqua(g) }
        guard isActive else {
            t.background.setFill()
            bounds.fill()
            t.drawOutline(bounds)
            return
        }
        let position = position ?? ScrollPosition(total: 0, offset: 0, visible: 0)
        if g.arrows == .elevator { return drawElevator(g, position: position) }
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

    /// Aqua's: a white track, shadowed along its left as if sunk, a capsule of blue gel for the thumb (white in a window
    /// behind), and both arrows at the bottom in white gel.
    private func drawAqua(_ g: ScrollbarGeometry) {
        let t = theme
        let position = position ?? ScrollPosition(total: 0, offset: 0, visible: 0)
        NSGradient(colorsAndLocations: (NSColor(white: 0.78, alpha: 1), 0), (NSColor(white: 0.95, alpha: 1), 0.35),
                   (.white, 0.7), (NSColor(white: 0.93, alpha: 1), 1))?.draw(in: bounds, angle: 0)
        NSColor(white: 0, alpha: 0.3).setFill()
        NSRect(x: bounds.minX, y: bounds.minY, width: 1, height: bounds.height).fill()
        let thumb = g.thumb(for: position)
        if let thumb {
            let face = thumb.insetBy(dx: 2, dy: 1)
            let radius = face.width / 2
            t.drawGel(NSBezierPath(roundedRect: face, xRadius: radius, yRadius: radius), in: face,
                      color: isActive ? t.thumb : t.aquaWhite, pressed: pressed == .thumb)
        }
        for (rect, pointingUp, part) in [(g.upArrow, true, ScrollbarPart.lineUp), (g.downArrow, false, .lineDown)] {
            t.drawGel(NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5)), in: rect, color: t.aquaWhite,
                      pressed: pressed == part)
            (thumb == nil ? t.disabledText : t.text).setFill()
            let midX = rect.midX.rounded(.down), top = (rect.midY - 2).rounded(.down)
            for row in 0..<4 {
                let half = CGFloat(pointingUp ? row : 3 - row)
                NSRect(x: midX - half, y: top + CGFloat(row), width: half * 2 + 1, height: 1).fill()
            }
        }
    }

    /// OPEN LOOK's: a cable between two anchors, the part shown darkened on it, and the elevator riding it, its up,
    /// drag and down parts in one raised box.
    private func drawElevator(_ g: ScrollbarGeometry, position: ScrollPosition) {
        let t = theme
        t.background.setFill()
        bounds.fill()
        let cable = CGRect(x: (g.track.midX - ElevatorMetrics.cable / 2).rounded(.down), y: g.track.minY,
                           width: ElevatorMetrics.cable, height: g.track.height)
        t.well.setFill()
        cable.fill()
        t.drawOutline(cable, color: t.dark)
        if let shown = g.proportion(for: position) {
            t.border.setFill()
            shown.fill()
        }
        for (anchor, part) in [(g.topAnchor, ScrollbarPart.toStart), (g.bottomAnchor, .toEnd)] {
            t.drawButtonFace(anchor, pressed: pressed == part)
        }
        let elevator = g.elevator(for: position)
        let enabled = position.canScroll
        t.drawButtonFace(elevator, pressed: false)
        let up = g.upArrow(for: position), down = g.downArrow(for: position)
        if pressed == .lineUp { t.drawSunkenBevel(up.insetBy(dx: 1, dy: 1)) }
        if pressed == .lineDown { t.drawSunkenBevel(down.insetBy(dx: 1, dy: 1)) }
        if pressed == .thumb { t.drawSunkenBevel(CGRect(x: up.minX + 1, y: up.maxY, width: up.width - 2,
                                                        height: down.minY - up.maxY)) }
        t.dark.setFill()
        NSRect(x: elevator.minX + 2, y: up.maxY, width: elevator.width - 4, height: 1).fill()
        NSRect(x: elevator.minX + 2, y: down.minY - 1, width: elevator.width - 4, height: 1).fill()
        let ink = enabled ? t.border : t.disabledText
        ink.setFill()
        for (rect, pointingUp) in [(up, true), (down, false)] {
            let midX = rect.midX.rounded(.down), top = (rect.midY - 2).rounded(.down)
            for row in 0..<4 {
                let half = CGFloat(pointingUp ? row : 3 - row)
                NSRect(x: midX - half, y: top + CGFloat(row), width: half * 2 + 1, height: 1).fill()
            }
        }
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
        case .toStart: .offset(0)
        case .toEnd: position.map { .offset($0.maxOffset) }
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
