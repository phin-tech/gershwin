// ClassicMenu shows an NSMenu drawn in a theme's own style: Mac OS 8 and 9's (bevelled, with a hard drop shadow),
// System 1 to 7's (white, outlined in black, the highlight inverted), or BeOS's (a flat grey panel, a darker band for
// the highlight). macOS draws an NSMenu's frame, corners and highlight itself and won't let them be restyled, so this
// reads the menu's items and draws them in panels of its own. Choosing an item sends its action, as NSMenu would.
//
// Grown from the Platinum menus of Sam's SketchyBar helpers (chezmoi's helpers/appmenu/platinum-menu.swift). Unlike
// those, it tracks the mouse in an event loop of its own, as the Menu Manager's MenuSelect did, rather than running
// the whole application again inside itself.
//
// Mouse: press, drag and release to choose; a quick click leaves the menu open (Mac OS 8's sticky menus), and then
// hover and click. A ▸ row opens its submenu. Clicking outside closes it. Keys: ↑↓ move, → opens a submenu, ← closes
// one, Return chooses, Esc closes, letters jump to the next item starting with them. Holding ⌥, ⇧ or ⌃ swaps in
// alternate items.

import AppKit
import GershwinChrome

/// A menu's sizes, in Mac OS 9 pixels; its colours come from the theme.
private enum Metrics {
    static let fontSize: CGFloat = 12
    static let rowHeight: CGFloat = 18
    static let separatorHeight: CGFloat = 8
    static let padding: CGFloat = 3
    static let gutter: CGFloat = 20
    static let iconSize: CGFloat = 16
    static let trailing: CGFloat = 22
    static let keyGap: CGFloat = 24
    static let shadow: CGFloat = 2
    static let minimumWidth: CGFloat = 120
    /// A mouse-up this soon after the menu opened, before the mouse has moved onto another row, leaves it open.
    static let stickyClick: TimeInterval = 0.3
}

/// How a theme draws its menus.
enum MenuStyle {
    /// Mac OS 8 and 9, and Copland: bevelled, a hard shadow, the theme's highlight colour.
    case platinum
    /// System 1 to 7: white, outlined, a solid one-pixel shadow, the highlight inverted.
    case classic
    /// BeOS: a flat grey panel and a darker grey band, with macOS's soft shadow.
    case beos

    init(_ chrome: ChromeTheme) {
        switch (chrome.family, chrome.tabStyle) {
        case (.beos, _): self = .beos
        case (_, .folder): self = .classic
        default: self = .platinum
        }
    }
}

// MARK: - Rows

private struct Row {
    let item: NSMenuItem
    let y: CGFloat
    let height: CGFloat

    var selectable: Bool { !item.isSeparatorItem && !item.isSectionHeader && item.isEnabled && !item.isHidden }
}

private func label(_ item: NSMenuItem) -> String {
    item.title.isEmpty ? item.attributedTitle?.string ?? "" : item.title
}

/// "⌃⌥⇧⌘Q" for an item's key equivalent, or "" when it has none.
private func shortcut(_ item: NSMenuItem) -> String {
    guard !item.keyEquivalent.isEmpty else { return "" }
    let mask = item.keyEquivalentModifierMask
    var text = ""
    if mask.contains(.control) { text += "⌃" }
    if mask.contains(.option) { text += "⌥" }
    if mask.contains(.shift) { text += "⇧" }
    if mask.contains(.command) { text += "⌘" }
    let key: String
    switch item.keyEquivalent {
    case "\r": key = "↩"
    case "\u{1b}": key = "⎋"
    case "\u{8}", "\u{7f}": key = "⌫"
    case " ": key = "Space"
    default: key = item.keyEquivalent.uppercased()
    }
    return text + key
}

// MARK: - View

/// One menu, drawn in Mac OS 9 pixels: its bounds are its frame over the theme's scale.
private final class MenuView: NSView {
    let source: NSMenu
    let theme: ClassicTheme
    let style: MenuStyle
    private let font: NSFont
    private(set) var rows: [Row] = []
    /// The menu's own size, in pixels, without its shadow.
    private(set) var menuSize = NSSize.zero
    let minimumWidth: CGFloat
    var highlighted: Int? { didSet { if highlighted != oldValue { needsDisplay = true } } }
    private(set) var modifiers: NSEvent.ModifierFlags = []

    init(menu: NSMenu, theme: ClassicTheme, minimumWidth: CGFloat) {
        source = menu
        self.theme = theme
        style = MenuStyle(theme.chrome)
        font = theme.font(size: Metrics.fontSize)
        self.minimumWidth = minimumWidth
        super.init(frame: .zero)
        layoutRows()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    private var shadowWidth: CGFloat { style == .beos ? 0 : (style == .classic ? 1 : Metrics.shadow) }
    private var hasIcons: Bool { source.items.contains { $0.image != nil && !$0.isHidden } }

    /// Swaps alternates in or out for newly held modifiers. Returns whether it did.
    func update(modifiers held: NSEvent.ModifierFlags) -> Bool {
        let held = held.intersection([.shift, .option, .control])
        guard held != modifiers else { return false }
        modifiers = held
        layoutRows()
        needsDisplay = true
        return true
    }

    /// One item per group of a primary and its alternates: the alternate whose extra modifiers are all held (the most
    /// specific, if several), else the primary.
    private var shownItems: [NSMenuItem] {
        var shown: [NSMenuItem] = []
        var primary: NSMenuItem?
        for item in source.items where !item.isHidden {
            guard item.isAlternate, let base = primary else {
                primary = item
                shown.append(item)
                continue
            }
            let extra = item.keyEquivalentModifierMask.subtracting(base.keyEquivalentModifierMask)
                .intersection([.shift, .option, .control])
            let current = shown[shown.count - 1]
            let currentExtra = current.keyEquivalentModifierMask.subtracting(base.keyEquivalentModifierMask)
                .intersection([.shift, .option, .control])
            if !extra.isEmpty, modifiers.isSuperset(of: extra),
               current === base || extra.isStrictSuperset(of: currentExtra) {
                shown[shown.count - 1] = item
            }
        }
        return shown
    }

    private func layoutRows() {
        rows = []
        var y = Metrics.padding
        var titleWidth: CGFloat = 0
        var keyWidth: CGFloat = 0
        for item in shownItems {
            let height = item.isSeparatorItem ? Metrics.separatorHeight : Metrics.rowHeight
            rows.append(Row(item: item, y: y, height: height))
            y += height
            titleWidth = max(titleWidth, attributed(label(item), color: theme.text).size().width)
            keyWidth = max(keyWidth, attributed(shortcut(item), color: theme.text).size().width)
        }
        let icons = hasIcons ? Metrics.iconSize + 4 : 0
        let keys = keyWidth > 0 ? Metrics.keyGap + keyWidth : 0
        let width = Metrics.gutter + icons + titleWidth + keys + Metrics.trailing
        menuSize = NSSize(width: ceil(max(width, Metrics.minimumWidth, minimumWidth)), height: y + Metrics.padding)
        let pixels = NSSize(width: menuSize.width + shadowWidth, height: menuSize.height + shadowWidth)
        setFrameSize(NSSize(width: pixels.width * theme.scale, height: pixels.height * theme.scale))
        setBoundsSize(pixels)
    }

    private func attributed(_ string: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    }

    func row(at point: NSPoint) -> Int? {
        guard point.x >= 0, point.x < menuSize.width else { return nil }
        return rows.firstIndex { point.y >= $0.y && point.y < $0.y + $0.height }
    }

    /// A row's frame on screen, for placing its submenu or lining it up over a pop-up button.
    func screenFrame(ofRow index: Int) -> NSRect {
        let row = rows[index]
        let local = convert(NSRect(x: 0, y: row.y, width: menuSize.width, height: row.height), to: nil)
        return window?.convertToScreen(local) ?? local
    }

    /// How far down the menu a row's top is, in points.
    func offset(ofRow index: Int) -> CGFloat { rows[index].y * theme.scale }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        let menu = NSRect(origin: .zero, size: menuSize)
        drawFrame(menu)
        for (index, row) in rows.enumerated() {
            if row.item.isSeparatorItem {
                switch style {
                case .classic:
                    // A dotted grey line, as System 7 drew it.
                    theme.disabledText.setFill()
                    for x in stride(from: 1, to: menu.width - 1, by: 2) {
                        NSRect(x: x, y: row.y + floor(row.height / 2), width: 1, height: 1).fill()
                    }
                case .platinum, .beos:
                    theme.drawEtchedLine(x: 1, y: row.y + floor(row.height / 2) - 1, width: menu.width - 2)
                }
                continue
            }
            let selected = index == highlighted && row.selectable
            if selected {
                (style == .beos ? theme.dark : theme.highlight).setFill()
                NSRect(x: 1, y: row.y, width: menu.width - 2, height: row.height).fill()
            }
            let color: NSColor = !row.selectable ? theme.disabledText
                : selected && style != .beos ? theme.selectedText : theme.text
            drawContents(of: row, color: color, width: menu.width)
        }
    }

    private func drawFrame(_ rect: NSRect) {
        let t = theme
        switch style {
        case .platinum:
            NSColor(white: 0, alpha: 0.4).setFill()
            rect.offsetBy(dx: Metrics.shadow, dy: Metrics.shadow).fill()
            t.background.setFill()
            rect.fill()
            t.drawOutline(rect)
            t.light.setFill()
            NSRect(x: rect.minX + 1, y: rect.minY + 1, width: rect.width - 2, height: 1).fill()
            NSRect(x: rect.minX + 1, y: rect.minY + 1, width: 1, height: rect.height - 2).fill()
        case .classic:
            t.border.setFill()
            rect.offsetBy(dx: 1, dy: 1).fill()
            t.background.setFill()
            rect.fill()
            t.drawOutline(rect)
        case .beos:
            t.background.setFill()
            rect.fill()
            t.drawOutline(rect)
            t.drawRaisedBevel(rect.insetBy(dx: 1, dy: 1))
        }
    }

    private func drawContents(of row: Row, color: NSColor, width: CGFloat) {
        let item = row.item
        let title = attributed(label(item), color: color)
        let textY = row.y + (row.height - title.size().height) / 2

        if item.state == .on {
            attributed("✓", color: color).draw(at: NSPoint(x: 6, y: textY))
        } else if item.state == .mixed {
            attributed("–", color: color).draw(at: NSPoint(x: 7, y: textY))
        }

        var x = Metrics.gutter
        if hasIcons {
            if let image = item.image {
                let icon = NSRect(x: x, y: row.y + (row.height - Metrics.iconSize) / 2,
                                  width: Metrics.iconSize, height: Metrics.iconSize)
                image.draw(in: icon, from: .zero, operation: .sourceOver,
                           fraction: row.selectable ? 1 : 0.5, respectFlipped: true, hints: nil)
            }
            x += Metrics.iconSize + 4
        }
        title.draw(at: NSPoint(x: x, y: textY))

        if item.hasSubmenu {
            // A solid triangle pointing right, the classic submenu arrow.
            let midY = row.y + row.height / 2
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: width - 14, y: midY - 5))
            arrow.line(to: NSPoint(x: width - 9, y: midY))
            arrow.line(to: NSPoint(x: width - 14, y: midY + 5))
            arrow.close()
            color.setFill()
            arrow.fill()
        } else {
            let key = attributed(shortcut(item), color: color)
            key.draw(at: NSPoint(x: width - Metrics.trailing + 8 - key.size().width, y: textY))
        }
    }
}

// MARK: - Panels

private final class MenuPanel: NSPanel {
    let menuView: MenuView

    init(menu: NSMenu, theme: ClassicTheme, minimumWidth: CGFloat) {
        menuView = MenuView(menu: menu, theme: theme, minimumWidth: minimumWidth)
        super.init(contentRect: menuView.frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        // The Mac styles draw their own hard shadow; BeOS's is soft, as macOS draws.
        hasShadow = menuView.style == .beos
        isReleasedWhenClosed = false
        contentView = menuView
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - Session

@MainActor
public final class ClassicMenu {
    /// Shows `menu` with its top-left corner at `topLeft` (screen coordinates), and returns once it closes, having sent
    /// the chosen item's action. Returns the chosen item, or nil if none was.
    ///
    /// - Parameters:
    ///   - lineUp: the index of an item to put at `topLeft` rather than the menu's top, as a pop-up button does with
    ///     its current choice.
    ///   - minimumWidth: in points: a pop-up's menu is at least as wide as the button.
    @discardableResult
    public static func popUp(_ menu: NSMenu, at topLeft: NSPoint, theme: ClassicTheme, lineUp: Int? = nil,
                             minimumWidth: CGFloat = 0) -> NSMenuItem? {
        let session = ClassicMenu(theme: theme)
        return session.run(menu, at: topLeft, lineUp: lineUp, minimumWidth: minimumWidth / theme.scale)
    }

    /// A context menu at the mouse, as for a right-click.
    @discardableResult
    public static func popUpContextMenu(_ menu: NSMenu, for event: NSEvent, theme: ClassicTheme) -> NSMenuItem? {
        popUp(menu, at: NSEvent.mouseLocation, theme: theme)
    }

    private let theme: ClassicTheme
    private var panels: [MenuPanel] = []
    private var chosen: NSMenuItem?
    private var closed = false
    private var lastMouse = NSPoint(x: CGFloat.nan, y: CGFloat.nan)
    private var openedAt = Date()
    private var movedToAnotherRow = false

    private init(theme: ClassicTheme) {
        self.theme = theme
    }

    private func run(_ menu: NSMenu, at topLeft: NSPoint, lineUp: Int?, minimumWidth: CGFloat) -> NSMenuItem? {
        menu.update()
        open(menu, at: topLeft, avoiding: nil, lineUp: lineUp, minimumWidth: minimumWidth)
        panels[0].makeKeyAndOrderFront(nil)
        if let lineUp, panels[0].menuView.rows.indices.contains(lineUp) { panels[0].menuView.highlighted = lineUp }
        openedAt = Date()
        let startRow = panels[0].menuView.highlighted

        // The Menu Manager's way: take events until the menu closes, dispatching only what isn't the menu's.
        while !closed {
            let event = NSApp.nextEvent(matching: .any, until: Date(timeIntervalSinceNow: 1.0 / 60),
                                        inMode: .eventTracking, dequeue: true)
            track()
            if panels.first?.menuView.highlighted != startRow { movedToAnotherRow = true }
            guard let event else {
                if !NSApp.isActive { close(choosing: nil) }
                continue
            }
            handle(event)
        }
        panels.forEach { $0.orderOut(nil) }
        if let item = chosen, let action = item.action {
            NSApp.sendAction(action, to: item.target, from: item)
        }
        return chosen
    }

    private func open(_ menu: NSMenu, at topLeft: NSPoint, avoiding parentRow: NSRect?, lineUp: Int? = nil,
                      minimumWidth: CGFloat = 0) {
        menu.delegate?.menuNeedsUpdate?(menu)
        let panel = MenuPanel(menu: menu, theme: theme, minimumWidth: minimumWidth)
        let size = panel.frame.size
        let screen = NSScreen.screens.first { NSPointInRect(topLeft, $0.frame) } ?? NSScreen.main!
        let visible = screen.visibleFrame
        var top = topLeft.y
        if let lineUp, panel.menuView.rows.indices.contains(lineUp) {
            top += panel.menuView.offset(ofRow: lineUp)
        }
        var origin = NSPoint(x: topLeft.x, y: top - size.height)
        if origin.x + size.width > visible.maxX {
            // No room on the right: a submenu flips to its parent's left side.
            origin.x = parentRow.map { $0.minX - size.width + 2 * theme.scale } ?? visible.maxX - size.width
        }
        origin.x = max(origin.x, visible.minX)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
        panels.append(panel)
    }

    private func closeSubmenus(after level: Int) {
        while panels.count > level + 1 { panels.removeLast().orderOut(nil) }
    }

    private func openSubmenu(ofRow index: Int, in level: Int) {
        let view = panels[level].menuView
        guard let submenu = view.rows[index].item.submenu, view.rows[index].selectable else { return }
        if panels.count > level + 1, panels[level + 1].menuView.source === submenu { return }
        closeSubmenus(after: level)
        let row = view.screenFrame(ofRow: index)
        open(submenu, at: NSPoint(x: row.maxX - 2 * theme.scale, y: row.maxY + Metrics.padding * theme.scale),
             avoiding: row)
    }

    /// The deepest panel under the pointer, its level and the row there.
    private func hit(_ point: NSPoint) -> (level: Int, row: Int?)? {
        for level in panels.indices.reversed() where NSPointInRect(point, panels[level].frame) {
            let view = panels[level].menuView
            let local = view.convert(panels[level].convertPoint(fromScreen: point), from: nil)
            return (level, view.row(at: local))
        }
        return nil
    }

    private func track() {
        for (level, panel) in panels.enumerated() where panel.menuView.update(modifiers: NSEvent.modifierFlags) {
            let top = panel.frame.maxY
            panel.setFrame(NSRect(origin: NSPoint(x: panel.frame.minX, y: top - panel.menuView.frame.height),
                                  size: panel.menuView.frame.size), display: true)
            closeSubmenus(after: level)
        }
        let mouse = NSEvent.mouseLocation
        guard mouse != lastMouse else { return }
        lastMouse = mouse
        guard let spot = hit(mouse) else { return }   // outside: keep what's highlighted
        let (level, row) = (spot.level, spot.row)
        panels[level].menuView.highlighted = row
        if let row, panels[level].menuView.rows[row].item.hasSubmenu {
            openSubmenu(ofRow: row, in: level)
        } else {
            closeSubmenus(after: level)
        }
        for parent in 0..<level where parent + 1 < panels.count {
            let submenu = panels[parent + 1].menuView.source
            panels[parent].menuView.highlighted = panels[parent].menuView.rows.firstIndex { $0.item.submenu === submenu }
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            if hit(NSEvent.mouseLocation) == nil { close(choosing: nil) }
        case .leftMouseUp, .rightMouseUp:
            // The click that opened the menu, let go at once without moving to another row: leave it open.
            if Date().timeIntervalSince(openedAt) < Metrics.stickyClick, !movedToAnotherRow { return }
            guard let spot = hit(NSEvent.mouseLocation), let row = spot.row else { return }
            let item = panels[spot.level].menuView.rows[row]
            if item.selectable && !item.item.hasSubmenu { close(choosing: item.item) }
        case .keyDown:
            key(event)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .flagsChanged, .scrollWheel:
            break   // followed by track()
        default:
            NSApp.sendEvent(event)
        }
    }

    private func key(_ event: NSEvent) {
        let level = panels.count - 1
        let view = panels[level].menuView
        switch event.keyCode {
        case 125: move(by: 1, in: view)       // ↓
        case 126: move(by: -1, in: view)      // ↑
        case 124:                             // →
            if let row = view.highlighted, view.rows[row].item.hasSubmenu { enterSubmenu(ofRow: row, in: level) }
        case 123:                             // ←
            if level > 0 { closeSubmenus(after: level - 1) }
        case 36, 76:                          // Return, Enter
            guard let row = view.highlighted, view.rows[row].selectable else { return }
            if view.rows[row].item.hasSubmenu {
                enterSubmenu(ofRow: row, in: level)
            } else {
                close(choosing: view.rows[row].item)
            }
        case 53: close(choosing: nil)         // Esc
        default:
            guard let letter = event.charactersIgnoringModifiers?.lowercased(), !letter.isEmpty else { return }
            let start = (view.highlighted ?? -1) + 1
            let order = Array(start..<view.rows.count) + Array(0..<start)
            if let match = order.first(where: {
                view.rows[$0].selectable && label(view.rows[$0].item).lowercased().hasPrefix(letter)
            }) {
                view.highlighted = match
                closeSubmenus(after: level)
            }
        }
    }

    private func enterSubmenu(ofRow row: Int, in level: Int) {
        openSubmenu(ofRow: row, in: level)
        if panels.count > level + 1 { move(by: 1, in: panels[level + 1].menuView) }
    }

    private func move(by step: Int, in view: MenuView) {
        let count = view.rows.count
        guard count > 0 else { return }
        var index = view.highlighted ?? (step > 0 ? -1 : count)
        for _ in 0..<count {
            index = (index + step + count) % count
            if view.rows[index].selectable { view.highlighted = index; return }
        }
    }

    private func close(choosing item: NSMenuItem?) {
        guard !closed else { return }
        closed = true
        chosen = item
    }
}

#if DEBUG
/// For tests: a menu drawn as it would show, without running it.
@MainActor
public enum ClassicMenuPreview {
    public static func view(for menu: NSMenu, theme: ClassicTheme, highlighted: Int? = nil) -> NSView {
        let view = MenuView(menu: menu, theme: theme, minimumWidth: 0)
        view.highlighted = highlighted
        return view
    }
}
#endif
