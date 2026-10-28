import GershwinAppKit
import GershwinChrome
import SwiftUI

/// Items as icons with their names beneath, wrapping across the width: the Finder's icon view. The chosen one has
/// its name in the highlight colour. Click to choose, double-click for `onOpen`.
public struct ClassicIconGrid<Item: Identifiable, Icon: View>: View where Item.ID: Hashable & Sendable {
    @Environment(\.classicTheme) private var theme
    let items: [Item]
    @Binding var selection: Item.ID?
    let title: (Item) -> String
    let icon: (Item) -> Icon
    let onOpen: ((Item) -> Void)?

    public init(_ items: [Item], selection: Binding<Item.ID?>, title: @escaping (Item) -> String,
                onOpen: ((Item) -> Void)? = nil, @ViewBuilder icon: @escaping (Item) -> Icon) {
        self.items = items
        _selection = selection
        self.title = title
        self.icon = icon
        self.onOpen = onOpen
    }

    public var body: some View {
        let s = theme.scale
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80 * s), spacing: 8 * s, alignment: .top)],
                      spacing: 8 * s) {
                ForEach(items) { item in
                    let selected = item.id == selection
                    VStack(spacing: 3 * s) {
                        icon(item).frame(width: 32 * s, height: 32 * s)
                        Text(title(item)).lineLimit(2).multilineTextAlignment(.center)
                            .padding(.horizontal, 3 * s)
                            .foregroundStyle(Color(selected ? theme.palette.selectedText : theme.palette.text))
                            .background(selected ? Color(theme.palette.highlight) : .clear)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen?(item) })
                    .simultaneousGesture(TapGesture().onEnded { selection = item.id })
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(8 * s)
        }
        .background(Color(theme.palette.well))
        // Clicking the empty well chooses nothing.
        .onTapGesture { selection = nil }
    }
}
