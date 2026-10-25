import GershwinAppKit
import GershwinChrome
import SwiftUI

/// The strip across the top of a window: its buttons and fields in a row, over a rule. Put a `Spacer()` between
/// the ones that go left and the ones that go right.
public struct ClassicToolbar<Content: View>: View {
    @Environment(\.classicTheme) private var theme
    let content: Content

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        let s = theme.scale
        content
            .frame(maxWidth: .infinity)
            .padding(6 * s)
            .overlay(alignment: .bottom) { Rectangle().fill(Color(theme.palette.dark)).frame(height: 1) }
    }
}
