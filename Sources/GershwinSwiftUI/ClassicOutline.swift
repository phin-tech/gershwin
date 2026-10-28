import GershwinAppKit
import GershwinChrome
import SwiftUI

/// A tree in a sunken well: rows indented by depth, a disclosure triangle on each that has children, one row
/// selected in the highlight colour. The Finder's list view of folders, or a file browser's sidebar. A node with
/// `children` of nil is a leaf; one with an empty array is a folder with nothing in it.
///
/// Click a row to select it, a triangle to open or close it; double-click opens a folder or, on a leaf, calls
/// `onOpen`. ↑ and ↓ move the selection, → opens a folder (or steps into it), ← closes one (or steps out to its
/// parent), Return is `onOpen`.
public struct ClassicOutline<Node: Identifiable>: View where Node.ID: Hashable & Sendable {
    @Environment(\.classicTheme) private var theme
    @FocusState private var isFocused: Bool
    let roots: [Node]
    let children: KeyPath<Node, [Node]?>
    @Binding var selection: Node.ID?
    @Binding var expanded: Set<Node.ID>
    let title: (Node) -> String
    let badge: (Node) -> String?
    let onOpen: ((Node) -> Void)?

    public init(_ roots: [Node], children: KeyPath<Node, [Node]?>, selection: Binding<Node.ID?>,
                expanded: Binding<Set<Node.ID>>, title: @escaping (Node) -> String,
                badge: @escaping (Node) -> String? = { _ in nil }, onOpen: ((Node) -> Void)? = nil) {
        self.roots = roots
        self.children = children
        _selection = selection
        _expanded = expanded
        self.title = title
        self.badge = badge
        self.onOpen = onOpen
    }

    /// A row as shown: the node, how deep it sits, and where it hangs from.
    struct Row {
        let node: Node
        let depth: Int
        let parent: Node.ID?
        let isFolder: Bool
    }

    /// The rows showing: each root, and under each open folder, its children, depth first.
    static func visibleRows(_ roots: [Node], children: KeyPath<Node, [Node]?>, expanded: Set<Node.ID>) -> [Row] {
        var rows: [Row] = []
        func add(_ nodes: [Node], depth: Int, parent: Node.ID?) {
            for node in nodes {
                let kids = node[keyPath: children]
                rows.append(Row(node: node, depth: depth, parent: parent, isFolder: kids != nil))
                if let kids, expanded.contains(node.id) { add(kids, depth: depth + 1, parent: node.id) }
            }
        }
        add(roots, depth: 0, parent: nil)
        return rows
    }

    public var body: some View {
        let s = theme.scale
        let rows = Self.visibleRows(roots, children: children, expanded: expanded)
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rows, id: \.node.id) { row in
                    rowView(row, s: s)
                }
            }
        }
        .background(Color(theme.palette.well))
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(phases: [.down, .repeat]) { press in handle(press.key, rows: rows) }
        .accessibilityElement(children: .contain)
    }

    private func rowView(_ row: Row, s: CGFloat) -> some View {
        OutlineRowView(depth: row.depth, isFolder: row.isFolder, isOpen: expanded.contains(row.node.id),
                       isSelected: row.node.id == selection, title: title(row.node), badge: badge(row.node),
                       toggle: { toggle(row.node.id) },
                       select: {
                           selection = row.node.id
                           isFocused = true
                       },
                       activate: { activate(row) })
            .equatable()
    }

    private func toggle(_ id: Node.ID) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    private func activate(_ row: Row) {
        if row.isFolder { toggle(row.node.id) } else { onOpen?(row.node) }
    }

    private func handle(_ key: KeyEquivalent, rows: [Row]) -> KeyPress.Result {
        let index = rows.firstIndex { $0.node.id == selection }
        switch key {
        case .upArrow, .downArrow:
            guard !rows.isEmpty else { return .ignored }
            let step = key == .upArrow ? -1 : 1
            let next = index.map { min(max($0 + step, 0), rows.count - 1) } ?? (step < 0 ? rows.count - 1 : 0)
            selection = rows[next].node.id
        case .rightArrow:
            guard let index, rows[index].isFolder else { return .ignored }
            let id = rows[index].node.id
            if !expanded.contains(id) {
                expanded.insert(id)
            } else if index + 1 < rows.count, rows[index + 1].parent == id {
                selection = rows[index + 1].node.id
            }
        case .leftArrow:
            guard let index else { return .ignored }
            let row = rows[index]
            if row.isFolder, expanded.contains(row.node.id) {
                expanded.remove(row.node.id)
            } else if let parent = row.parent {
                selection = parent
            }
        case .return:
            guard let index, let onOpen else { return .ignored }
            if rows[index].isFolder { toggle(rows[index].node.id) } else { onOpen(rows[index].node) }
        default:
            return .ignored
        }
        return .handled
    }
}

/// One row, from plain values only, so SwiftUI skips the rows a selection or an expansion didn't touch (the closures
/// are left out of the comparison).
private struct OutlineRowView: View, @MainActor Equatable {
    @Environment(\.classicTheme) private var theme
    let depth: Int
    let isFolder: Bool
    let isOpen: Bool
    let isSelected: Bool
    let title: String
    let badge: String?
    let toggle: () -> Void
    let select: () -> Void
    let activate: () -> Void

    static func == (a: OutlineRowView, b: OutlineRowView) -> Bool {
        a.depth == b.depth && a.isFolder == b.isFolder && a.isOpen == b.isOpen && a.isSelected == b.isSelected
            && a.title == b.title && a.badge == b.badge
    }

    var body: some View {
        let s = theme.scale
        HStack(spacing: 4 * s) {
            Color.clear.frame(width: CGFloat(depth) * 16 * s, height: 1)
            if isFolder {
                Button(action: toggle) {
                    DisclosureTriangle(isExpanded: isOpen)
                        .frame(width: 10 * s, height: 10 * s)
                        .frame(width: 14 * s, height: 14 * s)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 14 * s, height: 1)
            }
            // The double-click is on the name alone, so one on the triangle isn't also an open.
            HStack {
                Text(title).lineLimit(1)
                Spacer(minLength: 4 * s)
                if let badge { Text(badge).monospacedDigit() }
            }
            .contentShape(Rectangle())
            // Both at once: a tap handler placed after a double-tap one waits out the double-click time to fire.
            .simultaneousGesture(TapGesture(count: 2).onEnded { activate() })
        }
        .padding(.horizontal, 6 * s).padding(.vertical, 2 * s)
        .foregroundStyle(Color(isSelected ? theme.palette.selectedText : theme.palette.text))
        .background(isSelected ? Color(theme.palette.highlight) : .clear)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { select() })
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isFolder ? (isOpen ? "expanded" : "collapsed") : "")
    }
}
