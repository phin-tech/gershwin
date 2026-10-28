import GershwinAppKit
import SwiftUI

/// Labels in a column at the left, right-aligned, and their controls in a column beside them, as a classic dialog
/// laid out its edit-text fields and pop-ups.
public struct ClassicForm<Content: View>: View {
    @Environment(\.classicTheme) private var theme
    let content: Content

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8 * theme.scale, verticalSpacing: 8 * theme.scale) {
            content
        }
    }
}

/// One line of a ClassicForm: `label`, then the control.
public struct ClassicFormRow<Content: View>: View {
    let label: String
    let content: Content

    public init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    public var body: some View {
        GridRow {
            Text(label).gridColumnAlignment(.trailing)
            content
        }
    }
}
