import CoreGraphics

/// The sizes of an Amiga Workbench window's parts, in points, as Workbench 2.0 and 3.1 drew them (taller than on an
/// Amiga's own screen, whose pixels were twice as tall as wide).
public enum AmigaMetrics {
    public static func titleBarHeight(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 12 : 16 }
    /// The close gadget, at the left of the drag bar.
    public static func closeWidth(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 14 : 20 }
    /// The zoom and depth gadgets, at its right.
    public static func gadgetWidth(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 16 : 22 }
    /// The border at the left and bottom.
    public static let border: CGFloat = 4
    /// The right border of a document, which holds its scroll bar, and the size gadget below it.
    public static let rightBorder: CGFloat = 18
    public static let sizeGadgetHeight: CGFloat = 10
    /// A collapsed window (Window ▸ Collapse; Workbench had none): its title bar.
    public static func collapsedHeight(for style: ClassicWindowStyle) -> CGFloat { titleBarHeight(for: style) + 1 }
}

/// Where each part of an Amiga Workbench window goes, for a window of a given size. Flipped coordinates.
///
/// The title bar is the drag bar: the close gadget at its left, then the title, then the zoom and depth gadgets at
/// its right. A document's right border holds its scroll bar, the arrows together at its bottom, and the size gadget
/// in the corner below them; the left and bottom borders are thin.
public struct AmigaChromeLayout: Equatable, Sendable {
    public let bounds: CGRect
    public let style: ClassicWindowStyle
    public let isCollapsed: Bool

    public let titleBar: CGRect
    public let closeGadget: CGRect
    /// Documents only.
    public let zoomGadget: CGRect?
    public let depthGadget: CGRect
    public let content: CGRect
    public let tabBar: CGRect?
    public let main: CGRect
    public let scrollBar: CGRect?
    public let sizeGadget: CGRect?

    public init(bounds: CGRect, style: ClassicWindowStyle, isCollapsed: Bool = false, showsTabBar: Bool = false) {
        typealias M = AmigaMetrics
        self.bounds = bounds
        self.style = style
        self.isCollapsed = isCollapsed
        let height = M.titleBarHeight(for: style)
        titleBar = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: height)
        closeGadget = CGRect(x: bounds.minX, y: bounds.minY, width: M.closeWidth(for: style), height: height)
        let gadget = M.gadgetWidth(for: style)
        depthGadget = CGRect(x: bounds.maxX - gadget, y: bounds.minY, width: gadget, height: height)
        zoomGadget = style == .document ? depthGadget.offsetBy(dx: -gadget, dy: 0) : nil

        let document = style == .document
        let right = document ? M.rightBorder : M.border
        content = isCollapsed ? .zero
            : CGRect(x: bounds.minX + M.border, y: titleBar.maxY, width: max(0, bounds.width - M.border - right),
                     height: max(0, bounds.maxY - M.border - titleBar.maxY))
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
        main = below
        if document, !isCollapsed {
            let size = CGRect(x: bounds.maxX - M.rightBorder, y: bounds.maxY - M.sizeGadgetHeight,
                              width: M.rightBorder, height: M.sizeGadgetHeight)
            sizeGadget = size
            scrollBar = CGRect(x: size.minX + 1, y: below.minY, width: M.rightBorder - 2,
                               height: max(0, size.minY - below.minY))
        } else {
            sizeGadget = nil
            scrollBar = nil
        }
    }

    /// The title, left-aligned after the close gadget, kept clear of the gadgets at the right.
    public func titleRect(textWidth: CGFloat, textHeight: CGFloat) -> CGRect {
        let left = closeGadget.maxX + 4
        let right = (zoomGadget ?? depthGadget).minX - 4
        return CGRect(x: left, y: titleBar.midY - textHeight / 2, width: min(textWidth, max(0, right - left)),
                      height: textHeight)
    }
}
