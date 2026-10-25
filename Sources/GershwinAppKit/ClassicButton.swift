import AppKit
import GershwinChrome

/// A push button in the theme's style: Mac OS 8 and 9's rounded, bevelled face; System 1 to 7's white round-rect,
/// inverted while pressed; or BeOS's bevelled grey. The default button (the one Return presses) wears the era's thick
/// ring. It tracks the mouse as the Toolbox did: pressed while the mouse is inside, pressed on release inside.
@MainActor
public final class ClassicButton: NSView {
    public var title: String { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    public var theme: ClassicTheme { didSet { invalidateIntrinsicContentSize(); needsLayout = true; needsDisplay = true } }
    public var isDefault: Bool { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    public var onPress: (() -> Void)?

    private var isPressed = false { didSet { needsDisplay = true } }

    /// Sizes in Mac OS 9 pixels.
    private enum Metrics {
        static let height: CGFloat = 20
        static let padding: CGFloat = 14
        static let minimumWidth: CGFloat = 58
        /// Room for the default button's ring, on each side.
        static let ring: CGFloat = 4
    }

    public init(title: String, isDefault: Bool = false, theme: ClassicTheme, onPress: (() -> Void)? = nil) {
        self.title = title
        self.isDefault = isDefault
        self.theme = theme
        self.onPress = onPress
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var isFlipped: Bool { true }
    private var style: MenuStyle { MenuStyle(theme.chrome) }
    private var font: NSFont { theme.font(size: 12) }

    /// Always room for the ring, so buttons line up whichever is the default.
    public override var intrinsicContentSize: NSSize {
        let text = theme.textWidth(title, font: font)
        let width = max(Metrics.minimumWidth, ceil(text) + Metrics.padding * 2) + Metrics.ring * 2
        return NSSize(width: width * theme.scale, height: (Metrics.height + Metrics.ring * 2) * theme.scale)
    }

    public override func layout() {
        super.layout()
        setClassicBounds(scale: theme.scale)
    }

    public override func draw(_ dirtyRect: NSRect) {
        let t = theme
        let face = bounds.insetBy(dx: Metrics.ring, dy: Metrics.ring)
        if t.isAqua {
            // Aqua's capsule of gel: white, or blue for the default button. No ring: the colour says which it is.
            t.drawAquaButton(face, isDefault: isDefault, pressed: isPressed)
            return t.drawText(title, in: face, font: font, color: t.text, alignment: .center)
        }
        let ink: NSColor
        switch style {
        case .platinum:
            let shape = NSBezierPath(roundedRect: face.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            (isPressed ? t.well : t.background).setFill()
            shape.fill()
            let inner = NSBezierPath(roundedRect: face.insetBy(dx: 1.5, dy: 1.5), xRadius: 3, yRadius: 3)
            (isPressed ? t.dark : t.light).setStroke()
            inner.lineWidth = 1
            inner.stroke()
            t.border.setStroke()
            shape.lineWidth = 1
            shape.stroke()
            if isDefault {
                let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 7, yRadius: 7)
                ring.lineWidth = 3
                t.border.setStroke()
                ring.stroke()
            }
            ink = t.text
        case .classic:
            let shape = NSBezierPath(roundedRect: face.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
            (isPressed ? t.border : t.light).setFill()
            shape.fill()
            t.border.setStroke()
            shape.lineWidth = 1
            shape.stroke()
            if isDefault {
                let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 11, yRadius: 11)
                ring.lineWidth = 3
                ring.stroke()
            }
            ink = isPressed ? t.light : t.text
        case .beos:
            (isPressed ? t.well : t.background).setFill()
            face.fill()
            t.drawOutline(face)
            if isPressed { t.drawSunkenBevel(face.insetBy(dx: 1, dy: 1)) } else { t.drawRaisedBevel(face.insetBy(dx: 1, dy: 1)) }
            if isDefault {
                // BeOS's default button: a second, darker frame around the first.
                t.drawOutline(face.insetBy(dx: -2, dy: -2), color: t.dark)
                t.drawOutline(face.insetBy(dx: -3, dy: -3))
            }
            ink = t.text
        }
        t.drawText(title, in: face, font: font, color: ink, alignment: .center)
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let face = bounds.insetBy(dx: Metrics.ring, dy: Metrics.ring)
        isPressed = true
        var inside = true
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            inside = face.contains(convert(next.locationInWindow, from: nil))
            if isPressed != inside { isPressed = inside }
            if next.type == .leftMouseUp { break }
        }
        isPressed = false
        if inside { onPress?() }
    }

    public override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }

    /// Shows the button pressed for a moment, then presses it: what Return does to the default button.
    public func flashAndPress() {
        isPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isPressed = false
            self?.onPress?()
        }
    }
}
