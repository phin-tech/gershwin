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

@Test func aWindows7WindowHangsItsGlassButtonsFromTheTopEdge() throws {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
    let layout = OS2ChromeLayout(bounds: bounds, style: .document, titleBar: .windows7)
    let close = try #require(layout.closeButton), maximize = try #require(layout.maximizeButton)
    let hide = try #require(layout.hideButton)
    #expect(close.minY == 1 && close.width == 47 && close.maxX < bounds.maxX)
    // Joined: minimize, maximize, then close, with no gaps.
    #expect(maximize.maxX == close.minX && hide.maxX == maximize.minX)
    #expect(layout.titleBar.minY == 2 && layout.content.minY == layout.titleBar.maxY)
    // The title sits left of the buttons, after the icon, level with them.
    let title = layout.titleRect(textWidth: 60, textHeight: 12)
    #expect(title.minX == layout.systemMenu.maxX + 6 && title.midY == close.midY)
    // A dialog has no minimize or maximize.
    let panel = OS2ChromeLayout(bounds: bounds, style: .panel, titleBar: .windows7)
    #expect(panel.hideButton == nil && panel.maximizeButton == nil && panel.closeButton != nil)
    // Collapsed, the window is its caption in its frame.
    let collapsed = OS2Metrics.collapsedHeight(for: .document, titleBar: .windows7)
    #expect(collapsed == 35)
    let rolled = OS2ChromeLayout(bounds: CGRect(x: 0, y: 0, width: 400, height: collapsed), style: .document,
                                 isCollapsed: true, titleBar: .windows7)
    #expect(rolled.content.isEmpty)
}

@Test func windows7ComesInLightAndDarkAsPartners() throws {
    #expect(ChromeTheme.windows7.darkCounterpart() == .windows7Dark)
    #expect(ChromeTheme.windows7Dark.lightCounterpart() == .windows7)
    #expect(ChromeTheme.windows7.family == .os2 && ChromeTheme.windows7Dark.isDark)
}
