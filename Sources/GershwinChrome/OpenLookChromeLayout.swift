import CoreGraphics

/// The sizes of an OPEN LOOK window's parts, in points, as OpenWindows drew them.
public enum OpenLookMetrics {
    /// The border, which the resize corners sit in.
    public static func border(for style: ClassicWindowStyle) -> CGFloat { style == .document ? 5 : 3 }
    public static func headerHeight(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 15 : 20 }
    /// The window menu button (and a pop-up's pushpin), a square.
    public static func buttonSize(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 10 : 13 }
    /// Each arm of a resize corner's L.
    public static let cornerArm: CGFloat = 14
    public static let scrollBarWidth: CGFloat = 16
    public static func collapsedHeight(for style: ClassicWindowStyle) -> CGFloat {
        headerHeight(for: style) + border(for: style) * 2
    }
}

/// Where each part of an OPEN LOOK window goes, for a window of a given size. Flipped coordinates.
///
/// A border with an L-shaped resize corner at each corner; inside it the header, the title centred, with the window
/// menu button at its left (a pop-up has a pushpin there instead: pulled out, it goes); then the content, with an
/// elevator scroll bar along its right. There are no other boxes: the window menu closes, sizes and backs the window.
public struct OpenLookChromeLayout: Equatable, Sendable {
    public let bounds: CGRect
    public let style: ClassicWindowStyle
    public let isCollapsed: Bool

    public let header: CGRect
    /// The window menu button, or for a pop-up (a panel, a palette) its pushpin.
    public let button: CGRect
    /// Top left, top right, bottom left, bottom right: each the square its L fills two sides of. None on a pop-up.
    public let corners: [CGRect]
    public let content: CGRect
    public let tabBar: CGRect?
    public let main: CGRect
    public let scrollBar: CGRect?

    public var hasPushpin: Bool { style != .document }

    public init(bounds: CGRect, style: ClassicWindowStyle, isCollapsed: Bool = false, showsTabBar: Bool = false) {
        typealias M = OpenLookMetrics
        self.bounds = bounds
        self.style = style
        self.isCollapsed = isCollapsed
        let b = M.border(for: style)
        header = CGRect(x: bounds.minX + b, y: bounds.minY + b, width: max(0, bounds.width - b * 2),
                        height: M.headerHeight(for: style))
        let size = M.buttonSize(for: style)
        button = CGRect(x: header.minX + 4, y: (header.midY - size / 2).rounded(.down), width: size, height: size)
        let arm = M.cornerArm
        corners = style == .document && !isCollapsed ? [
            CGRect(x: bounds.minX, y: bounds.minY, width: arm, height: arm),
            CGRect(x: bounds.maxX - arm, y: bounds.minY, width: arm, height: arm),
            CGRect(x: bounds.minX, y: bounds.maxY - arm, width: arm, height: arm),
            CGRect(x: bounds.maxX - arm, y: bounds.maxY - arm, width: arm, height: arm),
        ] : []
        content = isCollapsed ? .zero
            : CGRect(x: header.minX, y: header.maxY + 1, width: header.width,
                     height: max(0, bounds.maxY - b - header.maxY - 1))
        let below: CGRect
        if showsTabBar, !isCollapsed {
            let bar = CGRect(x: content.minX, y: content.minY, width: content.width,
                             height: min(ChromeMetrics.tabBarHeight, content.height))
            tabBar = bar
            below = CGRect(x: content.minX, y: bar.maxY, width: content.width, height: content.maxY - bar.maxY)
        } else {
            tabBar = nil
            below = content
        }
        if style == .document, !isCollapsed {
            let side = M.scrollBarWidth
            scrollBar = CGRect(x: below.maxX - side, y: below.minY, width: side, height: below.height)
            main = CGRect(x: below.minX, y: below.minY, width: max(0, below.width - side), height: below.height)
        } else {
            scrollBar = nil
            main = below
        }
    }

    /// The title, centred in the header, clear of the button.
    public func titleRect(textWidth: CGFloat, textHeight: CGFloat) -> CGRect {
        let left = button.maxX + 6, right = header.maxX - (button.maxX - header.minX) - 6
        let width = min(textWidth, max(0, right - left))
        let x = min(max(header.midX - width / 2, left), right - width)
        return CGRect(x: x, y: header.midY - textHeight / 2, width: width, height: textHeight)
    }

    /// Which resize corner `point` is in, if any (an index into `corners`).
    public func corner(at point: CGPoint) -> Int? {
        corners.firstIndex { $0.contains(point) && !content.insetBy(dx: 1, dy: 1).contains(point) }
    }
}
