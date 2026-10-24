import CoreGraphics
import Testing
@testable import GershwinChrome

private let window = CGRect(x: 0, y: 0, width: 600, height: 400)
private typealias M = BeOSMetrics

@Test func oneTabIsAsWideAsItsTitleAndBoxes() {
    let layout = BeOSChromeLayout(bounds: window, style: .document, titleWidths: [100])
    let tab = layout.tabs[0]
    #expect(tab.minX == 0)
    #expect(tab.height == M.tabHeight)
    #expect(tab.width == 100 + M.boxInset * 2 + M.boxSize * 2 + M.titleGap * 2)
    #expect(tab.contains(layout.closeBox))
    #expect(tab.contains(layout.zoomBox!))
    #expect(layout.titles[0].minX == layout.closeBox.maxX + M.titleGap)
    #expect(layout.titles[0].maxX == layout.zoomBox!.minX - M.titleGap)
}

@Test func shortTitleStillGetsAUsableTab() {
    let layout = BeOSChromeLayout(bounds: window, style: .document, titleWidths: [4])
    #expect(layout.tabs[0].width == M.minimumTabWidth)
}

@Test func panelTabHasNoZoomBox() {
    let layout = BeOSChromeLayout(bounds: window, style: .panel, titleWidths: [100])
    #expect(layout.zoomBox == nil)
    #expect(layout.scrollBar == nil)
    #expect(layout.main == layout.content)
}

@Test func bodyIsBelowTheTabsAndTheContentInsideTheFrame() throws {
    let layout = BeOSChromeLayout(bounds: window, style: .document, titleWidths: [100])
    #expect(layout.body == CGRect(x: 0, y: M.tabHeight, width: 600, height: 400 - M.tabHeight))
    #expect(layout.content == layout.body.insetBy(dx: M.frameWidth, dy: M.frameWidth))
    let scroll = try #require(layout.scrollBar), grow = try #require(layout.growBox)
    #expect(scroll.maxX == layout.content.maxX)
    #expect(grow.minY == scroll.maxY)
    #expect(grow.maxY == layout.content.maxY)
    #expect(layout.main.maxX == scroll.minX)
    #expect(layout.main.height == layout.content.height)
}

@Test func severalTabsSitSideBySideWithTheZoomBoxOnlyOnTheFrontOne() {
    let layout = BeOSChromeLayout(bounds: window, style: .document, titleWidths: [80, 80, 80], frontTab: 1)
    #expect(layout.tabs.count == 3)
    #expect(layout.tabs[1].minX == layout.tabs[0].maxX)
    #expect(layout.tabs[2].minX == layout.tabs[1].maxX)
    #expect(layout.tabs[1].contains(layout.closeBox))
    #expect(!layout.tabs[0].intersects(layout.closeBox))
    #expect(layout.tabs[1].width > layout.tabs[0].width)
    // Every tab has a close box of its own, before its title.
    #expect(layout.closeBoxes.count == 3)
    for (tab, box) in zip(layout.tabs, layout.closeBoxes) { #expect(tab.contains(box)) }
    for (box, title) in zip(layout.closeBoxes, layout.titles) { #expect(title.minX > box.maxX) }
    #expect(layout.closeBox(at: CGPoint(x: layout.closeBoxes[2].midX, y: layout.closeBoxes[2].midY)) == 2)
}

@Test func backTabsGiveWayWhenTheyDontFit() {
    let narrow = CGRect(x: 0, y: 0, width: 300, height: 200)
    let layout = BeOSChromeLayout(bounds: narrow, style: .document, titleWidths: [200, 200, 200], frontTab: 0)
    #expect(layout.tabs.last!.maxX <= narrow.maxX)
    #expect(layout.tabs[0].width > layout.tabs[1].width)
}

@Test func slideMovesTheTabsButKeepsThemOnTheWindow() {
    let slid = BeOSChromeLayout(bounds: window, style: .document, titleWidths: [100], slide: 120)
    #expect(slid.tabs[0].minX == 120)
    let far = BeOSChromeLayout(bounds: window, style: .document, titleWidths: [100], slide: 5_000)
    #expect(far.tabs[0].maxX == window.maxX)
    let back = BeOSChromeLayout(bounds: window, style: .document, titleWidths: [100], slide: -50)
    #expect(back.tabs[0].minX == 0)
}

@Test func collapsedWindowIsJustItsTab() {
    let layout = BeOSChromeLayout(bounds: CGRect(x: 0, y: 0, width: 600, height: M.collapsedHeight),
                                  style: .document, isCollapsed: true, titleWidths: [100])
    #expect(layout.body == .zero)
    #expect(layout.scrollBar == nil)
    #expect(layout.tabs[0].height == M.collapsedHeight)
}

@Test func onlyBeOSHasTheBeOSShape() {
    #expect(ChromeTheme.beos.family == .beos)
    #expect(ChromeTheme.builtIn.filter { $0.family == .beos } == [.beos, .beosDark])
    #expect(ChromeTheme.beos.palette.titleTab != nil)
    #expect(ChromeTheme.beosDark.palette.titleTab != nil)
    #expect(ChromeTheme.beosDark.isDark)
}

@Test func builtInThemesHaveDistinctIdsAndNames() {
    #expect(Set(ChromeTheme.builtIn.map(\.id)).count == ChromeTheme.builtIn.count)
    #expect(Set(ChromeTheme.builtIn.map(\.name)).count == ChromeTheme.builtIn.count)
    #expect(ChromeTheme.builtIn.filter(\.isDark).map(\.id) == ["hiTech", "beosDark", "os2Dark", "workbench13"])
}
