// Context menus for SwiftUI, drawn as the theme draws menus (ClassicMenu): SwiftUI's own `.contextMenu` opens
// macOS's menu, which `.gershwin()` can't restyle.

import AppKit
import GershwinAppKit
import SwiftUI

/// One row of a classic menu: a title and what choosing it does, a submenu, or a separator line.
public struct ClassicMenuItem: @unchecked Sendable {
    let title: String
    let isEnabled: Bool
    let isChecked: Bool
    let action: (() -> Void)?
    let submenu: [ClassicMenuItem]
    let isSeparator: Bool

    public init(_ title: String, isEnabled: Bool = true, isChecked: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.isChecked = isChecked
        self.action = action
        submenu = []
        isSeparator = false
    }

    public init(_ title: String, isEnabled: Bool = true, submenu: [ClassicMenuItem]) {
        self.title = title
        self.isEnabled = isEnabled
        isChecked = false
        action = nil
        self.submenu = submenu
        isSeparator = false
    }

    private init() {
        title = ""
        isEnabled = false
        isChecked = false
        action = nil
        submenu = []
        isSeparator = true
    }

    public static let separator = ClassicMenuItem()

    /// An NSMenu of `items`; each item's tag indexes `actions`, which the caller runs for the one chosen.
    @MainActor
    static func makeMenu(from items: [ClassicMenuItem], actions: inout [Int: () -> Void]) -> NSMenu {
        let menu = NSMenu()
        // Enabled is what each item says, not whether it has a target and action.
        menu.autoenablesItems = false
        for item in items {
            if item.isSeparator {
                menu.addItem(.separator())
                continue
            }
            let row = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
            row.isEnabled = item.isEnabled
            row.state = item.isChecked ? .on : .off
            if let action = item.action {
                row.tag = actions.count
                actions[row.tag] = action
            }
            if !item.submenu.isEmpty { row.submenu = makeMenu(from: item.submenu, actions: &actions) }
            menu.addItem(row)
        }
        return menu
    }

    /// Shows `items` as a classic menu with its top-left at `point` (screen coordinates; the mouse by default), waits
    /// for a choice, and runs it.
    @MainActor
    public static func popUp(_ items: [ClassicMenuItem], at point: NSPoint = NSEvent.mouseLocation,
                             theme: ClassicTheme) {
        var actions: [Int: () -> Void] = [:]
        let menu = makeMenu(from: items, actions: &actions)
        guard let chosen = ClassicMenu.popUp(menu, at: point, theme: theme), chosen.submenu == nil,
              let action = actions[chosen.tag] else { return }
        action()
    }
}

public extension View {
    /// A context menu on a right-click (or a control-click) in the theme's style. `items` is asked each time, so
    /// what's enabled or checked is what it is then.
    func classicContextMenu(_ items: @escaping () -> [ClassicMenuItem]) -> some View {
        modifier(ClassicContextMenuModifier(items: items))
    }
}

private struct ClassicContextMenuModifier: ViewModifier {
    @Environment(\.classicTheme) private var theme
    let items: () -> [ClassicMenuItem]

    func body(content: Content) -> some View {
        content.overlay(ContextMenuCatcher(theme: theme, items: items))
    }
}

/// A view over the content that takes no click but a right- or control-click: it answers the hit test only while that
/// kind of event is the one being delivered, so everything else falls through to what's beneath.
private struct ContextMenuCatcher: NSViewRepresentable {
    let theme: ClassicTheme
    let items: () -> [ClassicMenuItem]

    func makeNSView(context: Context) -> CatcherView { CatcherView() }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.theme = theme
        view.items = items
    }

    final class CatcherView: NSView {
        var theme = ClassicTheme.platinum
        var items: () -> [ClassicMenuItem] = { [] }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent, bounds.contains(convert(point, from: superview)) else { return nil }
            switch event.type {
            case .rightMouseDown: return self
            case .leftMouseDown where event.modifierFlags.contains(.control): return self
            default: return nil
            }
        }

        override func mouseDown(with event: NSEvent) { show() }
        override func rightMouseDown(with event: NSEvent) { show() }

        private func show() {
            let items = items()
            guard !items.isEmpty else { return }
            ClassicMenuItem.popUp(items, theme: theme)
        }
    }
}
