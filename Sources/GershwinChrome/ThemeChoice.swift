/// Which theme an app shows: one, or a light one and a dark one, switching as macOS does. Saved as
/// `{"light": "platinum", "dark": "hiTech", "followsSystem": true}`.
public struct ThemeChoice: Hashable, Sendable, Codable {
    /// The theme; while following macOS, the one for light mode.
    public var light: ChromeTheme
    /// The one for dark mode, while following macOS.
    public var dark: ChromeTheme
    public var followsSystem: Bool

    public init(light: ChromeTheme = .platinum, dark: ChromeTheme = .hiTech, followsSystem: Bool = false) {
        self.light = light
        self.dark = dark
        self.followsSystem = followsSystem
    }

    /// The theme to show, with macOS in light or dark mode.
    public func theme(systemIsDark: Bool) -> ChromeTheme {
        followsSystem && systemIsDark ? dark : light
    }

    /// Choosing a theme (from a menu, say): while following macOS, it becomes the one for the mode macOS is in now,
    /// so the choice shows at once.
    public mutating func choose(_ theme: ChromeTheme, systemIsDark: Bool) {
        if followsSystem && systemIsDark { dark = theme } else { light = theme }
    }

    /// Turns following macOS on or off without changing what's showing: the theme in use takes the slot for its own
    /// mode, and the other slot gets its counterpart (BeOS Dark's is BeOS; Platinum's, Hi-Tech).
    public mutating func setFollowsSystem(_ on: Bool, systemIsDark: Bool, among themes: [ChromeTheme] = ChromeTheme.builtIn) {
        guard on != followsSystem else { return }
        let showing = theme(systemIsDark: systemIsDark)
        followsSystem = on
        if on {
            if showing.isDark {
                dark = showing
                light = showing.lightCounterpart(among: themes)
            } else {
                light = showing
                dark = showing.darkCounterpart(among: themes)
            }
        } else {
            light = showing
        }
    }

    // Field by field: a theme that can't be found, or a key left out, is the default.
    private enum CodingKeys: String, CodingKey { case light, dark, followsSystem }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        light = (try? c.decode(ChromeTheme.self, forKey: .light)) ?? .platinum
        dark = (try? c.decode(ChromeTheme.self, forKey: .dark)) ?? .hiTech
        followsSystem = (try? c.decodeIfPresent(Bool.self, forKey: .followsSystem)) ?? false
    }
}
