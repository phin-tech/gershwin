import CoreGraphics
import Foundation
import Testing
@testable import GershwinChrome

private let area = CGRect(x: 0, y: 0, width: 205, height: 105)

@Test func onePaneFillsTheSpace() {
    let tree = SplitTree(pane: "a")
    let geometry = tree.layout(in: area, divider: 5)
    #expect(geometry.frames == ["a": area] && geometry.dividers.isEmpty)
}

@Test func splittingSideBySideGivesTheNewPaneTheRight() throws {
    var tree = SplitTree(pane: "a")
    tree.split("a", along: .sideBySide, adding: "b")
    #expect(tree.panes == ["a", "b"])
    let g = tree.layout(in: area, divider: 5)
    #expect(g.frames["a"] == CGRect(x: 0, y: 0, width: 100, height: 105))
    #expect(g.frames["b"] == CGRect(x: 105, y: 0, width: 100, height: 105))
    #expect(g.dividers.map(\.rect) == [CGRect(x: 100, y: 0, width: 5, height: 105)])
}

@Test func splitsNestAndStack() {
    var tree = SplitTree(pane: "a")
    tree.split("a", along: .sideBySide, adding: "b")
    tree.split("b", along: .stacked, adding: "c")
    #expect(tree.panes == ["a", "b", "c"])
    let g = tree.layout(in: area, divider: 5)
    #expect(g.frames["b"] == CGRect(x: 105, y: 0, width: 100, height: 50))
    #expect(g.frames["c"] == CGRect(x: 105, y: 55, width: 100, height: 50))
    #expect(g.dividers.count == 2)
}

@Test func closingAPaneGivesItsSpaceToTheOtherSide() {
    var tree = SplitTree(pane: "a")
    tree.split("a", along: .sideBySide, adding: "b")
    tree.split("b", along: .stacked, adding: "c")
    let closedB = tree.close("b")
    #expect(closedB && tree.panes == ["a", "c"])
    #expect(tree.layout(in: area, divider: 5).frames["c"] == CGRect(x: 105, y: 0, width: 100, height: 105))
    let closedA = tree.close("a")
    #expect(closedA && tree.panes == ["c"])
    let closedLast = tree.close("c")
    #expect(!closedLast && tree.panes == ["c"])   // the last one stays
}

@Test func draggingADividerKeepsBothSidesAtLeastTheMinimum() throws {
    var tree = SplitTree(pane: "a")
    tree.split("a", along: .sideBySide, adding: "b")
    let divider = try #require(tree.layout(in: area, divider: 5).dividers.first)
    tree.move(divider, to: 150, thickness: 5, minimum: 40)
    #expect(tree.layout(in: area, divider: 5).frames["a"]?.width == 150)
    tree.move(divider, to: 199, thickness: 5, minimum: 40)
    #expect(tree.layout(in: area, divider: 5).frames["b"]?.width == 40)
    tree.move(divider, to: -50, thickness: 5, minimum: 40)
    #expect(tree.layout(in: area, divider: 5).frames["a"]?.width == 40)
}

@Test func aNestedDividerMovesOnlyItsOwnSplit() throws {
    var tree = SplitTree(pane: "a")
    tree.split("a", along: .sideBySide, adding: "b")
    tree.split("b", along: .stacked, adding: "c")
    let inner = try #require(tree.layout(in: area, divider: 5).dividers.first { $0.axis == .stacked })
    tree.move(inner, to: 20, thickness: 5, minimum: 10)
    let g = tree.layout(in: area, divider: 5)
    #expect(g.frames["b"]?.height == 20 && g.frames["a"]?.width == 100)
}

@Test func neighboursAreTheNearestPaneThatWay() {
    var tree = SplitTree(pane: "a")
    tree.split("a", along: .sideBySide, adding: "b")
    tree.split("b", along: .stacked, adding: "c")
    #expect(tree.neighbor(of: "a", .right, in: area, divider: 5) == "b")
    #expect(tree.neighbor(of: "b", .down, in: area, divider: 5) == "c")
    #expect(tree.neighbor(of: "c", .left, in: area, divider: 5) == "a")
    #expect(tree.neighbor(of: "a", .left, in: area, divider: 5) == nil)
}

@Test func aTreeIsSavedAndReadBack() throws {
    var tree = SplitTree(pane: UUID())
    let b = UUID()
    tree.split(tree.panes[0], along: .stacked, adding: b, fraction: 0.3)
    #expect(try JSONDecoder().decode(SplitTree<UUID>.self, from: JSONEncoder().encode(tree)) == tree)
}

@Test func aClosedPanesSpaceGoesToItsSplitsOtherSide() {
    var tree = SplitTree(pane: "a")
    tree.split("a", along: .sideBySide, adding: "b")
    tree.split("b", along: .stacked, adding: "c")
    #expect(tree.heir(of: "c") == "b")        // below b: b takes it
    #expect(tree.heir(of: "b") == "c")
    #expect(tree.heir(of: "a") == "b")        // the right column's first
    #expect(SplitTree(pane: "z").heir(of: "z") == nil)
}
