import Foundation
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
