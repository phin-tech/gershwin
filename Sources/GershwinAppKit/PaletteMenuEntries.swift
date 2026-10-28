import AppKit
import GershwinChrome

public extension PaletteEntry {
    /// An entry for each command in `menu` and its submenus: the item's title, the menus it's under as its detail
    /// ("Panes", or "Window ▸ Go to Tab"), and its shortcut as the menu shows it. Separators, hidden and disabled
    /// items, and items that do nothing, are left out; items are validated first, as the menu bar would before
    /// opening. Choosing one does what clicking it does. `including` leaves out the items it says no to, for ones the
    /// app lists better another way (a menu of themes, where the palette has an entry for each).
    @MainActor
    static func entries(from menu: NSMenu, group: String = "Menu",
                        including include: (NSMenuItem) -> Bool = { _ in true }) -> [PaletteEntry] {
        var found: [PaletteEntry] = []
        collect(menu, path: [], group: group, include: include, into: &found)
        return found
    }

    @MainActor
    private static func collect(_ menu: NSMenu, path: [String], group: String, include: (NSMenuItem) -> Bool,
                                into found: inout [PaletteEntry]) {
        menu.update()
        for item in menu.items where !item.isSeparatorItem && !item.isHidden {
            if let submenu = item.submenu {
                let title = item.title.isEmpty ? submenu.title : item.title
                collect(submenu, path: title.isEmpty ? path : path + [title], group: group, include: include,
                        into: &found)
                continue
            }
            guard item.isEnabled, item.action != nil, include(item) else { continue }
            let id = (path + [item.title]).joined(separator: " ▸ ")
            found.append(PaletteEntry(id: "menu:" + id, title: item.title,
                                      detail: path.isEmpty ? nil : path.joined(separator: " ▸ "), group: group,
                                      shortcut: shortcutLabel(for: item)) { [weak item] in
                guard let item, let action = item.action else { return }
                NSApp.sendAction(action, to: item.target, from: item)
            })
        }
    }

    /// "⇧⌘P": a menu item's shortcut as the menus draw it, in the order Mac OS did (control, option, shift, command).
    static func shortcutLabel(for item: NSMenuItem) -> String? {
        let key = item.keyEquivalent
        guard !key.isEmpty else { return nil }
        let flags = item.keyEquivalentModifierMask
        var label = ""
        if flags.contains(.control) { label += "⌃" }
        if flags.contains(.option) { label += "⌥" }
        if flags.contains(.shift) { label += "⇧" }
        if flags.contains(.command) { label += "⌘" }
        return label + key.uppercased()
    }
}
