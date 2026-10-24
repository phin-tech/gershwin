import CoreGraphics

/// Where the terminal's scrollback is: Ghostty's `TerminalScrollbar`, as plain numbers (rows).
public struct ScrollPosition: Equatable, Sendable {
    /// Rows in the scrollback and the screen together.
    public var total: UInt64
    /// The first row on screen.
    public var offset: UInt64
    /// Rows on screen.
    public var visible: UInt64

    public init(total: UInt64, offset: UInt64, visible: UInt64) {
        self.total = total
        self.offset = offset
        self.visible = visible
    }

    /// Whether there is anything to scroll to. Without it the bar is an empty track, as on Mac OS 9.
    public var canScroll: Bool { total > visible }

    /// The largest `offset`, which shows the bottom of the scrollback.
    public var maxOffset: UInt64 { total > visible ? total - visible : 0 }
}

/// Where a scroll bar's arrows are.
public enum ScrollArrows: Sendable {
    /// One at each end: the Mac's, BeOS's, OS/2's and Windows'.
    case atEnds
    /// Both at the bottom, up above down: the Amiga's (and NeXT's).
    case together
    /// OPEN LOOK's elevator: up, drag and down in one fixed-size box that rides a cable between two anchors, the
    /// visible part shown on the cable.
    case elevator
}

/// OPEN LOOK's elevator's sizes, in pixels.
public enum ElevatorMetrics {
    /// Each of its three parts.
    public static let part: CGFloat = 14
    public static let anchor: CGFloat = 6
    public static let cable: CGFloat = 3
}

/// A vertical scroll bar's parts and arithmetic: its arrows, the track and a proportional thumb (Mac OS 8.5's "smart
/// scrolling") no shorter than the arrows. Flipped coordinates.
public struct ScrollbarGeometry: Equatable, Sendable {
    public let bounds: CGRect
    public let arrows: ScrollArrows

    public init(bounds: CGRect, arrows: ScrollArrows = .atEnds) {
        self.bounds = bounds
        self.arrows = arrows
    }

    private var arrowLength: CGFloat { min(ChromeMetrics.scrollBarWidth, bounds.height / 2) }

    /// The down arrow's length, and with both at the bottom, each one's (a third of the bar at most).
    private var bottomArrowLength: CGFloat {
        arrows == .together ? min(ChromeMetrics.scrollBarWidth, bounds.height / 3) : arrowLength
    }

    /// Where the up arrow is: for the elevator, with nothing scrolled (`upArrow(for:)` follows it).
    public var upArrow: CGRect {
        switch arrows {
        case .atEnds: CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: arrowLength)
        case .together: CGRect(x: bounds.minX, y: bounds.maxY - bottomArrowLength * 2, width: bounds.width,
                               height: bottomArrowLength)
        case .elevator: upArrow(for: ScrollPosition(total: 0, offset: 0, visible: 0))
        }
    }

    public var downArrow: CGRect {
        if arrows == .elevator { return downArrow(for: ScrollPosition(total: 0, offset: 0, visible: 0)) }
        return CGRect(x: bounds.minX, y: bounds.maxY - bottomArrowLength, width: bounds.width, height: bottomArrowLength)
    }

    public var track: CGRect {
        if arrows == .elevator {
            // The cable, between the anchors.
            let a = ElevatorMetrics.anchor
            return CGRect(x: bounds.minX, y: bounds.minY + a, width: bounds.width, height: max(0, bounds.height - a * 2))
        }
        let top = arrows == .together ? bounds.minY : upArrow.maxY
        let bottom = arrows == .together ? upArrow.minY : downArrow.minY
        return CGRect(x: bounds.minX, y: top, width: bounds.width, height: max(0, bottom - top))
    }

    // MARK: The elevator

    /// The anchors at the cable's ends: a click goes to the start or the end.
    public var topAnchor: CGRect {
        CGRect(x: bounds.minX + 2, y: bounds.minY, width: max(0, bounds.width - 4), height: ElevatorMetrics.anchor)
    }

    public var bottomAnchor: CGRect {
        CGRect(x: bounds.minX + 2, y: bounds.maxY - ElevatorMetrics.anchor, width: max(0, bounds.width - 4),
               height: ElevatorMetrics.anchor)
    }

    /// The elevator, where `position` puts it: at the top with nothing to scroll.
    public func elevator(for position: ScrollPosition) -> CGRect {
        let height = min(ElevatorMetrics.part * 3, track.height)
        let travel = max(0, track.height - height)
        let fraction = position.canScroll ? CGFloat(position.offset) / CGFloat(position.maxOffset) : 0
        return CGRect(x: bounds.minX, y: (track.minY + travel * min(max(fraction, 0), 1)).rounded(),
                      width: bounds.width, height: height)
    }

    /// The part of the cable the window shows, darkened.
    public func proportion(for position: ScrollPosition) -> CGRect? {
        guard position.canScroll else { return nil }
        let top = track.height * CGFloat(position.offset) / CGFloat(position.total)
        let length = max(2, track.height * CGFloat(position.visible) / CGFloat(position.total))
        return CGRect(x: track.midX - ElevatorMetrics.cable / 2, y: (track.minY + top).rounded(),
                      width: ElevatorMetrics.cable, height: length.rounded())
    }

    /// The up arrow where it is now: the elevator's top third, or fixed for the other styles.
    public func upArrow(for position: ScrollPosition) -> CGRect {
        guard arrows == .elevator else { return upArrow }
        let e = elevator(for: position)
        return CGRect(x: e.minX, y: e.minY, width: e.width, height: (e.height / 3).rounded())
    }

    public func downArrow(for position: ScrollPosition) -> CGRect {
        guard arrows == .elevator else { return downArrow }
        let e = elevator(for: position), third = (e.height / 3).rounded()
        return CGRect(x: e.minX, y: e.maxY - third, width: e.width, height: third)
    }

    /// The thumb for `position`, or nil when there is nothing to scroll or no room to draw one. For the elevator, its
    /// middle third, which drags it.
    public func thumb(for position: ScrollPosition) -> CGRect? {
        if arrows == .elevator {
            guard position.canScroll else { return nil }
            let up = upArrow(for: position), down = downArrow(for: position)
            return CGRect(x: up.minX, y: up.maxY, width: up.width, height: down.minY - up.maxY)
        }
        guard position.canScroll, track.height >= ChromeMetrics.scrollBarWidth else { return nil }
        let length = thumbLength(for: position)
        let travel = track.height - length
        let fraction = CGFloat(position.offset) / CGFloat(position.maxOffset)
        let y = track.minY + travel * min(max(fraction, 0), 1)
        return CGRect(x: track.minX, y: y.rounded(), width: track.width, height: length)
    }

    private func thumbLength(for position: ScrollPosition) -> CGFloat {
        let proportional = track.height * CGFloat(position.visible) / CGFloat(position.total)
        return min(track.height, max(ChromeMetrics.scrollBarWidth, proportional.rounded()))
    }

    /// The first row to show when the thumb is dragged so its top is at `thumbTop`.
    public func offset(forThumbTop thumbTop: CGFloat, position: ScrollPosition) -> UInt64 {
        guard position.canScroll else { return 0 }
        if arrows == .elevator {
            let e = elevator(for: position)
            let travel = track.height - e.height
            guard travel > 0 else { return 0 }
            let top = thumbTop - (e.height / 3).rounded()
            let fraction = min(max((top - track.minY) / travel, 0), 1)
            return UInt64((fraction * CGFloat(position.maxOffset)).rounded())
        }
        let travel = track.height - thumbLength(for: position)
        guard travel > 0 else { return 0 }
        let fraction = min(max((thumbTop - track.minY) / travel, 0), 1)
        return UInt64((fraction * CGFloat(position.maxOffset)).rounded())
    }

    /// What a click at `point` does.
    public func part(at point: CGPoint, position: ScrollPosition) -> ScrollbarPart? {
        guard bounds.contains(point) else { return nil }
        if arrows == .elevator {
            guard position.canScroll else { return nil }
            if topAnchor.contains(point) { return .toStart }
            if bottomAnchor.contains(point) { return .toEnd }
            let e = elevator(for: position)
            if point.y < e.minY { return .pageUp }
            if point.y >= e.maxY { return .pageDown }
            if upArrow(for: position).contains(point) { return .lineUp }
            if downArrow(for: position).contains(point) { return .lineDown }
            return .thumb
        }
        if upArrow.contains(point) { return .lineUp }
        if downArrow.contains(point) { return .lineDown }
        guard let thumb = thumb(for: position) else { return nil }
        if point.y < thumb.minY { return .pageUp }
        if point.y >= thumb.maxY { return .pageDown }
        return .thumb
    }
}

public enum ScrollbarPart: Equatable, Sendable {
    case lineUp, lineDown, pageUp, pageDown, thumb
    /// OPEN LOOK's cable anchors: the top, or the bottom.
    case toStart, toEnd
}
