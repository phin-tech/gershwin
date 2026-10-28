import CoreGraphics
import Testing
@testable import GershwinChrome

private let window = WindowChromeLayout(bounds: CGRect(x: 0, y: 0, width: 400, height: 300), style: .document,
                                        aqua: true)

@Test func aquasButtonsAreTogetherAtTheLeftCloseMinimizeZoom() throws {
    let zoom = try #require(window.zoomBox)
    #expect(window.closeBox.minX == AquaMetrics.buttonInset(for: .document))
    #expect(window.collapseBox.minX == window.closeBox.maxX + AquaMetrics.buttonGap(for: .document))
    #expect(zoom.minX == window.collapseBox.maxX + AquaMetrics.buttonGap(for: .document))
    #expect(window.boxes == [window.closeBox, window.collapseBox, zoom])
    #expect(window.titleBar.height == 22)
}

@Test func aquasContentReachesTheWindowsEdges() {
    // No frame beside or below it, as Platinum's has.
    #expect(window.content == CGRect(x: 0, y: 22, width: 400, height: 278))
    #expect(window.growBox?.maxX == 400 && window.growBox?.maxY == 300)
}

@Test func aquasTitleIsCentredOnTheWindowClearOfTheButtons() throws {
    let title = window.titleRect(textWidth: 80, textHeight: 14)
    #expect(title.midX == window.titleBar.midX)
    // Too long to centre clear of the buttons: it moves right, and is cut short at the edge.
    let zoom = try #require(window.zoomBox)
    let long = window.titleRect(textWidth: 330, textHeight: 14)
    #expect(long.minX > zoom.maxX && long.maxX < window.titleBar.maxX)
    #expect(long.midX > window.titleBar.midX)
    #expect(window.titleRect(textWidth: 1000, textHeight: 14).width < 400)
}

@Test func aPanelHasNoZoomAndACollapsedAquaWindowIsItsTitleBar() {
    let panel = WindowChromeLayout(bounds: CGRect(x: 0, y: 0, width: 300, height: 200), style: .panel, aqua: true)
    #expect(panel.zoomBox == nil && panel.boxes.count == 2)
    #expect(WindowChromeLayout.collapsedHeight(for: .document, aqua: true) == 22)
    #expect(WindowChromeLayout.collapsedHeight(for: .utility, aqua: true) == 16)
}

@Test func theAquaThemesAreBuiltIn() {
    #expect(ChromeTheme.builtIn.filter { $0.family == .aqua } == [.gel, .gelGraphite])
    #expect(ChromeTheme.named("gelGraphite") == .gelGraphite)
}
