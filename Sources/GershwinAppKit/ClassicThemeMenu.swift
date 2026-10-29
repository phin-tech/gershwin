import AppKit
import GershwinChrome

/// What a theme menu and a theme palette act on: the user's ThemeChoice, and the mode macOS is in. ClassicThemeStore is
/// one; an app that keeps its settings its own way makes its own (it needs only these two).
@MainActor
public protocol ClassicThemeSource: AnyObject {
    var themeChoice: ThemeChoice { get set }
    /// Whether macOS is in dark mode now.
    var systemIsDark: Bool { get }
}

extension ClassicThemeStore: ClassicThemeSource {
    public var themeChoice: ThemeChoice {
        get { settings.themeChoice }
        set { settings.themeChoice = newValue }
    }
}

public extension ClassicThemeSource {
    /// The theme showing: the chosen one, or while following macOS, the one for its mode now.
    var currentTheme: ChromeTheme { themeChoice.theme(systemIsDark: systemIsDark) }

    /// Choosing a theme from a menu: while following macOS, it is the one for the mode macOS is in now.
    func choose(_ theme: ChromeTheme) { themeChoice.choose(theme, systemIsDark: systemIsDark) }

    /// Turns following macOS on or off, keeping what is showing and the light and dark choices.
    func setFollowsSystem(_ on: Bool) { themeChoice.setFollowsSystem(on, systemIsDark: systemIsDark) }
}

/// A menu of themes, and a palette's: "Follow System Light and Dark", then each theme, the one showing checked; and
/// an entry for each theme for a ClassicPalette. Choosing acts on the source as ThemeChoice says (while following macOS,
/// a theme is the one for the mode now). Keep the menu object as long as its menu: items don't hold their target.
///
///     let themes = ClassicThemeMenu(source: store)
///     themes.addItems(to: viewMenu)
@MainActor
public final class ClassicThemeMenu: NSObject, NSMenuItemValidation {
    private let source: ClassicThemeSource
    private let themes: [ChromeTheme]

    public init(source: ClassicThemeSource, themes: [ChromeTheme] = ChromeTheme.builtIn) {
        self.source = source
        self.themes = themes
    }

    /// Follow System Light and Dark, a separator, and a checked item for each theme, at the end of `menu`.
    public func addItems(to menu: NSMenu, followTitle: String = "Follow System Light and Dark") {
        let follow = NSMenuItem(title: followTitle, action: #selector(toggleFollowsSystem(_:)), keyEquivalent: "")
        follow.target = self
        menu.addItem(follow)
        menu.addItem(.separator())
        for theme in themes {
            let item = NSMenuItem(title: theme.name, action: #selector(chooseTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.id
            menu.addItem(item)
        }
    }

    /// An entry for each theme, the one showing marked "current". Choosing one is choosing it from the menu.
    public func paletteEntries(group: String = "Theme") -> [PaletteEntry] {
        let current = source.currentTheme.id
        return themes.map { theme in
            PaletteEntry(id: "theme:\(theme.id)", title: theme.name, detail: theme.id == current ? "current" : nil,
                         group: group) { [source] in source.choose(theme) }
        }
    }

    @objc private func chooseTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let theme = themes.first(where: { $0.id == id }) else { return }
        source.choose(theme)
    }

    @objc private func toggleFollowsSystem(_ sender: Any?) {
        source.setFollowsSystem(!source.themeChoice.followsSystem)
    }

    public func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(chooseTheme(_:)) {
            item.state = (item.representedObject as? String) == source.currentTheme.id ? .on : .off
        } else if item.action == #selector(toggleFollowsSystem(_:)) {
            item.state = source.themeChoice.followsSystem ? .on : .off
        }
        return true
    }
}
