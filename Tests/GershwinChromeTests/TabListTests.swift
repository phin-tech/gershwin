import CoreGraphics
import Testing
@testable import GershwinChrome

private func list(_ ids: [Int], selecting selected: Int? = nil) -> TabList<Int> {
    var tabs = TabList<Int>()
    for id in ids { tabs.add(id) }
    if let selected { tabs.select(selected) }
    return tabs
}

@Test func newTabGoesJustAfterTheFrontOneAndComesForward() {
    var tabs = list([1, 2, 3], selecting: 1)
    tabs.add(4)
    #expect(tabs.ids == [1, 4, 2, 3])
    #expect(tabs.selected == 4)
}

@Test func closingTheFrontTabBringsForwardTheOneToItsRight() {
    var tabs = list([1, 2, 3], selecting: 2)
    tabs.close(2)
    #expect(tabs.ids == [1, 3])
    #expect(tabs.selected == 3)
}

@Test func closingTheLastTabInFrontBringsForwardTheOneToItsLeft() {
    var tabs = list([1, 2, 3], selecting: 3)
    tabs.close(3)
    #expect(tabs.selected == 2)
}

@Test func closingATabBehindLeavesTheFrontOneAlone() {
    var tabs = list([1, 2, 3], selecting: 1)
    tabs.close(3)
    #expect(tabs.selected == 1)
}

@Test func closingTheOnlyTabLeavesNoneSelected() {
    var tabs = list([1])
    tabs.close(1)
    #expect(tabs.ids.isEmpty)
    #expect(tabs.selected == nil)
}

@Test func nextAndPreviousWrapAround() {
    var tabs = list([1, 2, 3], selecting: 3)
    tabs.selectAdjacent(by: 1)
    #expect(tabs.selected == 1)
    tabs.selectAdjacent(by: -1)
    #expect(tabs.selected == 3)
}

@Test func selectingByNumberIgnoresTabsThatDontExist() {
    var tabs = list([1, 2, 3], selecting: 1)
    tabs.select(index: 2)
    #expect(tabs.selected == 3)
    tabs.select(index: 8)
    #expect(tabs.selected == 3)
}

@Test func tabsAreAsWideAsTheirTitlesWithinLimits() {
    let bar = CGRect(x: 0, y: 0, width: 600, height: 22)
    let tabs = TabStripLayout.tabs(in: bar, titleWidths: [10, 100, 900])
    #expect(tabs.map(\.width) == [TabStripLayout.minimumWidth, 128, TabStripLayout.maximumWidth])
    #expect(tabs[0].minX == TabStripLayout.inset)
    #expect(tabs[1].minX == tabs[0].maxX)
}

@Test func tabsThatDontFitAreNarrowedEvenly() {
    let bar = CGRect(x: 0, y: 0, width: 312, height: 22)
    let tabs = TabStripLayout.tabs(in: bar, titleWidths: [200, 200, 200])
    #expect(tabs.allSatisfy { $0.width == 100 })
    #expect(tabs.last!.maxX <= bar.maxX - TabStripLayout.inset)
}

@Test func documentWithTabsPutsTheBarBetweenTitleBarAndTerminal() throws {
    let layout = WindowChromeLayout(bounds: CGRect(x: 0, y: 0, width: 600, height: 400), style: .document,
                                    showsTabBar: true)
    let bar = try #require(layout.tabBar)
    #expect(bar == CGRect(x: 6, y: 21, width: 588, height: 22))
    #expect(layout.main.minY == bar.maxY)
    #expect(layout.scrollBar?.minY == bar.maxY)
    #expect(layout.main.height == 335)   // 357 without the bar, less its 22
}

@Test func collapsedWindowHasNoTabBar() {
    let layout = WindowChromeLayout(bounds: CGRect(x: 0, y: 0, width: 600, height: 22), style: .document,
                                    isCollapsed: true, showsTabBar: true)
    #expect(layout.tabBar == nil)
}
