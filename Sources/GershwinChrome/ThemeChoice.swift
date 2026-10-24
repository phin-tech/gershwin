/// Which theme an app shows: one, or while following macOS, one for light mode and one for dark. The three are kept
/// apart, so turning following on and off never loses a choice. A mode that hasn't been given one gets the theme's
/// partner for it (BeOS's dark one is BeOS Dark), or failing that Platinum or Hi-Tech, until one is chosen.
///
/// Saved as `{"theme": "platinum", "light": "system7", "dark": "beosDark", "followsSystem": true}`; `light` and `dark`
/// are left out until chosen.
public struct ThemeChoice: Hashable, Sendable, Codable {
    /// The theme while not following macOS.
    public var theme: ChromeTheme
    /// The ones for light and dark mode while following it; nil for one not chosen yet.
    public var light: ChromeTheme?
    public var dark: ChromeTheme?
    public var followsSystem: Bool

    public init(theme: ChromeTheme = .platinum, light: ChromeTheme? = nil, dark: ChromeTheme? = nil,
                followsSystem: Bool = false) {
        self.theme = theme
        self.light = light
        self.dark = dark
        self.followsSystem = followsSystem
    }

    /// The theme for light mode: the one chosen, or the theme's light partner.
    public func lightTheme(among themes: [ChromeTheme] = ChromeTheme.builtIn) -> ChromeTheme {
        light ?? theme.lightCounterpart(among: themes)
    }

    /// The theme for dark mode: the one chosen, or the theme's dark partner.
    public func darkTheme(among themes: [ChromeTheme] = ChromeTheme.builtIn) -> ChromeTheme {
        dark ?? theme.darkCounterpart(among: themes)
    }

    /// The theme to show, with macOS in light or dark mode.
    public func theme(systemIsDark: Bool, among themes: [ChromeTheme] = ChromeTheme.builtIn) -> ChromeTheme {
        guard followsSystem else { return theme }
        return systemIsDark ? darkTheme(among: themes) : lightTheme(among: themes)
    }

    /// Choosing a theme (from a menu, say): while following macOS, it becomes the one for the mode macOS is in now,
    /// so the choice shows at once.
    public mutating func choose(_ chosen: ChromeTheme, systemIsDark: Bool) {
        if !followsSystem {
            theme = chosen
        } else if systemIsDark {
            dark = chosen
        } else {
            light = chosen
        }
    }

    /// Turns following macOS on or off. On, the light and dark themes are as they were chosen (or the partners, for
    /// one not chosen); off, the theme is the one that was showing, so nothing changes on screen.
    public mutating func setFollowsSystem(_ on: Bool, systemIsDark: Bool,
                                          among themes: [ChromeTheme] = ChromeTheme.builtIn) {
        guard on != followsSystem else { return }
        if !on { theme = theme(systemIsDark: systemIsDark, among: themes) }
        followsSystem = on
    }

    // Field by field: a theme that can't be found, or a key left out, is the default.
    private enum CodingKeys: String, CodingKey { case theme, light, dark, followsSystem }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = (try? c.decode(ChromeTheme.self, forKey: .theme)) ?? .platinum
        light = try? c.decodeIfPresent(ChromeTheme.self, forKey: .light)
        dark = try? c.decodeIfPresent(ChromeTheme.self, forKey: .dark)
        followsSystem = (try? c.decodeIfPresent(Bool.self, forKey: .followsSystem)) ?? false
    }
}
