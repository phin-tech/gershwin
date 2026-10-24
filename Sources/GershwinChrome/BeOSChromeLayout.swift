import CoreGraphics

/// The shapes of window Gershwin draws.
public enum ChromeFamily: Sendable {
    /// The classic Mac's: a title bar across the whole top, boxes at its ends (WindowChromeLayout).
    case macintosh
    /// BeOS's: a yellow tab only as wide as the title, on the top edge, over the desktop (BeOSChromeLayout).
    case beos
    /// OS/2 Warp's: a sizing border all round, a coloured title bar with the system menu at its left and the hide,
    /// maximize and close buttons at its right (OS2ChromeLayout).
    case os2
}

/// The sizes of a BeOS window's parts, in points, as BeOS R5 drew them.
public enum BeOSMetrics {
    /// The title tabs along the top.
    public static let tabHeight: CGFloat = 21
    /// The frame around the content: a dark outline, then grey, then the content's own edge.
    public static let frameWidth: CGFloat = 5
    public static let boxSize: CGFloat = 13
    /// From a tab's ends to its close and zoom boxes.
    public static let boxInset: CGFloat = 5
    /// Between a box and the title beside it, and either side of a title on a tab without boxes.
    public static let titleGap: CGFloat = 7
    /// A tab is never narrower than this, however short its title.
    public static let minimumTabWidth: CGFloat = 70
    public static let scrollBarWidth: CGFloat = 14
    /// A collapsed window: just its tab, floating.
    public static var collapsedHeight: CGFloat { tabHeight }

    /// BeOS's floating windows have a smaller tab, with smaller boxes.
    public static func tabHeight(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 15 : tabHeight }
    public static func boxSize(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 9 : boxSize }
}

/// Where each part of a BeOS window goes, for a window of a given size and its tabs' titles. Flipped coordinates.
///
/// The top strip is the tabs and, beside them, nothing: the window is transparent there, and clicks fall through to
/// whatever is behind. With one tab, the tab is the window's title; with more, each terminal tab is a title tab of its
/// own, side by side, as Haiku stacks windows (Stack & Tile). Every tab has its own close box, which closes that tab;
/// only the front one has the zoom box.
public struct BeOSChromeLayout: Equatable, Sendable {
    public let bounds: CGRect
    public let style: ClassicWindowStyle
    public let isCollapsed: Bool

    /// One per title, left to right.
    public let tabs: [CGRect]
    public let frontTab: Int
    /// The front tab's close box.
    public let closeBox: CGRect
    /// Every tab's close box, one per tab.
    public let closeBoxes: [CGRect]
    public let zoomBox: CGRect?
    /// Each tab's title, inside its tab.
    public let titles: [CGRect]
    /// The opaque part below the tabs: the frame and everything in it. Empty when collapsed.
    public let body: CGRect
    /// Inside the frame.
    public let content: CGRect
    public let main: CGRect
    public let scrollBar: CGRect?
    /// The resize knob, under the scroll bar.
    public let growBox: CGRect?

    /// - Parameters:
    ///   - titleWidths: each tab's title text width; at least one (the window's title).
    ///   - slide: how far right of the window's left edge the tabs start; kept so they stay on the window.
    public init(bounds: CGRect, style: ClassicWindowStyle, isCollapsed: Bool = false, titleWidths: [CGFloat],
                frontTab: Int = 0, slide: CGFloat = 0) {
        typealias M = BeOSMetrics
        self.bounds = bounds
        self.style = style
        self.isCollapsed = isCollapsed
        let widths = titleWidths.isEmpty ? [0] : titleWidths
        let front = min(max(frontTab, 0), widths.count - 1)
        self.frontTab = front

        // Each tab has a close box before its title; the front one also has the zoom box after it.
        let boxSize = M.boxSize(for: style), tabHeight = M.tabHeight(for: style)
        let closePart = M.boxInset + boxSize + M.titleGap
        let boxesWidth = closePart + (style == .document ? M.titleGap + boxSize + M.boxInset : M.titleGap)
        let wanted = widths.enumerated().map { i, text in
            max(M.minimumTabWidth, (text + (i == front ? boxesWidth : closePart + M.titleGap)).rounded(.up))
        }
        // Too wide for the window: the back tabs give way first, then the front one.
        let available = max(0, bounds.width)
        var sized = wanted
        if sized.reduce(0, +) > available, sized.count > 1 {
            let others = available - sized[front]
            let each = max(M.minimumTabWidth / 2, (others / CGFloat(sized.count - 1)).rounded(.down))
            sized = sized.enumerated().map { $0.offset == front ? $0.element : min($0.element, each) }
        }
        if sized.reduce(0, +) > available {
            sized[front] = max(boxesWidth, available - sized.enumerated().filter { $0.offset != front }
                .map(\.element).reduce(0, +))
        }
        let total = sized.reduce(0, +)
        var x = bounds.minX + min(max(0, slide), max(0, bounds.width - total))
        let laidOut = sized.map { width in
            defer { x += width }
            return CGRect(x: x, y: bounds.minY, width: width, height: tabHeight)
        }
        tabs = laidOut

        let tab = laidOut[front]
        let boxY = (tab.midY - boxSize / 2).rounded(.down)
        let closes = laidOut.map { CGRect(x: $0.minX + M.boxInset, y: boxY, width: boxSize, height: boxSize) }
        closeBoxes = closes
        let close = closes[front]
        let zoom = style == .document
            ? CGRect(x: tab.maxX - M.boxInset - boxSize, y: boxY, width: boxSize, height: boxSize)
            : nil
        closeBox = close
        zoomBox = zoom
        titles = laidOut.enumerated().map { i, rect in
            let left = closes[i].maxX + M.titleGap
            let right = (i == front ? zoom?.minX ?? rect.maxX : rect.maxX) - M.titleGap
            return CGRect(x: left, y: rect.minY, width: max(0, right - left), height: rect.height)
        }

        if isCollapsed {
            body = .zero
            content = .zero
        } else {
            body = CGRect(x: bounds.minX, y: bounds.minY + tabHeight, width: bounds.width,
                          height: max(0, bounds.height - tabHeight))
            let frame = style == .utility ? 2 : M.frameWidth
            content = body.insetBy(dx: frame, dy: frame)
        }

        if style == .document, !isCollapsed {
            let side = M.scrollBarWidth
            let grow = CGRect(x: content.maxX - side, y: content.maxY - side, width: side, height: side)
            growBox = grow
            scrollBar = CGRect(x: grow.minX, y: content.minY, width: side, height: max(0, grow.minY - content.minY))
            main = CGRect(x: content.minX, y: content.minY, width: max(0, grow.minX - content.minX),
                          height: content.height)
        } else {
            growBox = nil
            scrollBar = nil
            main = content
        }
    }

    /// The width the tabs take, for sliding them.
    public var tabsWidth: CGFloat { (tabs.last?.maxX ?? 0) - (tabs.first?.minX ?? 0) }

    /// The tab whose close box is under `point`, if any.
    public func closeBox(at point: CGPoint) -> Int? {
        closeBoxes.firstIndex { $0.contains(point) }
    }

    /// The tab under `point`, if any.
    public func tab(at point: CGPoint) -> Int? {
        tabs.firstIndex { $0.contains(point) }
    }
}
