import GershwinAppKit
import GershwinChrome
import SwiftUI

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

    public init(_ title: String, width: Width = .flexible, text: @escaping (Row) -> String) {
        id = title
        self.title = title
        self.width = width
        self.text = text
    }
}

/// A dense, multi-column list: one-pixel rules, clipped text, a header whose columns resize by dragging the rule beside
/// them, and one selected row in the highlight colour. Rows are one line of text each, in the order given.
public struct ClassicTable<Row: Identifiable>: View where Row.ID: Hashable & Sendable {
    @Environment(\.classicTheme) private var theme
    let rows: [Row]
    let columns: [ClassicColumn<Row>]
    @Binding var selection: Row.ID?
    let emphasized: (Row) -> Bool

    /// Widths the person has dragged columns to, by column id, in Mac OS 9 pixels.
    @State private var dragged: [String: CGFloat] = [:]
    /// The width a column had when its drag began, so the drag measures from there, not from each event.
    @State private var dragStart: [String: CGFloat] = [:]

    /// `emphasized` rows are drawn bold (unread mail, say).
    public init(_ rows: [Row], columns: [ClassicColumn<Row>], selection: Binding<Row.ID?>,
                emphasized: @escaping (Row) -> Bool = { _ in false }) {
        self.rows = rows
        self.columns = columns
        _selection = selection
        self.emphasized = emphasized
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
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        let selected = row.id == selection
                        HStack(spacing: 0) {
                            ForEach(columns) { column in cell(column.text(row), column: column, bold: emphasized(row)) }
                        }
                        .frame(height: 18 * s)
                        .foregroundStyle(Color(selected ? theme.palette.selectedText : theme.palette.text))
                        .background(selected ? Color(theme.palette.highlight) : .clear)
                        .contentShape(Rectangle())
                        .onTapGesture { selection = row.id }
                    }
                }
            }
            .background(Color(theme.palette.well))
        }
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
        return HStack(spacing: 0) {
            Text(column.title).lineLimit(1).padding(.horizontal, 6 * s).frame(maxWidth: .infinity, alignment: .leading)
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

    private func cell(_ text: String, column: ClassicColumn<Row>, bold: Bool) -> some View {
        let width = ownWidth(column).map { $0 * theme.scale }
        return Text(text).lineLimit(1).truncationMode(.tail).fontWeight(bold ? .bold : .regular)
            .padding(.horizontal, 6 * theme.scale)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    /// A column's new width, in Mac OS 9 pixels, when its rule has been dragged `translation` points from where the
    /// drag began (`sign` is -1 when the rule belongs to the column before it). No narrower than `minimum`.
    static func resized(from start: CGFloat, by translation: CGFloat, sign: CGFloat, scale: CGFloat, minimum: CGFloat = 40) -> CGFloat {
        max(minimum, start + sign * translation / scale)
    }
}
