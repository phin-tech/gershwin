import CoreGraphics
import Testing
@testable import GershwinChrome

private let window = CGRect(x: 0, y: 0, width: 600, height: 400)

@Test func documentWindowBoxesSitInTheTitleBar() {
    let layout = WindowChromeLayout(bounds: window, style: .document)
    // On whole pixels: a 13-pixel box in a 20-pixel bar sits a pixel nearer the top than the bottom.
    #expect(layout.closeBox == CGRect(x: 7, y: 4, width: 13, height: 13))
    #expect(layout.collapseBox == CGRect(x: 580, y: 4, width: 13, height: 13))
    #expect(layout.zoomBox == CGRect(x: 563, y: 4, width: 13, height: 13))
    for box in layout.boxes {
        #expect(layout.titleBar.contains(box))
    }
}

@Test func panelHasNoZoomBoxScrollBarOrGrowBox() {
    let layout = WindowChromeLayout(bounds: window, style: .panel)
    #expect(layout.zoomBox == nil)
    #expect(layout.scrollBar == nil)
    #expect(layout.growBox == nil)
    #expect(layout.main == layout.content)
    #expect(layout.boxes.count == 2)
}

@Test func documentContentIsSplitIntoTerminalScrollBarPlacardAndGrowBox() throws {
    let layout = WindowChromeLayout(bounds: window, style: .document)
    let scrollBar = try #require(layout.scrollBar)
    let growBox = try #require(layout.growBox)
    let placard = try #require(layout.placard)

    #expect(layout.content == CGRect(x: 6, y: 21, width: 588, height: 373))
    #expect(growBox == CGRect(x: 578, y: 378, width: 16, height: 16))
    #expect(scrollBar == CGRect(x: 578, y: 21, width: 16, height: 357))
    #expect(placard == CGRect(x: 6, y: 378, width: 572, height: 16))
    #expect(layout.main == CGRect(x: 6, y: 21, width: 572, height: 357))
    // The four parts tile the content exactly.
    let area = [layout.main, scrollBar, placard, growBox].map { $0.width * $0.height }.reduce(0, +)
    #expect(area == layout.content.width * layout.content.height)
}

@Test func collapsedWindowHasOnlyItsTitleBar() {
    let layout = WindowChromeLayout(bounds: CGRect(x: 0, y: 0, width: 600, height: ChromeMetrics.collapsedHeight),
                                    style: .document, isCollapsed: true)
    #expect(layout.content == .zero)
    #expect(layout.scrollBar == nil)
    #expect(layout.growBox == nil)
    #expect(layout.boxes.count == 3)
}

@Test func titleIsCentredOnTheWindow() {
    let layout = WindowChromeLayout(bounds: window, style: .document)
    let title = layout.titleRect(textWidth: 100, textHeight: 14)
    #expect(title.midX == 300)
    #expect(title.width == 100)
}

@Test func longTitleIsKeptClearOfTheBoxes() {
    let layout = WindowChromeLayout(bounds: window, style: .document)
    let title = layout.titleRect(textWidth: 2000, textHeight: 14)
    #expect(title.minX >= layout.closeBox.maxX + ChromeMetrics.boxClearance + ChromeMetrics.titleClearance)
    #expect(title.maxX <= layout.zoomBox!.minX - ChromeMetrics.boxClearance - ChromeMetrics.titleClearance)
}

@Test func titleInATinyWindowHasNoWidthRatherThanANegativeOne() {
    let layout = WindowChromeLayout(bounds: CGRect(x: 0, y: 0, width: 40, height: 100), style: .document)
    #expect(layout.titleRect(textWidth: 100, textHeight: 14).width == 0)
}

@Test func pinstripesSkipTheBoxesAndTheTitle() {
    let layout = WindowChromeLayout(bounds: window, style: .document)
    let title = layout.titleRect(textWidth: 100, textHeight: 14)
    let areas = layout.stripeAreas(title: title)
    // Before the close box, between it and the title, between the title and the zoom box, and after the collapse
    // box; the zoom and collapse boxes' clearances meet, so nothing between them.
    #expect(areas.count == 4)
    for area in areas {
        for box in layout.boxes { #expect(!area.intersects(box)) }
        #expect(!area.intersects(title))
        #expect(layout.titleBar.contains(area))
    }
}

@Test func windowShadeKeepsTheTitleBarWhereItWas() {
    let frame = CGRect(x: 100, y: 200, width: 600, height: 400)
    let collapsed = WindowShade.collapsedFrame(from: frame)
    #expect(collapsed.maxY == frame.maxY)
    #expect(collapsed.height == ChromeMetrics.collapsedHeight)
    #expect(WindowShade.expandedFrame(from: collapsed, height: 400) == frame)
}

@Test func utilityWindowHasAThinTitleBarSmallBoxesAndNoZoom() {
    let layout = WindowChromeLayout(bounds: CGRect(x: 0, y: 0, width: 200, height: 150), style: .utility)
    #expect(layout.titleBar.height == 12)
    #expect(layout.closeBox.width == 9)
    #expect(layout.zoomBox == nil)
    #expect(layout.scrollBar == nil)
    #expect(layout.boxes.allSatisfy { layout.titleBar.contains($0) })
    #expect(layout.content.minX == 3)   // the outline and a two-pixel frame
    #expect(ClassicWindowStyle.utility.collapsedHeight == 14)
}

@Test func beosUtilityWindowHasASmallerTab() {
    let layout = BeOSChromeLayout(bounds: CGRect(x: 0, y: 0, width: 200, height: 150), style: .utility,
                                  titleWidths: [60])
    #expect(layout.tabs[0].height == 15)
    #expect(layout.closeBox.width == 9)
    #expect(layout.tabs[0].contains(layout.closeBox))
    #expect(layout.zoomBox == nil)
}
