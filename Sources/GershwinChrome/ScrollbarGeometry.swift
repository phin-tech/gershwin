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

/// A vertical Platinum scroll bar's parts and arithmetic: an arrow at each end, the track between them and a
/// proportional thumb (Mac OS 8.5's "smart scrolling") no shorter than the arrows. Flipped coordinates.
public struct ScrollbarGeometry: Equatable, Sendable {
    public let bounds: CGRect

    public init(bounds: CGRect) {
        self.bounds = bounds
    }

    private var arrowLength: CGFloat { min(ChromeMetrics.scrollBarWidth, bounds.height / 2) }

    public var upArrow: CGRect {
        CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: arrowLength)
    }

    public var downArrow: CGRect {
        CGRect(x: bounds.minX, y: bounds.maxY - arrowLength, width: bounds.width, height: arrowLength)
    }

    public var track: CGRect {
        CGRect(x: bounds.minX, y: upArrow.maxY, width: bounds.width, height: max(0, downArrow.minY - upArrow.maxY))
    }

    /// The thumb for `position`, or nil when there is nothing to scroll or no room to draw one.
    public func thumb(for position: ScrollPosition) -> CGRect? {
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
        let travel = track.height - thumbLength(for: position)
        guard travel > 0 else { return 0 }
        let fraction = min(max((thumbTop - track.minY) / travel, 0), 1)
        return UInt64((fraction * CGFloat(position.maxOffset)).rounded())
    }

    /// What a click at `point` does.
    public func part(at point: CGPoint, position: ScrollPosition) -> ScrollbarPart? {
        guard bounds.contains(point) else { return nil }
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
}
