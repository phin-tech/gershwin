import GershwinAppKit
import GershwinChrome
import SwiftUI

/// What a sidebar row's lamp says, drawn as a small square lit in the theme's colours, as the Control Strip's were.
public enum ClassicSidebarMarker: String, Sendable, Equatable, CaseIterable {
    /// An empty square: nothing happening.
    case off
    /// Filled with the highlight colour.
    case on
    /// Striped across: working.
    case busy
    /// Filled red: wants attention.
    case alert
}

public struct ClassicSidebarItem: Identifiable, Sendable, Equatable {
    public var id: String
    public var title: String
    /// A line of smaller text under the title.
    public var detail: String?
    /// At the row's right: a count, say.
    public var badge: String?
    public var marker: ClassicSidebarMarker?

    public init(id: String, title: String, detail: String? = nil, badge: String? = nil, marker: ClassicSidebarMarker? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.badge = badge
        self.marker = marker
    }
}

public struct ClassicSidebarSection: Identifiable, Sendable, Equatable {
    public var id: String { title ?? items.first?.id ?? "" }
    public var title: String?
    public var items: [ClassicSidebarItem]

    public init(title: String? = nil, items: [ClassicSidebarItem]) {
        self.title = title
        self.items = items
    }
}

/// A column of buttons in a sunken well, in sections under small bold headings: a window's source list, or the
/// workspaces of a session. Clicking a row selects it and calls `onActivate` with its id, once, on release.
public struct ClassicSidebar: View {
    @Environment(\.classicTheme) private var theme
    let sections: [ClassicSidebarSection]
    @Binding var selection: String?
    let onActivate: (String) -> Void

    public init(_ sections: [ClassicSidebarSection], selection: Binding<String?>,
                onActivate: @escaping (String) -> Void = { _ in }) {
        self.sections = sections
        _selection = selection
        self.onActivate = onActivate
    }

    public var body: some View {
        let s = theme.scale
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    if let title = section.title {
                        Text(title)
                            .font(Font(ClassicTheme.smallFont(size: 10 * s)).bold())
                            .foregroundStyle(Color(theme.palette.disabledText))
                            .padding(.horizontal, 8 * s).padding(.top, 8 * s).padding(.bottom, 2 * s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(section.items) { item in row(item) }
                }
            }
            .padding(.vertical, 2 * s)
        }
        .background(Color(theme.palette.well))
    }

    private func row(_ item: ClassicSidebarItem) -> some View {
        let s = theme.scale
        let selected = item.id == selection
        let ink = Color(selected ? theme.palette.selectedText : theme.palette.text)
        return HStack(spacing: 6 * s) {
            if let marker = item.marker { lamp(marker, selected: selected) }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title).lineLimit(1)
                if let detail = item.detail {
                    Text(detail).font(Font(ClassicTheme.smallFont(size: 10 * s))).lineLimit(1).opacity(0.7)
                }
            }
            Spacer(minLength: 4 * s)
            if let badge = item.badge { Text(badge).monospacedDigit() }
        }
        .padding(.horizontal, 8 * s).padding(.vertical, 3 * s)
        .foregroundStyle(ink)
        .background(selected ? Color(theme.palette.highlight) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selection = item.id
            onActivate(item.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// A 9-point square: a bevelled well, lit by its marker.
    private func lamp(_ marker: ClassicSidebarMarker, selected: Bool) -> some View {
        let s = theme.scale
        let lit: RGB = marker == .alert ? RGB(0xCC2222) : (selected ? theme.palette.selectedText : theme.palette.highlight)
        return ZStack {
            Rectangle().fill(Color(theme.palette.well))
            switch marker {
            case .off: EmptyView()
            case .on, .alert: Rectangle().fill(Color(lit)).padding(2 * s)
            case .busy:
                // Horizontal stripes, a pixel of each.
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { row in
                        Rectangle().fill(row % 2 == 0 ? Color(lit) : .clear)
                    }
                }.padding(2 * s)
            }
        }
        .frame(width: 10 * s, height: 10 * s)
        .overlay(Rectangle().stroke(Color(theme.palette.dark), lineWidth: max(1, s.rounded())))
    }
}
