import Foundation
import SwiftUI
import Testing
@testable import GershwinSwiftUI

private struct Entry: Identifiable {
    let id: String
    var children: [Entry]?
}

private let tree = [
    Entry(id: "Documents", children: [Entry(id: "Letters", children: [Entry(id: "a.txt", children: nil)]),
                                      Entry(id: "b.txt", children: nil)]),
    Entry(id: "Empty", children: []),
    Entry(id: "readme", children: nil),
]

@MainActor @Test func anOutlineShowsOnlyTheRootsUntilFoldersAreOpened() {
    let rows = ClassicOutline<Entry>.visibleRows(tree, children: \.children, expanded: [])
    #expect(rows.map(\.node.id) == ["Documents", "Empty", "readme"])
    #expect(rows.map(\.isFolder) == [true, true, false])
}

@MainActor @Test func anOpenFolderShowsItsChildrenIndentedBelowIt() {
    let rows = ClassicOutline<Entry>.visibleRows(tree, children: \.children, expanded: ["Documents", "Letters"])
    #expect(rows.map(\.node.id) == ["Documents", "Letters", "a.txt", "b.txt", "Empty", "readme"])
    #expect(rows.map(\.depth) == [0, 1, 2, 1, 0, 0])
    #expect(rows[2].parent == "Letters")
}

@MainActor @Test func aFolderInsideAClosedOneStaysHidden() {
    // "Letters" is open, but "Documents" above it is not, so nothing under it shows.
    let rows = ClassicOutline<Entry>.visibleRows(tree, children: \.children, expanded: ["Letters"])
    #expect(rows.map(\.node.id) == ["Documents", "Empty", "readme"])
}

@MainActor @Test func theDatePickerStepsOnePartAndCarriesAsTheCalendarDoes() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let jan31 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
    let feb = ClassicDatePicker.adding(1, to: .month, of: jan31, calendar: calendar)
    #expect(calendar.dateComponents([.month, .day], from: feb) == DateComponents(month: 2, day: 28))
    let next = ClassicDatePicker.adding(1, to: .day, of: jan31, calendar: calendar)
    #expect(calendar.dateComponents([.month, .day], from: next) == DateComponents(month: 2, day: 1))
    let year = ClassicDatePicker.adding(-1, to: .year, of: jan31, calendar: calendar)
    #expect(calendar.component(.year, from: year) == 2025)
}
