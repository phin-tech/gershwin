import AppKit
import GershwinChrome

/// A pop-up menu button in the theme's style: Mac OS 8 and 9's rounded, bevelled button with its arrow box; System
/// 7's white box with a drop shadow; or BeOS's bevelled field. Clicking it opens a ClassicMenu of its choices with the
/// current one over the button, where the mouse is, as the classic pop-up did.
@MainActor
public final class ClassicPopUpButton: NSView {
    public var theme: ClassicTheme {
        didSet {
            invalidateIntrinsicContentSize()
            needsLayout = true
            needsDisplay = true
        }
    }

    public var titles: [String] {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    public var selectedIndex: Int {
        didSet {
            needsDisplay = true
            setAccessibilityValue(selectedTitle)
        }
    }

    /// Told when the user chooses a different item.
    public var onChange: ((Int) -> Void)?

    private var isOpen = false {
        didSet { needsDisplay = true }
    }

    /// Sizes in Mac OS 9 pixels.
    private enum Metrics {
        static let height: CGFloat = 20
        static let textInset: CGFloat = 8
        static let arrowWidth: CGFloat = 18
        /// Where a menu row's text starts (ClassicMenu's gutter), to line the menu's text up with the button's.
        static let menuGutter: CGFloat = 20
    }

    public init(titles: [String], selectedIndex: Int = 0, theme: ClassicTheme) {
        self.titles = titles
        self.selectedIndex = selectedIndex
        self.theme = theme
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.popUpButton)
        setAccessibilityValue(selectedTitle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }

    private var selectedTitle: String { titles.indices.contains(selectedIndex) ? titles[selectedIndex] : "" }
    private var font: NSFont { theme.font(size: 12) }
    private var style: MenuStyle { MenuStyle(theme.chrome) }

    public override var intrinsicContentSize: NSSize {
        let widest = titles.map { theme.textWidth($0, font: font) }.max() ?? 0
        let width = Metrics.textInset + widest + Metrics.textInset + Metrics.arrowWidth + 2
        return NSSize(width: ceil(width) * theme.scale, height: (Metrics.height + 1) * theme.scale)
    }

    public override func layout() {
        super.layout()
        setClassicBounds(scale: theme.scale)
    }

    // MARK: Drawing

    public override func draw(_ dirtyRect: NSRect) {
        let t = theme
        let box = NSRect(x: 0, y: 0, width: floor(bounds.width) - 1, height: Metrics.height)
        let arrowBox = NSRect(x: box.maxX - Metrics.arrowWidth, y: box.minY, width: Metrics.arrowWidth, height: box.height)
        switch style {
        case .platinum:
            let shape = NSBezierPath(roundedRect: box.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            (isOpen ? t.well : t.background).setFill()
            shape.fill()
            // A bevel inside the outline, light up and left, dark down and right, and the arrow box set off.
            let inner = NSBezierPath(roundedRect: box.insetBy(dx: 1.5, dy: 1.5), xRadius: 3, yRadius: 3)
            (isOpen ? t.dark : t.light).setStroke()
            inner.lineWidth = 1
            inner.stroke()
            t.dark.setFill()
            NSRect(x: arrowBox.minX, y: box.minY + 3, width: 1, height: box.height - 6).fill()
            t.light.setFill()
            NSRect(x: arrowBox.minX + 1, y: box.minY + 3, width: 1, height: box.height - 6).fill()
            t.border.setStroke()
            shape.lineWidth = 1
            shape.stroke()
        case .classic:
            t.border.setFill()
            box.offsetBy(dx: 1, dy: 1).fill()
            (isOpen ? t.border : t.light).setFill()
            box.fill()
            t.drawOutline(box)
        case .beos:
            (isOpen ? t.well : t.background).setFill()
            box.fill()
            t.drawOutline(box)
            if isOpen { t.drawSunkenBevel(box.insetBy(dx: 1, dy: 1)) } else { t.drawRaisedBevel(box.insetBy(dx: 1, dy: 1)) }
        }

        let ink: NSColor = style == .classic && isOpen ? t.light : t.text
        drawArrow(in: arrowBox, color: ink)
        let text = NSRect(x: Metrics.textInset, y: box.minY, width: arrowBox.minX - Metrics.textInset * 2,
                          height: box.height)
        t.drawText(selectedTitle, in: text, font: font, color: ink)
    }

    /// A solid triangle pointing down, seven wide, drawn a row at a time so it stays crisp.
    private func drawArrow(in rect: NSRect, color: NSColor) {
        color.setFill()
        let midX = rect.midX.rounded(.down)
        let top = (rect.midY - 2).rounded(.down)
        for row in 0..<4 {
            let half = CGFloat(3 - row)
            NSRect(x: midX - half, y: top + CGFloat(row), width: half * 2 + 1, height: 1).fill()
        }
    }

    // MARK: Choosing

    public override func mouseDown(with event: NSEvent) {
        openMenu()
    }

    public override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " { openMenu() } else { super.keyDown(with: event) }
    }

    public override func accessibilityPerformPress() -> Bool {
        openMenu()
        return true
    }

    private func openMenu() {
        guard let window, !titles.isEmpty else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (index, title) in titles.enumerated() {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.tag = index
            item.state = index == selectedIndex ? .on : .off
            menu.addItem(item)
        }
        // The menu's text over the button's, and its current choice level with the button.
        let s = theme.scale
        let local = NSRect(x: (Metrics.textInset - Metrics.menuGutter) * s, y: -1 * s, width: 0, height: 0)
        let inWindow = convert(local, to: nil)
        let screen = window.convertToScreen(inWindow).origin
        isOpen = true
        defer { isOpen = false }
        guard let chosen = ClassicMenu.popUp(menu, at: screen, theme: theme, lineUp: selectedIndex,
                                             minimumWidth: frame.width + (Metrics.menuGutter - Metrics.textInset) * s),
              chosen.tag != selectedIndex else { return }
        selectedIndex = chosen.tag
        onChange?(chosen.tag)
    }
}
