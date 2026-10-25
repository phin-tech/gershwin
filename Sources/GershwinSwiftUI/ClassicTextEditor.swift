import GershwinAppKit
import GershwinChrome
import SwiftUI

/// A multi-line text area in a sunken well, for writing in (ClassicField is the one-line one).
public struct ClassicTextEditor: View {
    @Environment(\.classicTheme) private var theme
    @Binding var text: String

    public init(text: Binding<String>) { _text = text }

    public var body: some View {
        TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .padding(4 * theme.scale)
            .background(Color(theme.palette.well))
            .overlay(Rectangle().stroke(Color(theme.palette.dark), lineWidth: 1))
    }
}
