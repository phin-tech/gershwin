import CoreGraphics

/// The kinds of Platinum window Fanfare draws.
public enum ClassicWindowStyle: Sendable {
    /// A terminal: close, zoom and collapse boxes, a scroll bar, a placard along the bottom and a grow box.
    case document
    /// Settings and About: a close box and a collapse box, and nothing in the frame around the content.
    case panel
    /// A floating palette: a thin title bar with small close and collapse boxes and small title text, and a thin
    /// frame (BeOS: a smaller tab).
    case utility

    var hasZoomBox: Bool { self == .document }
    var hasScrollBar: Bool { self == .document }

    /// The title bar, inside the top border.
    public var titleBarHeight: CGFloat { self == .utility ? 12 : ChromeMetrics.titleBarHeight }
    public var boxSize: CGFloat { self == .utility ? 9 : ChromeMetrics.boxSize }
    var boxInset: CGFloat { self == .utility ? 4 : ChromeMetrics.boxInset }
    var frameWidth: CGFloat { self == .utility ? 2 : ChromeMetrics.frameWidth }
    var stripeInset: CGFloat { self == .utility ? 2 : ChromeMetrics.stripeInset }
    /// A collapsed window: its title bar and border, nothing else.
    public var collapsedHeight: CGFloat { titleBarHeight + ChromeMetrics.border * 2 }
}

/// The sizes of a Platinum window's parts, in points, as Mac OS 8.5 and 9 drew them at 72 dpi.
public enum ChromeMetrics {
    /// The black outline around the whole window.
    public static let border: CGFloat = 1
    /// The title bar, inside the top border.
    public static let titleBarHeight: CGFloat = 20
    /// The grey frame on the left, right and bottom, inside the border.
    public static let frameWidth: CGFloat = 5
    /// The close, zoom and collapse boxes are squares this size.
    public static let boxSize: CGFloat = 13
    /// From the window's outer edge to the close box, and from the collapse box to the other edge.
    public static let boxInset: CGFloat = 7
    /// Between the zoom box and the collapse box.
    public static let boxGap: CGFloat = 4
    /// The grey kept clear of pinstripes around each box.
    public static let boxClearance: CGFloat = 2
    /// The grey kept clear of pinstripes either side of the title.
    public static let titleClearance: CGFloat = 6
    /// The pinstripes stop this far short of the title bar's top and bottom.
    public static let stripeInset: CGFloat = 4
    /// A scroll bar's width, and its arrows' and the grow box's sides.
    public static let scrollBarWidth: CGFloat = 16
    /// The placard along the bottom of a terminal window, beside the grow box.
    public static let placardHeight: CGFloat = 16
    /// A document's tab bar, between the title bar and the terminal, when it has more than one tab.
    public static let tabBarHeight: CGFloat = 22

    /// A collapsed window: the title bar and its border, nothing else.
    public static var collapsedHeight: CGFloat { titleBarHeight + border * 2 }
}

/// Where each part of a Platinum window goes, for a window of a given size. Coordinates are flipped: the origin is
/// the window's top-left and y grows down, as in the views that draw it.
public struct WindowChromeLayout: Equatable, Sendable {
    public let bounds: CGRect
    public let style: ClassicWindowStyle
    public let isCollapsed: Bool

    public let titleBar: CGRect
    public let closeBox: CGRect
    public let zoomBox: CGRect?
    public let collapseBox: CGRect
    /// Inside the frame: everything the window shows below its title bar. Empty when collapsed.
    public let content: CGRect
    /// Along the top of the content, when the window shows tabs.
    public let tabBar: CGRect?
    /// Where the terminal (or a panel's view) goes.
    public let main: CGRect
    public let scrollBar: CGRect?
    public let placard: CGRect?
    public let growBox: CGRect?

    public init(bounds: CGRect, style: ClassicWindowStyle, isCollapsed: Bool = false, showsTabBar: Bool = false) {
        typealias M = ChromeMetrics
        self.bounds = bounds
        self.style = style
        self.isCollapsed = isCollapsed

        titleBar = CGRect(x: bounds.minX + M.border, y: bounds.minY + M.border,
                          width: max(0, bounds.width - M.border * 2), height: style.titleBarHeight)
        let box = style.boxSize
        let boxY = (titleBar.midY - box / 2).rounded(.down)
        closeBox = CGRect(x: bounds.minX + style.boxInset, y: boxY, width: box, height: box)
        collapseBox = CGRect(x: bounds.maxX - style.boxInset - box, y: boxY, width: box, height: box)
        zoomBox = style.hasZoomBox
            ? collapseBox.offsetBy(dx: -(box + M.boxGap), dy: 0)
            : nil

        if isCollapsed {
            content = .zero
        } else {
            let top = titleBar.maxY
            let frame = style.frameWidth
            content = CGRect(x: bounds.minX + M.border + frame, y: top,
                             width: max(0, bounds.width - (M.border + frame) * 2),
                             height: max(0, bounds.maxY - M.border - frame - top))
        }

        let below: CGRect
        if showsTabBar, !isCollapsed {
            let bar = CGRect(x: content.minX, y: content.minY, width: content.width,
                             height: min(M.tabBarHeight, content.height))
            tabBar = bar
            below = CGRect(x: content.minX, y: bar.maxY, width: content.width, height: content.maxY - bar.maxY)
        } else {
            tabBar = nil
            below = content
        }

        if style.hasScrollBar, !isCollapsed {
            let side = M.scrollBarWidth
            let grow = CGRect(x: content.maxX - side, y: content.maxY - side, width: side, height: side)
            growBox = grow
            scrollBar = CGRect(x: grow.minX, y: below.minY, width: side, height: max(0, grow.minY - below.minY))
            placard = CGRect(x: content.minX, y: grow.minY, width: max(0, grow.minX - content.minX),
                             height: M.placardHeight)
            main = CGRect(x: content.minX, y: below.minY, width: max(0, grow.minX - content.minX),
                          height: max(0, grow.minY - below.minY))
        } else {
            growBox = nil
            scrollBar = nil
            placard = nil
            main = below
        }
    }

    /// The boxes the title bar shows, left to right.
    public var boxes: [CGRect] {
        [closeBox] + [zoomBox].compactMap { $0 } + [collapseBox]
    }

    /// Where a title `textWidth` wide is drawn: centred on the window, but kept clear of the boxes, and as wide as
    /// fits between them (the caller truncates the text to the rect's width).
    public func titleRect(textWidth: CGFloat, textHeight: CGFloat) -> CGRect {
        typealias M = ChromeMetrics
        let leftLimit = closeBox.maxX + M.boxClearance + M.titleClearance
        let rightLimit = (zoomBox ?? collapseBox).minX - M.boxClearance - M.titleClearance
        let available = max(0, rightLimit - leftLimit)
        let width = min(textWidth, available)
        var x = titleBar.midX - width / 2
        x = min(max(x, leftLimit), rightLimit - width)
        return CGRect(x: x, y: titleBar.midY - textHeight / 2, width: width, height: textHeight)
    }

    /// The parts of the title bar that carry pinstripes on the frontmost window: its full width, less the grey kept
    /// clear around each box and either side of the title. Each rect spans the stripes' rows; draw every other one.
    public func stripeAreas(title: CGRect) -> [CGRect] {
        typealias M = ChromeMetrics
        let top = titleBar.minY + style.stripeInset
        let height = max(0, titleBar.height - style.stripeInset * 2 + 1)
        var gaps = boxes.map { (min: $0.minX - M.boxClearance, max: $0.maxX + M.boxClearance) }
        if title.width > 0 {
            gaps.append((min: title.minX - M.titleClearance, max: title.maxX + M.titleClearance))
        }
        gaps.sort { $0.min < $1.min }

        var areas: [CGRect] = []
        var x = titleBar.minX + M.boxClearance
        let end = titleBar.maxX - M.boxClearance
        for gap in gaps {
            if gap.min > x { areas.append(CGRect(x: x, y: top, width: gap.min - x, height: height)) }
            x = max(x, gap.max)
        }
        if end > x { areas.append(CGRect(x: x, y: top, width: end - x, height: height)) }
        return areas
    }
}

/// WindowShade, from Mac OS 8: a collapsed window rolls up into its title bar, which stays where it was.
/// Frames here are in screen coordinates (y grows up), as `NSWindow` takes them.
public enum WindowShade {
    /// Rolled up to `height`: a Mac window's title bar, or a BeOS window's tab.
    public static func collapsedFrame(from frame: CGRect, height: CGFloat = ChromeMetrics.collapsedHeight) -> CGRect {
        CGRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height)
    }

    /// Unrolls a collapsed window to `height`, keeping its title bar in place.
    public static func expandedFrame(from collapsed: CGRect, height: CGFloat) -> CGRect {
        CGRect(x: collapsed.minX, y: collapsed.maxY - height, width: collapsed.width, height: height)
    }
}
