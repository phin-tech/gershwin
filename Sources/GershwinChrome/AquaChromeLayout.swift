import CoreGraphics

/// The sizes of an Aqua window's parts, in points, as Mac OS X 10.2 and 10.3 drew them. Everything else is laid out
/// as a Platinum window is (WindowChromeLayout, `aqua`).
public enum AquaMetrics {
    public static func titleBarHeight(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 16 : 22 }
    /// The close, minimize and zoom buttons: circles this wide.
    public static func buttonSize(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 10 : 14 }
    /// From the window's left edge to the close button.
    public static func buttonInset(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 5 : 8 }
    /// Between one button and the next.
    public static func buttonGap(for style: ClassicWindowStyle) -> CGFloat { style == .utility ? 4 : 7 }
    /// The radius of a window's top corners.
    public static let cornerRadius: CGFloat = 5
    /// The pinstripes: a stripe this many pixels tall, then a lighter one.
    public static let pinstripe: CGFloat = 2
}
