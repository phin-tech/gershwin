import GershwinAppKit
import GershwinChrome
import SwiftUI

/// Which column a ClassicTable is sorted by (its id: the column's title), and which way.
public struct ClassicSortOrder: Equatable, Hashable, Codable, Sendable {
    public var column: String
    public var ascending: Bool

    public init(column: String, ascending: Bool) {
        self.column = column
        self.ascending = ascending
    }
}

/// One column of a ClassicTable. Widths are in Mac OS 9 pixels (the table scales them with the theme).
public struct ClassicColumn<Row>: Identifiable {
    public enum Width: Sendable {
        /// This wide to begin with, and resizable by dragging its header's right rule.
        case fixed(CGFloat)
        /// Whatever is left over. Dragging its right rule resizes the fixed column after it, if there is one.
        case flexible
    }

    public let id: String
    public let title: String
    public let width: Width
    public let text: (Row) -> String
    /// What to draw instead of the text, for a column of icons.
    let view: ((Row) -> AnyView)?
    /// Whether one row goes before another, sorted ascending by this column; nil if it can't be sorted by.
    let areInIncreasingOrder: ((Row, Row) -> Bool)?
    /// Whether the first click on its header sorts it descending (newest first, largest first).
    let startsDescending: Bool

    public var isSortable: Bool { areInIncreasingOrder != nil }

    /// A column of text, sorted by that text as the Finder sorts names (numbers by value, case aside) unless
    /// `sortable` is false or `sorted(on:)` says otherwise.
    public init(_ title: String, width: Width = .flexible, sortable: Bool = true, text: @escaping (Row) -> String) {
        id = title
        self.title = title
        self.width = width
        self.text = text
        view = nil
        areInIncreasingOrder = sortable ? { text($0).localizedStandardCompare(text($1)) == .orderedAscending } : nil
        startsDescending = false
    }

    /// A column whose cells are views: an icon, say. Draw them to fit a row, in the row's text colour. Not sortable
    /// unless given an order with `sorted(on:)` or `sorted(by:)`.
    public init<Cell: View>(_ title: String, width: Width, @ViewBuilder cell: @escaping (Row) -> Cell) {
        id = title
        self.title = title
        self.width = width
        text = { _ in "" }
        view = { AnyView(cell($0)) }
        areInIncreasingOrder = nil
        startsDescending = false
    }

    private init(_ column: ClassicColumn, order: ((Row, Row) -> Bool)?, startsDescending: Bool) {
        id = column.id
        title = column.title
        width = column.width
        text = column.text
        view = column.view
        areInIncreasingOrder = order
        self.startsDescending = startsDescending
    }

    /// Sorted by `key` rather than the text shown: a date by the date, not by how it's written. `startsDescending` for
    /// a column read largest first, as dates and sizes usually are.
    public func sorted<Key: Comparable>(on key: @escaping (Row) -> Key, startsDescending: Bool = false) -> ClassicColumn {
        ClassicColumn(self, order: { key($0) < key($1) }, startsDescending: startsDescending)
    }

    /// Sorted by an order of your own.
    public func sorted(by areInIncreasingOrder: @escaping (Row, Row) -> Bool, startsDescending: Bool = false) -> ClassicColumn {
        ClassicColumn(self, order: areInIncreasingOrder, startsDescending: startsDescending)
    }
}

/// A dense, multi-column list: one-pixel rules, clipped text, a header whose columns resize by dragging the rule beside
/// them, and one selected row in the highlight colour. Rows are one line of text each.
///
/// Clicking a sortable column's header sorts by it, as the Finder's list views do; clicking it again reverses it. The
/// sorted column's header is darker, with a triangle pointing the way it runs.
public struct ClassicTable<Row: Identifiable>: View where Row.ID: Hashable & Sendable {
    @Environment(\.classicTheme) private var theme
    let rows: [Row]
    let columns: [ClassicColumn<Row>]
    @Binding var selection: Row.ID?
    let emphasized: (Row) -> Bool
    let marked: (Row) -> Bool
    let onOpen: ((Row.ID) -> Void)?
    /// The caller's sort order, when it keeps one; nil when the table keeps its own.
    let sortOrder: Binding<ClassicSortOrder?>?

    /// The table's own sort order, when the caller didn't give one. Nil shows the rows as given.
    @State private var ownSortOrder: ClassicSortOrder?

    /// Widths the person has dragged columns to, by column id, in Mac OS 9 pixels.
    @State private var dragged: [String: CGFloat] = [:]
    /// The width a column had when its drag began, so the drag measures from there, not from each event.
    @State private var dragStart: [String: CGFloat] = [:]

    /// `emphasized` rows are drawn bold (unread mail, say); `marked` ones tinted with the highlight colour (checked, to
    /// act on together), less than the selected one is; `onOpen` hears of a double-click on a row.
    ///
    /// Without `sortOrder` the table sorts the rows itself, by each column's order, and forgets how when it goes. With
    /// it, the caller owns the order and sorts the rows (in a database query, say, or to keep it between launches): the
    /// table shows them as given, marks the header, and sets the binding when a header is clicked.
    public init(_ rows: [Row], columns: [ClassicColumn<Row>], selection: Binding<Row.ID?>,
                sortOrder: Binding<ClassicSortOrder?>? = nil,
                emphasized: @escaping (Row) -> Bool = { _ in false }, marked: @escaping (Row) -> Bool = { _ in false },
                onOpen: ((Row.ID) -> Void)? = nil) {
        self.rows = rows
        self.columns = columns
        _selection = selection
        self.sortOrder = sortOrder
        self.emphasized = emphasized
        self.marked = marked
        self.onOpen = onOpen
    }

    private var currentSortOrder: ClassicSortOrder? { sortOrder?.wrappedValue ?? ownSortOrder }

    /// The rows in the order shown: as given when the caller sorts them, else sorted here.
    private var shownRows: [Row] {
        sortOrder == nil ? Self.sorted(rows, by: ownSortOrder, columns: columns) : rows
    }

    public var body: some View {
        let s = theme.scale
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in header(column, at: index) }
            }
            .frame(height: 20 * s)
            .background(Color(theme.palette.background))
            Rectangle().fill(Color(theme.palette.dark)).frame(height: 1)
            ScrollViewReader { proxy in
                rowList
                    // The selection set from elsewhere (the keys, say) may be out of sight: the list follows it.
                    .onChange(of: selection) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
            }
        }
    }

    private var rowList: some View {
        let s = theme.scale
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(shownRows) { row in
                    let selected = row.id == selection
                    HStack(spacing: 0) {
                        ForEach(columns) { column in cell(row, column: column, bold: emphasized(row)) }
                    }
                    .frame(height: 18 * s)
                    .foregroundStyle(Color(selected ? theme.palette.selectedText : theme.palette.text))
                    .background(selected ? Color(theme.palette.highlight)
                                : marked(row) ? Color(theme.palette.highlight).opacity(0.3) : .clear)
                    .contentShape(Rectangle())
                    .onTapGesture { selection = row.id }
                    // Alongside, not instead: a single click selects at once, without waiting to see if a second comes.
                    .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen?(row.id) })
                }
            }
        }
        .background(Color(theme.palette.well))
    }

    // MARK: Columns

    /// A column's own width, if it has one: dragged to, or fixed to begin with.
    private func ownWidth(_ column: ClassicColumn<Row>) -> CGFloat? {
        if let width = dragged[column.id] { return width }
        if case .fixed(let width) = column.width { return width }
        return nil
    }

    /// The column the rule at the right of column `index` resizes, and whether dragging right widens it.
    private func handle(at index: Int) -> (column: ClassicColumn<Row>, sign: CGFloat)? {
        guard index < columns.count - 1 else { return nil }
        if ownWidth(columns[index]) != nil { return (columns[index], 1) }
        if ownWidth(columns[index + 1]) != nil { return (columns[index + 1], -1) }
        return nil
    }

    private func header(_ column: ClassicColumn<Row>, at index: Int) -> some View {
        let s = theme.scale
        let sorted = currentSortOrder?.column == column.id ? currentSortOrder : nil
        return HStack(spacing: 0) {
            HStack(spacing: 4 * s) {
                Text(column.title).lineLimit(1)
                Spacer(minLength: 0)
                if let sorted { SortTriangle(ascending: sorted.ascending).frame(width: 7 * s, height: 4 * s) }
            }
            .padding(.horizontal, 6 * s)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            // The sorted column's header is a shade darker, as the Finder's was.
            .background(sorted == nil ? Color.clear : Color(theme.palette.dark).opacity(0.25))
            .contentShape(Rectangle())
            .onTapGesture { if column.isSortable { setSortOrder(Self.clicked(column, current: currentSortOrder)) } }
            .accessibilityAddTraits(column.isSortable ? .isButton : [])
            if let (target, sign) = handle(at: index) {
                Rectangle().fill(Color(theme.palette.dark)).frame(width: 1)
                    .contentShape(Rectangle().inset(by: -3 * s))
                    .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { drag in
                            let start = dragStart[target.id] ?? ownWidth(target) ?? 0
                            dragStart[target.id] = start
                            dragged[target.id] = Self.resized(from: start, by: drag.translation.width, sign: sign, scale: s)
                        }
                        .onEnded { _ in dragStart[target.id] = nil })
            }
        }
        .frame(width: ownWidth(column).map { $0 * s })
        .frame(maxWidth: ownWidth(column) == nil ? .infinity : nil)
    }

    private func cell(_ row: Row, column: ClassicColumn<Row>, bold: Bool) -> some View {
        let width = ownWidth(column).map { $0 * theme.scale }
        return Group {
            if let view = column.view {
                view(row)
            } else {
                Text(column.text(row)).lineLimit(1).truncationMode(.tail).fontWeight(bold ? .bold : .regular)
            }
        }
        .padding(.horizontal, 6 * theme.scale)
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    // MARK: Sorting

    private func setSortOrder(_ order: ClassicSortOrder) {
        if let sortOrder { sortOrder.wrappedValue = order } else { ownSortOrder = order }
    }

    /// The order after `column`'s header is clicked: the other way if it was already sorted by, else its first way.
    nonisolated static func clicked(_ column: ClassicColumn<Row>, current: ClassicSortOrder?) -> ClassicSortOrder {
        if let current, current.column == column.id { return ClassicSortOrder(column: column.id, ascending: !current.ascending) }
        return ClassicSortOrder(column: column.id, ascending: !column.startsDescending)
    }

    /// `rows` sorted by `order`, rows the column can't tell apart left in the order given. As given if there's no
    /// order, or its column isn't one of `columns` or can't be sorted by.
    nonisolated static func sorted(_ rows: [Row], by order: ClassicSortOrder?, columns: [ClassicColumn<Row>]) -> [Row] {
        guard let order, let before = columns.first(where: { $0.id == order.column })?.areInIncreasingOrder else { return rows }
        return rows.enumerated().sorted { a, b in
            if before(a.element, b.element) { return order.ascending }
            if before(b.element, a.element) { return !order.ascending }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// A column's new width, in Mac OS 9 pixels, when its rule has been dragged `translation` points from where the
    /// drag began (`sign` is -1 when the rule belongs to the column before it). No narrower than `minimum`.
    nonisolated static func resized(from start: CGFloat, by translation: CGFloat, sign: CGFloat, scale: CGFloat, minimum: CGFloat = 40) -> CGFloat {
        max(minimum, start + sign * translation / scale)
    }
}


/// The triangle in a sorted column's header: pointing up for ascending, down for descending.
private struct SortTriangle: View {
    let ascending: Bool
    @Environment(\.classicTheme) private var theme

    var body: some View {
        Canvas { context, size in
            var triangle = Path()
            let (top, bottom) = ascending ? (0.0, size.height) : (size.height, 0.0)
            triangle.move(to: CGPoint(x: size.width / 2, y: top))
            triangle.addLine(to: CGPoint(x: size.width, y: bottom))
            triangle.addLine(to: CGPoint(x: 0, y: bottom))
            triangle.closeSubpath()
            context.fill(triangle, with: .color(Color(theme.palette.text)))
        }
        .accessibilityLabel(ascending ? "Sorted ascending" : "Sorted descending")
    }
}
