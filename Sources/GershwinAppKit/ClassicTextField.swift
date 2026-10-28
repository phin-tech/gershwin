import AppKit
import GershwinChrome

/// An edit-text field in the theme's style, with the keyboard focus shown as its era did: Mac OS 8 and 9's sunken
/// white box with a two-pixel ring in the highlight colour around it while it has the focus (in the front window
/// only); System 7's plain black box, whose only sign of focus is the blinking caret; BeOS's sunken box, outlined in
/// blue while it has the focus. The text is an NSTextField's, so editing, the selection, undo and accessibility are
/// AppKit's own.
@MainActor
public final class ClassicTextField: NSView, NSTextFieldDelegate {
    public var theme: ClassicTheme {
        didSet {
            applyTheme()
            invalidateIntrinsicContentSize()
            needsLayout = true
            needsDisplay = true
        }
    }

    public var stringValue: String {
        get { field.stringValue }
        set { if field.stringValue != newValue { field.stringValue = newValue } }
    }

    public var placeholder: String? {
        didSet { applyTheme() }
    }

    /// Takes the keyboard focus once it's in a window, as a dialog's first field did.
    public var focusesOnAppear = false

    /// Told on each edit, with the new text.
    public var onChange: ((String) -> Void)?
    /// Return (with the shift key's state, for "the one before"), and Esc.
    public var onSubmit: ((_ shift: Bool) -> Void)?
    public var onCancel: (() -> Void)?
    /// ↑ (-1) and ↓ (1), for a field that sits over a list, as a search box does. Without it the arrows move the caret.
    public var onMove: ((_ step: Int) -> Void)?
    /// ⌫ with nothing in the field, for a search box that goes back a level when there's nothing left to delete.
    public var onDeleteWhenEmpty: (() -> Void)?

    /// The NSTextField that holds the text, for its first-responder status and accessibility.
    public let field: NSTextField = FocusReportingField()

    /// Whether the field has the keyboard focus (the field editor is editing it).
    public private(set) var isFocused = false {
        didSet { if isFocused != oldValue { needsDisplay = true } }
    }

    /// Sizes in Mac OS 9 pixels.
    private enum Metrics {
        /// Room around the box for the focus ring.
        static let ring: CGFloat = 3
        static let boxHeight: CGFloat = 18
        static let textInset: CGFloat = 4
    }

    public init(theme: ClassicTheme) {
        self.theme = theme
        super.init(frame: .zero)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        // One line, by not wrapping. Not usesSingleLineMode: it places the text by the font's bounding box, which for
        // Geneva is twice its size, and draws it half a line too high.
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.delegate = self
        (field as? FocusReportingField)?.onFocus = { [weak self] in self?.focusChanged(true) }
        addSubview(field)
        applyTheme()
        NotificationCenter.default.addObserver(self, selector: #selector(editingEnded),
                                               name: NSControl.textDidEndEditingNotification, object: field)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: (Metrics.boxHeight + Metrics.ring * 2) * theme.scale)
    }

    public override var acceptsFirstResponder: Bool { true }

    /// Giving this the focus gives it to the text.
    public override func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(field) ?? false
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            center.removeObserver(self, name: name, object: nil)
            if let newWindow {
                center.addObserver(self, selector: #selector(keyChanged), name: name, object: newWindow)
            }
        }
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard focusesOnAppear, window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self.field)
        }
    }

    @objc private func keyChanged() { needsDisplay = true }

    private func applyTheme() {
        let p = theme.palette
        field.font = ClassicTheme.smallFont(size: 12 * theme.scale)
        field.textColor = NSColor(p.contentText)
        if let placeholder {
            field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
                .font: ClassicTheme.smallFont(size: 12 * theme.scale), .foregroundColor: NSColor(p.disabledText)])
        } else {
            field.placeholderAttributedString = nil
        }
        (field.currentEditor() as? NSTextView)?.insertionPointColor = NSColor(p.contentText)
    }

    private var box: NSRect {
        let s = theme.scale
        return NSRect(x: Metrics.ring * s, y: (bounds.height - Metrics.boxHeight * s) / 2,
                      width: max(0, bounds.width - Metrics.ring * 2 * s), height: Metrics.boxHeight * s)
    }

    public override func layout() {
        super.layout()
        let s = theme.scale
        let inner = box.insetBy(dx: Metrics.textInset * s, dy: 0)
        let height = field.intrinsicContentSize.height
        field.frame = NSRect(x: inner.minX, y: (inner.midY - height / 2).rounded(), width: inner.width, height: height)
    }

    // MARK: Focus

    private func focusChanged(_ focused: Bool) {
        isFocused = focused
        if focused {
            (field.currentEditor() as? NSTextView)?.insertionPointColor = NSColor(theme.palette.contentText)
        }
    }

    @objc private func editingEnded() { focusChanged(false) }

    /// Draws the focus as if the field had it in the key window, for galleries and tests.
    public var drawsFocus = false { didSet { needsDisplay = true } }

    /// The ring shows while the field has the focus in the key window, as the Appearance Manager drew it.
    private var showsFocus: Bool { drawsFocus || (isFocused && (window?.isKeyWindow ?? false)) }

    // MARK: Drawing

    public override var isFlipped: Bool { true }

    public override func draw(_ dirtyRect: NSRect) {
        let t = theme, p = t.palette, s = t.scale
        let box = box
        func band(_ rect: NSRect, width: CGFloat, _ color: NSColor) {
            color.setFill()
            let path = NSBezierPath(rect: rect)
            path.append(NSBezierPath(rect: rect.insetBy(dx: width, dy: width)))
            path.windingRule = .evenOdd
            path.fill()
        }
        func sunken(_ rect: NSRect) {
            // Dark along the top and left, light along the bottom and right.
            t.dark.setFill()
            NSRect(x: rect.minX, y: rect.minY, width: rect.width - s, height: s).fill()
            NSRect(x: rect.minX, y: rect.minY, width: s, height: rect.height - s).fill()
            t.light.setFill()
            NSRect(x: rect.minX + s, y: rect.maxY - s, width: rect.width - s, height: s).fill()
            NSRect(x: rect.maxX - s, y: rect.minY + s, width: s, height: rect.height - s).fill()
        }
        switch MenuStyle(t.chrome) {
        case .platinum:
            if showsFocus { band(box.insetBy(dx: -2 * s, dy: -2 * s), width: 2 * s, t.highlight) }
            sunken(box)
            band(box.insetBy(dx: s, dy: s), width: s, t.border)
            NSColor(p.content).setFill()
            box.insetBy(dx: 2 * s, dy: 2 * s).fill()
        case .classic:
            band(box, width: s, t.border)
            NSColor(p.content).setFill()
            box.insetBy(dx: s, dy: s).fill()
        case .beos:
            sunken(box)
            NSColor(p.content).setFill()
            box.insetBy(dx: s, dy: s).fill()
            if showsFocus {
                band(box.insetBy(dx: s, dy: s), width: s, NSColor(srgbRed: 0.31, green: 0.5, blue: 0.85, alpha: 1))
            }
        }
    }

    // MARK: NSTextFieldDelegate

    public func controlTextDidChange(_ notification: Notification) {
        onChange?(field.stringValue)
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            guard let onSubmit else { return false }
            onSubmit(NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            guard let onCancel else { return false }
            onCancel()
            return true
        case #selector(NSResponder.deleteBackward(_:)):
            guard let onDeleteWhenEmpty, textView.string.isEmpty else { return false }
            onDeleteWhenEmpty()
            return true
        case #selector(NSResponder.moveUp(_:)):
            guard let onMove else { return false }
            onMove(-1)
            return true
        case #selector(NSResponder.moveDown(_:)):
            guard let onMove else { return false }
            onMove(1)
            return true
        default:
            return false
        }
    }
}

/// An NSTextField that says when it takes the focus; the end of editing says when it loses it.
private final class FocusReportingField: NSTextField {
    var onFocus: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { onFocus?() }
        return became
    }
}
