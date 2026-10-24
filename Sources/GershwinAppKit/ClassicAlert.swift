import AppKit
import GershwinChrome

/// An alert in the theme's style, run as the classic Mac ran them: app-modal, centred a third of the way down the
/// screen. Mac OS 8 and 9's has a bevelled frame and no title bar; System 1 to 7's the double border of a modal
/// dialog; BeOS's a darker band down its left side for the icon. The first button is the default (Return); a button
/// called Cancel, or the last, is Esc.
@MainActor
public final class ClassicAlert {
    public enum Icon: Sendable {
        /// A red octagon: something can't be done, or will be lost.
        case stop
        /// A yellow triangle: think before going on.
        case caution
        /// A speech balloon: for information.
        case note
    }

    public var icon: Icon
    public var message: String
    public var informativeText: String
    /// Left to right as the user reads them, the default last, as Mac OS 9 laid them out.
    public var buttons: [String]

    /// - Parameter buttons: the default first, as NSAlert takes them; they're shown the other way round.
    public init(icon: Icon = .caution, message: String, informativeText: String = "", buttons: [String] = ["OK"]) {
        self.icon = icon
        self.message = message
        self.informativeText = informativeText
        self.buttons = buttons
    }

    /// Shows the alert and waits; returns the index (in `buttons`) of the one pressed.
    public func runModal(theme: ClassicTheme) -> Int {
        let panel = AlertPanel(alert: self, theme: theme)
        panel.center()
        if let screen = panel.screen ?? NSScreen.main {
            // A third of the way down, where the Dialog Manager put alerts.
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.midX - panel.frame.width / 2,
                                         y: visible.maxY - (visible.height - panel.frame.height) / 3 - panel.frame.height))
        }
        let response = NSApp.runModal(for: panel)
        panel.orderOut(nil)
        return response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    }

    /// For tests and the gallery: the alert's view, as it would show.
    public func view(theme: ClassicTheme) -> NSView {
        AlertView(alert: self, theme: theme, respond: { _ in })
    }
}

/// Sizes in Mac OS 9 pixels.
private enum Metrics {
    static let width: CGFloat = 380
    static let margin: CGFloat = 16
    static let icon: CGFloat = 32
    /// BeOS's band down the left, behind the icon.
    static let band: CGFloat = 48
    static let textGap: CGFloat = 16
    static let paragraphGap: CGFloat = 8
    static let buttonGap: CGFloat = 8
}

private final class AlertPanel: NSPanel {
    let alertView: AlertView

    init(alert: ClassicAlert, theme: ClassicTheme) {
        var respond: (Int) -> Void = { _ in }
        alertView = AlertView(alert: alert, theme: theme, respond: { respond($0) })
        super.init(contentRect: NSRect(origin: .zero, size: alertView.frame.size), styleMask: [.borderless],
                   backing: .buffered, defer: false)
        respond = { index in
            NSApp.stopModal(withCode: NSApplication.ModalResponse(
                rawValue: NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + index))
        }
        contentView = alertView
        level = .modalPanel
        isOpaque = true
        hasShadow = true
        appearance = theme.nsAppearance
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: alertView.pressDefault()   // Return, Enter
        case 53: alertView.pressCancel()        // Esc
        default:
            // ⌘. was the classic Mac's cancel.
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "." {
                alertView.pressCancel()
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

private final class AlertView: NSView {
    let alert: ClassicAlert
    let theme: ClassicTheme
    private var buttons: [ClassicButton] = []
    private var messageRect = NSRect.zero
    private var infoRect = NSRect.zero
    private var iconRect = NSRect.zero

    init(alert: ClassicAlert, theme: ClassicTheme, respond: @escaping (Int) -> Void) {
        self.alert = alert
        self.theme = theme
        super.init(frame: .zero)
        // Shown right to left from the default, so the default ends up on the right.
        for (index, title) in alert.buttons.enumerated() {
            let button = ClassicButton(title: title, isDefault: index == 0, theme: theme) { respond(index) }
            buttons.append(button)
            addSubview(button)
        }
        layOut()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    private var style: MenuStyle { MenuStyle(theme.chrome) }
    private var messageFont: NSFont { theme.font(size: 12) }
    private var infoFont: NSFont {
        style == .beos ? (NSFont(name: "Helvetica", size: 11) ?? .systemFont(ofSize: 11)) : ClassicTheme.smallFont(size: 10)
    }

    /// Everything in pixels, then the frame in points.
    private func layOut() {
        let s = theme.scale
        let frameInset: CGFloat = style == .classic ? 6 : 3
        let left = style == .beos ? Metrics.band + Metrics.margin : Metrics.margin + Metrics.icon + Metrics.textGap
        iconRect = style == .beos
            ? NSRect(x: (Metrics.band - Metrics.icon) / 2 + 8, y: Metrics.margin + frameInset, width: Metrics.icon,
                     height: Metrics.icon)
            : NSRect(x: Metrics.margin + frameInset, y: Metrics.margin + frameInset, width: Metrics.icon,
                     height: Metrics.icon)
        let textWidth = Metrics.width - left - Metrics.margin - frameInset
        messageRect = NSRect(x: left, y: Metrics.margin + frameInset, width: textWidth,
                             height: height(of: alert.message, font: messageFont, width: textWidth))
        infoRect = alert.informativeText.isEmpty ? .zero
            : NSRect(x: left, y: messageRect.maxY + Metrics.paragraphGap, width: textWidth,
                     height: height(of: alert.informativeText, font: infoFont, width: textWidth))
        let textBottom = max(iconRect.maxY, infoRect == .zero ? messageRect.maxY : infoRect.maxY)

        var x = Metrics.width - Metrics.margin - frameInset + 4   // the ring's room outside the face
        let buttonTop = textBottom + Metrics.margin
        var buttonHeight: CGFloat = 0
        for button in buttons {
            let size = NSSize(width: button.intrinsicContentSize.width / s, height: button.intrinsicContentSize.height / s)
            x -= size.width
            button.frame = NSRect(x: x, y: buttonTop, width: size.width, height: size.height)
            x -= Metrics.buttonGap - 8   // rings overlap the gap
            buttonHeight = size.height
        }
        let height = buttonTop + buttonHeight + Metrics.margin - 4 + frameInset
        setFrameSize(NSSize(width: Metrics.width * s, height: height * s))
        setBoundsSize(NSSize(width: Metrics.width, height: height))
        for button in buttons { button.needsLayout = true }
    }

    private func height(of text: String, font: NSFont, width: CGFloat) -> CGFloat {
        ceil((text as NSString).boundingRect(with: NSSize(width: width, height: 10_000),
                                             options: [.usesLineFragmentOrigin], attributes: [.font: font]).height)
    }

    func pressDefault() { buttons.first?.flashAndPress() }

    func pressCancel() {
        let cancel = buttons.first { $0.title == "Cancel" } ?? buttons.last
        cancel?.flashAndPress()
    }

    override func draw(_ dirtyRect: NSRect) {
        let t = theme
        t.background.setFill()
        bounds.fill()
        switch style {
        case .platinum:
            t.drawOutline(bounds)
            t.drawRaisedBevel(bounds.insetBy(dx: 1, dy: 1), depth: 2)
        case .classic:
            // The modal dialog's double border: a thin line, a gap, then a thick one.
            t.drawOutline(bounds)
            t.drawOutline(bounds.insetBy(dx: 3, dy: 3))
            t.drawOutline(bounds.insetBy(dx: 4, dy: 4))
        case .beos:
            t.drawOutline(bounds)
            t.drawRaisedBevel(bounds.insetBy(dx: 1, dy: 1))
            t.well.setFill()
            NSRect(x: 2, y: 2, width: Metrics.band, height: bounds.height - 4).fill()
            t.dark.setFill()
            NSRect(x: 2 + Metrics.band, y: 2, width: 1, height: bounds.height - 4).fill()
        }
        drawIcon(in: iconRect)
        draw(alert.message, in: messageRect, font: messageFont)
        if infoRect != .zero { draw(alert.informativeText, in: infoRect, font: infoFont) }
    }

    private func draw(_ text: String, in rect: NSRect, font: NSFont) {
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin],
                                attributes: [.font: font, .foregroundColor: theme.text])
    }

    private func drawIcon(in rect: NSRect) {
        let ink = NSColor.black
        switch alert.icon {
        case .stop:
            // An octagon, red, ringed in white and outlined.
            let path = NSBezierPath()
            let c = NSPoint(x: rect.midX, y: rect.midY), r = rect.width / 2
            for i in 0..<8 {
                let angle = (CGFloat(i) * 45 + 22.5) * .pi / 180
                let p = NSPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
                if i == 0 { path.move(to: p) } else { path.line(to: p) }
            }
            path.close()
            NSColor(srgbRed: 0.85, green: 0.1, blue: 0.1, alpha: 1).setFill()
            path.fill()
            ink.setStroke()
            path.lineWidth = 1
            path.stroke()
            mark("!", in: rect, color: .white)
        case .caution:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.midX, y: rect.minY + 1))
            path.line(to: NSPoint(x: rect.maxX - 1, y: rect.maxY - 2))
            path.line(to: NSPoint(x: rect.minX + 1, y: rect.maxY - 2))
            path.close()
            NSColor(srgbRed: 1, green: 0.85, blue: 0.1, alpha: 1).setFill()
            path.fill()
            ink.setStroke()
            path.lineWidth = 1
            path.stroke()
            mark("!", in: rect.offsetBy(dx: 0, dy: 3), color: ink)
        case .note:
            let balloon = NSBezierPath(roundedRect: NSRect(x: rect.minX + 1, y: rect.minY + 2, width: rect.width - 2,
                                                           height: rect.height - 10), xRadius: 9, yRadius: 9)
            let tail = NSBezierPath()
            tail.move(to: NSPoint(x: rect.minX + 8, y: rect.maxY - 9))
            tail.line(to: NSPoint(x: rect.minX + 5, y: rect.maxY - 1))
            tail.line(to: NSPoint(x: rect.minX + 15, y: rect.maxY - 9))
            balloon.append(tail)
            NSColor.white.setFill()
            balloon.fill()
            ink.setStroke()
            balloon.lineWidth = 1
            balloon.stroke()
            mark("i", in: rect.offsetBy(dx: 0, dy: -3), color: ink)
        }
    }

    private func mark(_ text: String, in rect: NSRect, color: NSColor) {
        let font = NSFont.boldSystemFont(ofSize: 18)
        let size = (text as NSString).size(withAttributes: [.font: font])
        (text as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                                withAttributes: [.font: font, .foregroundColor: color])
    }
}
