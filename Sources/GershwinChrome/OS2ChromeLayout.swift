import CoreGraphics

/// The sizes of an OS/2 Warp window's parts, in points, as Warp 4 drew them at its default resolution.
public enum OS2Metrics {
    /// The sizing border around the whole window: drag it anywhere to resize. Thinner on a dialog and a palette.
    public static func frameWidth(for style: ClassicWindowStyle) -> CGFloat {
        switch style {
        case .document: 4
        case .panel: 3
        case .utility: 2
        }
    }

    public static func titleBarHeight(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 14 : 20 }
    /// The title bar's buttons are squares, a pixel short of the title bar at each end.
    public static func buttonSize(for style: ClassicWindowStyle) -> CGFloat { titleBarHeight(for: style) - 2 }
    /// Between the hide and maximize buttons and the close button.
    public static let closeGap: CGFloat = 2
    public static let scrollBarWidth: CGFloat = 16
    /// A collapsed window (which OS/2 never had; Window ▸ Collapse still works): its title bar in its frame.
    public static func collapsedHeight(for style: ClassicWindowStyle) -> CGFloat {
        titleBarHeight(for: style) + frameWidth(for: style) * 2
    }
}

/// Where each part of an OS/2 Warp window goes, for a window of a given size. Flipped coordinates.
///
/// A sizing border all round; inside it the title bar, with the system menu button (the window's icon, which opens its
/// menu) at the left, the title centred, and the hide, maximize and close buttons at the right; then the content, with
/// a scroll bar the whole height of its right side. There is no grow box: the border resizes the window.
public struct OS2ChromeLayout: Equatable, Sendable {
    public let bounds: CGRect
    public let style: ClassicWindowStyle
    public let isCollapsed: Bool

    public let titleBar: CGRect
    public let systemMenu: CGRect
    /// Documents only: Warp 4's hide (minimize) and maximize buttons.
    public let hideButton: CGRect?
    public let maximizeButton: CGRect?
    public let closeButton: CGRect
    /// Inside the frame, below the title bar. Empty when collapsed.
    public let content: CGRect
    public let tabBar: CGRect?
    public let main: CGRect
    public let scrollBar: CGRect?

    public init(bounds: CGRect, style: ClassicWindowStyle, isCollapsed: Bool = false, showsTabBar: Bool = false) {
        typealias M = OS2Metrics
        self.bounds = bounds
        self.style = style
        self.isCollapsed = isCollapsed
        let frame = M.frameWidth(for: style)
        titleBar = CGRect(x: bounds.minX + frame, y: bounds.minY + frame,
                          width: max(0, bounds.width - frame * 2), height: M.titleBarHeight(for: style))
        let size = M.buttonSize(for: style)
        let y = titleBar.minY + 1
        systemMenu = CGRect(x: titleBar.minX + 1, y: y, width: size, height: size)
        let close = CGRect(x: titleBar.maxX - 1 - size, y: y, width: size, height: size)
        closeButton = close
        if style == .document {
            let maximize = close.offsetBy(dx: -(size + M.closeGap), dy: 0)
            maximizeButton = maximize
            hideButton = maximize.offsetBy(dx: -size, dy: 0)
        } else {
            maximizeButton = nil
            hideButton = nil
        }

        content = isCollapsed ? .zero
            : CGRect(x: titleBar.minX, y: titleBar.maxY, width: titleBar.width,
                     height: max(0, bounds.maxY - frame - titleBar.maxY))
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

    /// The buttons at the right of the title bar, left to right.
    public var buttons: [CGRect] { [hideButton, maximizeButton, closeButton].compactMap { $0 } }

    /// Where a title `textWidth` wide goes: centred in the title bar, kept clear of the buttons either side.
    public func titleRect(textWidth: CGFloat, textHeight: CGFloat) -> CGRect {
        let left = systemMenu.maxX + 6
        let right = (buttons.first?.minX ?? closeButton.minX) - 6
        let width = min(textWidth, max(0, right - left))
        let x = min(max(titleBar.midX - width / 2, left), right - width)
        return CGRect(x: x, y: titleBar.midY - textHeight / 2, width: width, height: textHeight)
    }
}
