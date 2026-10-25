import Foundation
import SwiftUI
import Testing
@testable import GershwinSwiftUI

private struct Row: Identifiable { let id: Int }

@Test func aDraggedColumnMeasuresFromWhereTheDragBegan() {
    // 150 pixels wide, dragged 60 points right at 1.5x: 40 pixels wider, however many events it took to get there.
    #expect(ClassicTable<Row>.resized(from: 150, by: 60, sign: 1, scale: 1.5) == 190)
    // The rule of the flexible column before a fixed one narrows it as it moves right.
    #expect(ClassicTable<Row>.resized(from: 130, by: 30, sign: -1, scale: 1) == 100)
    // Never narrower than the minimum.
    #expect(ClassicTable<Row>.resized(from: 60, by: -500, sign: 1, scale: 1) == 40)
}

private struct Mail: Identifiable { let id: Int; let from: String; let date: Int }

private let mail = [Mail(id: 1, from: "Porter", date: 30), Mail(id: 2, from: "russell", date: 10),
                    Mail(id: 3, from: "Porter", date: 20), Mail(id: 4, from: "Item 10", date: 0),
                    Mail(id: 5, from: "Item 9", date: 0)]
private var mailColumns: [ClassicColumn<Mail>] {
    [ClassicColumn("From", text: \.from),
     ClassicColumn("Date", text: { String($0.date) }).sorted(on: \.date, startsDescending: true),
     ClassicColumn("", width: .fixed(18), cell: { _ in EmptyView() })]
}

@Test func aTextColumnSortsAsTheFinderDoesAndTiesKeepTheirOrder() {
    let ascending = ClassicTable<Mail>.sorted(mail, by: ClassicSortOrder(column: "From", ascending: true), columns: mailColumns)
    // Numbers by value, case aside, and the two from Porter in the order they came.
    #expect(ascending.map(\.id) == [5, 4, 1, 3, 2])
    let descending = ClassicTable<Mail>.sorted(mail, by: ClassicSortOrder(column: "From", ascending: false), columns: mailColumns)
    #expect(descending.map(\.id) == [2, 1, 3, 4, 5])
}

@Test func aColumnSortsByItsKeyNotItsText() {
    let newest = ClassicTable<Mail>.sorted(mail, by: ClassicSortOrder(column: "Date", ascending: false), columns: mailColumns)
    #expect(newest.map(\.date) == [30, 20, 10, 0, 0])
}

@Test func noOrderOrAnUnsortableColumnLeavesTheRowsAsGiven() {
    #expect(ClassicTable<Mail>.sorted(mail, by: nil, columns: mailColumns).map(\.id) == [1, 2, 3, 4, 5])
    #expect(ClassicTable<Mail>.sorted(mail, by: ClassicSortOrder(column: "", ascending: true), columns: mailColumns).map(\.id) == [1, 2, 3, 4, 5])
    #expect(!mailColumns[2].isSortable && mailColumns[0].isSortable)
}

@Test func aHeaderClickSortsItsFirstWayThenReverses() {
    let from = ClassicTable<Mail>.clicked(mailColumns[0], current: nil)
    #expect(from == ClassicSortOrder(column: "From", ascending: true))
    #expect(ClassicTable<Mail>.clicked(mailColumns[0], current: from) == ClassicSortOrder(column: "From", ascending: false))
    // A date is read newest first.
    #expect(ClassicTable<Mail>.clicked(mailColumns[1], current: from) == ClassicSortOrder(column: "Date", ascending: false))
}
