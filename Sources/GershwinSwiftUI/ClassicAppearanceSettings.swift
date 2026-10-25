import GershwinAppKit
import GershwinChrome
import SwiftUI

/// A window's SwiftUI content under the theme the store shows now, so it restyles when the choice, the scale or
/// macOS's mode changes. Use it as the root of a window's hosting view in place of `.gershwin(_:)`.
public struct ClassicThemed<Content: View>: View {
    let store: ClassicThemeStore
    let content: Content

    public init(_ store: ClassicThemeStore, @ViewBuilder content: () -> Content) {
        self.store = store
        self.content = content()
    }

    public var body: some View { content.gershwin(store.theme) }
}

/// The settings an app needs for looking the way the user likes: the ClassicThemeChooser (theme, or light and dark
/// while following macOS) and the size of the chrome's pixels. Put it in a GroupBox titled "Appearance".
public struct ClassicAppearanceSettings: View {
    @Environment(\.classicTheme) private var theme
    @Bindable var store: ClassicThemeStore
    let labelWidth: CGFloat

    public init(store: ClassicThemeStore, labelWidth: CGFloat = 50) {
        self.store = store
        self.labelWidth = labelWidth
    }

    public var body: some View {
        let s = theme.scale
        VStack(alignment: .leading, spacing: 10 * s) {
            ClassicThemeChooser(choice: $store.settings.themeChoice, systemIsDark: store.systemIsDark,
                                labelWidth: labelWidth)
            HStack(spacing: 8 * s) {
                Text("Size:").fixedSize().frame(width: labelWidth * s, alignment: .trailing)
                // How big the chrome's pixels are: 1 is pixel for point; 1.5 is a 1999 monitor's.
                ClassicPopUp(selection: $store.settings.interfaceScale, options: [
                    (1, "Small"), (1.5, "As on a Mac OS 9 screen"), (2, "Large"),
                ])
                Spacer(minLength: 0)
            }
        }
    }
}
