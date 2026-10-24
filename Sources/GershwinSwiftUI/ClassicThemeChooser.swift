import GershwinAppKit
import GershwinChrome
import SwiftUI

/// A settings pane's theme controls, for a ThemeChoice: a pop-up of the themes, or while following macOS one for light
/// and one for dark, and the checkbox that turns following on (keeping what's showing). Labels are right-aligned in a
/// column `labelWidth` wide (in Mac OS 9 pixels), as Mac OS 9's control panels set them; put more rows of your own
/// under it the same way.
public struct ClassicThemeChooser: View {
    @Environment(\.classicTheme) private var theme
    @Binding var choice: ThemeChoice
    let themes: [ChromeTheme]
    let systemIsDark: Bool
    let labelWidth: CGFloat

    public init(choice: Binding<ThemeChoice>, themes: [ChromeTheme] = ChromeTheme.builtIn, systemIsDark: Bool,
                labelWidth: CGFloat = 50) {
        _choice = choice
        self.themes = themes
        self.systemIsDark = systemIsDark
        self.labelWidth = labelWidth
    }

    public var body: some View {
        let s = theme.scale
        let options = themes.map { (value: $0, label: $0.name) }
        VStack(alignment: .leading, spacing: 10 * s) {
            if choice.followsSystem {
                row("Light:") { ClassicPopUp(selection: $choice.light, options: options) }
                row("Dark:") { ClassicPopUp(selection: $choice.dark, options: options) }
            } else {
                row("Theme:") { ClassicPopUp(selection: $choice.light, options: options) }
            }
            Toggle("Follow macOS light and dark", isOn: Binding(
                get: { choice.followsSystem },
                set: { choice.setFollowsSystem($0, systemIsDark: systemIsDark, among: themes) }))
        }
    }

    private func row<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 8 * theme.scale) {
            Text(label).fixedSize().frame(width: labelWidth * theme.scale, alignment: .trailing)
            control()
            Spacer(minLength: 0)
        }
    }
}
