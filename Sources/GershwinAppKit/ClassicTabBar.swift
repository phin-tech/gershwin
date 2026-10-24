import AppKit
import GershwinChrome

/// A row of tabs, drawn in its appearance's era (TabStyle): Mac OS 8 and 9's Appearance Manager tabs, or the
/// file-folder tabs apps drew before it. The front tab has no bottom edge, so it reads as the page it opens onto: in a
/// document window it's filled with the content's colour, and in a dialog's tab control (`opensOntoPanel`) with the
/// window's, like the panel below it.
///
/// It draws in Mac OS 9 pixels: inside a window's frame, which is scaled already, as they are; anywhere else, scaled
/// by its theme.
@MainActor
public final class ClassicTabBar: NSView {
    public var theme: ClassicTheme { didSet { needsDisplay = true } }
    public var titles: [String] = [] { didSet { if titles != oldValue { needsDisplay = true } } }
    public var selectedIndex: Int? { didSet { if selectedIndex != oldValue { needsDisplay = true } } }

    /// A click on a tab.
    public var onSelect: ((Int) -> Void)?
    /// A double-click on the bar beside the tabs.
    public var onNewTab: (() -> Void)?

    /// The front tab opens onto a panel in the window's colour (a dialog's tabs), not the content's.
    public var opensOntoPanel = false { didSet { needsDisplay = true } }

    public init(theme: ClassicTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.tabGroup)
    }

    public override func layout() {
        super.layout()
        setClassicBounds(scale: theme.scale)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var isFlipped: Bool { true }
    public override var isOpaque: Bool { true }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var font: NSFont { theme.font(size: 12) }

    /// The tabs' rects, as FanfareKit lays them out, inside the bar's bottom edge.
    var tabRects: [CGRect] {
        let strip = CGRect(x: bounds.minX, y: bounds.minY + 2, width: bounds.width, height: bounds.height - 2)
        return TabStripLayout.tabs(in: strip, titleWidths: titles.map { theme.textWidth($0, font: font) })
    }

    // MARK: Drawing

    public override func draw(_ dirtyRect: NSRect) {
        let t = theme
        t.background.setFill()
        bounds.fill()
        let rects = tabRects
        let baseline = bounds.maxY - 1

        NSGraphicsContext.current?.shouldAntialias = t.chrome.tabStyle == .appearanceManager
        // Back tabs first, then the front one over them.
        for (i, rect) in rects.enumerated() where i != selectedIndex {
            drawTab(rect, title: titles[i], front: false)
        }
        // The edge the tabs stand on, broken under the front tab.
        t.border.setFill()
        let front = selectedIndex.flatMap { rects.indices.contains($0) ? rects[$0] : nil }
        if let front {
            NSRect(x: bounds.minX, y: baseline, width: front.minX - bounds.minX + 1, height: 1).fill()
            NSRect(x: front.maxX - 1, y: baseline, width: bounds.maxX - front.maxX + 1, height: 1).fill()
            drawTab(front, title: titles[selectedIndex!], front: true)
        } else {
            NSRect(x: bounds.minX, y: baseline, width: bounds.width, height: 1).fill()
        }
        NSGraphicsContext.current?.shouldAntialias = true
    }

    private func drawTab(_ rect: CGRect, title: String, front: Bool) {
        let t = theme
        // Back tabs stand a little lower; the front one reaches the top and covers the edge below it.
        let top = rect.minY + (front ? 0 : 2)
        let bottom = rect.maxY - (front ? 0 : 1)
        let shape = outline(of: rect, top: top, bottom: bottom)

        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        if front {
            (opensOntoPanel ? t.background : NSColor(t.palette.content)).setFill()
            rect.fill()
        } else if t.chrome.tabStyle == .folder {
            t.fillWell(rect)
        } else {
            t.well.setFill()
            rect.fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        if t.chrome.tabStyle == .appearanceManager {
            // The bevel just inside the outline: light up the left and across the top, dark down the right.
            let inner = outline(of: rect.insetBy(dx: 1, dy: 0), top: top + 1, bottom: bottom, closed: false)
            inner.lineWidth = 1
            t.light.setStroke()
            inner.stroke()
            t.dark.setFill()
            NSRect(x: rect.maxX - 2, y: top + 4, width: 1, height: bottom - top - 4).fill()
        }
        t.border.setStroke()
        let edge = outline(of: rect, top: top, bottom: bottom, closed: false)
        edge.lineWidth = 1
        edge.stroke()

        let textColor = front && !opensOntoPanel ? NSColor(t.palette.contentText) : t.text
        let label = CGRect(x: rect.minX + TabStripLayout.padding / 2, y: top + 1,
                           width: rect.width - TabStripLayout.padding, height: bottom - top - 1)
        if !front, t.palette.dithersWells {
            // Text over a dither can't be read; one-bit Macs cleared a box behind it.
            let width = min(label.width, t.textWidth(title, font: font) + 6)
            let height = ceil(font.ascender - font.descender)
            t.background.setFill()
            NSRect(x: (label.midX - width / 2).rounded(), y: (label.midY - height / 2).rounded(),
                   width: width.rounded(), height: height).fill()
        }
        t.drawText(title, in: label, font: font, color: textColor, alignment: .center)
    }

    /// A tab's shape, open at the bottom. Rounded at the top for the Appearance Manager; slanted sides for a folder.
    private func outline(of rect: CGRect, top: CGFloat, bottom: CGFloat, closed: Bool = true) -> NSBezierPath {
        let path = NSBezierPath()
        // Half-point offsets put one-point strokes on whole pixels.
        let left = rect.minX + 0.5, right = rect.maxX - 0.5, topY = top + 0.5, bottomY = bottom
        switch theme.chrome.tabStyle {
        case .appearanceManager:
            let r: CGFloat = 4
            path.move(to: NSPoint(x: left, y: bottomY))
            path.line(to: NSPoint(x: left, y: topY + r))
            path.appendArc(withCenter: NSPoint(x: left + r, y: topY + r), radius: r, startAngle: 180, endAngle: 270)
            path.line(to: NSPoint(x: right - r, y: topY))
            path.appendArc(withCenter: NSPoint(x: right - r, y: topY + r), radius: r, startAngle: 270, endAngle: 360)
            path.line(to: NSPoint(x: right, y: bottomY))
        case .folder:
            let slant = min(8, (bottomY - topY) / 2)
            path.move(to: NSPoint(x: left, y: bottomY))
            path.line(to: NSPoint(x: left + slant, y: topY))
            path.line(to: NSPoint(x: right - slant, y: topY))
            path.line(to: NSPoint(x: right, y: bottomY))
        }
        if closed { path.close() }
        return path
    }

    // MARK: Mouse

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = TabStripLayout.index(at: point, in: tabRects) {
            onSelect?(index)
        } else if event.clickCount == 2 {
            onNewTab?()
        }
    }
}
