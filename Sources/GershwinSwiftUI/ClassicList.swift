import GershwinAppKit
import GershwinChrome
import SwiftUI

/// A single-column list in a sunken well, one row selected in the highlight colour, each row with an optional badge
/// at its right (a count, say): the Finder's list, or a mail program's mailboxes.
public struct ClassicList<Item: Identifiable>: View where Item.ID: Hashable & Sendable {
    @Environment(\.classicTheme) private var theme
    let items: [Item]
    @Binding var selection: Item.ID?
    let title: (Item) -> String
    let badge: (Item) -> String?

    public init(_ items: [Item], selection: Binding<Item.ID?>, title: @escaping (Item) -> String,
                badge: @escaping (Item) -> String? = { _ in nil }) {
        self.items = items
        _selection = selection
        self.title = title
        self.badge = badge
    }

    public var body: some View {
        let s = theme.scale
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    let selected = item.id == selection
                    HStack {
                        Text(title(item)).lineLimit(1)
                        Spacer(minLength: 4 * s)
                        if let badge = badge(item) { Text(badge).monospacedDigit() }
                    }
                    .padding(.horizontal, 8 * s).padding(.vertical, 2 * s)
                    .foregroundStyle(Color(selected ? theme.palette.selectedText : theme.palette.text))
                    .background(selected ? Color(theme.palette.highlight) : .clear)
                    .contentShape(Rectangle())
                    .onTapGesture { selection = item.id }
                }
            }
        }
        .background(Color(theme.palette.well))
    }
}
