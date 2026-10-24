import CoreGraphics
import Testing
@testable import GershwinChrome

private let window = CGRect(x: 0, y: 0, width: 400, height: 300)

@Test func anOS2WindowHasItsSystemMenuLeftAndItsButtonsRight() {
    let layout = OS2ChromeLayout(bounds: window, style: .document)
    #expect(layout.titleBar == CGRect(x: 4, y: 4, width: 392, height: 20))
    #expect(layout.systemMenu == CGRect(x: 5, y: 5, width: 18, height: 18))
    #expect(layout.closeButton == CGRect(x: 377, y: 5, width: 18, height: 18))
    // Hide and maximize side by side, a gap before close.
    #expect(layout.maximizeButton == CGRect(x: 357, y: 5, width: 18, height: 18))
    #expect(layout.hideButton == CGRect(x: 339, y: 5, width: 18, height: 18))
    #expect(layout.buttons.count == 3)
}

@Test func theScrollBarRunsTheContentsHeightWithNoGrowBox() throws {
    let layout = OS2ChromeLayout(bounds: window, style: .document)
    #expect(layout.content == CGRect(x: 4, y: 24, width: 392, height: 272))
    let bar = try #require(layout.scrollBar)
    #expect(bar.maxX == layout.content.maxX && bar.height == layout.content.height)
    #expect(layout.main.maxX == bar.minX && layout.main.height == layout.content.height)
}

@Test func aDialogHasOnlyItsSystemMenuAndCloseButton() {
    let layout = OS2ChromeLayout(bounds: window, style: .panel)
    #expect(layout.hideButton == nil && layout.maximizeButton == nil && layout.scrollBar == nil)
    #expect(layout.main == layout.content)
    #expect(layout.titleBar.minX == 3)
}

@Test func tabsGoAboveTheTerminal() throws {
    let layout = OS2ChromeLayout(bounds: window, style: .document, showsTabBar: true)
    let bar = try #require(layout.tabBar)
    #expect(bar.minY == layout.content.minY && layout.main.minY == bar.maxY)
}

@Test func theTitleIsCentredButClearOfTheButtons() {
    let layout = OS2ChromeLayout(bounds: window, style: .document)
    let short = layout.titleRect(textWidth: 60, textHeight: 12)
    #expect(short.midX == layout.titleBar.midX)
    let long = layout.titleRect(textWidth: 1000, textHeight: 12)
    #expect(long.minX >= layout.systemMenu.maxX && long.maxX <= layout.hideButton!.minX)
}

@Test func collapsedItIsItsTitleBarInItsBorder() {
    #expect(OS2Metrics.collapsedHeight(for: .document) == 28)
    #expect(OS2ChromeLayout(bounds: window, style: .document, isCollapsed: true).content == .zero)
}
