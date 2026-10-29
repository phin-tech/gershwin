import AppKit
import GershwinChrome
import Testing
@testable import GershwinAppKit

@MainActor
private final class Source: ClassicThemeSource {
    var themeChoice: ThemeChoice
    var systemIsDark: Bool
    init(_ choice: ThemeChoice = ThemeChoice(), systemIsDark: Bool = false) {
        themeChoice = choice
        self.systemIsDark = systemIsDark
    }
}

@MainActor
private func items(_ themes: ClassicThemeMenu) -> NSMenu {
    _ = NSApplication.shared
    let menu = NSMenu()
    themes.addItems(to: menu)
    return menu
}

@MainActor
@Test func theMenuChecksTheThemeShowing() {
    let source = Source(ThemeChoice(theme: .hiTech))
    let themes = ClassicThemeMenu(source: source)
    let menu = items(themes)
    for item in menu.items { _ = themes.validateMenuItem(item) }
    #expect(menu.items.filter { $0.state == .on }.map(\.title) == [ChromeTheme.hiTech.name])
    #expect(menu.items.first?.title == "Follow System Light and Dark" && menu.items.first?.state == .off)
}

@MainActor
@Test func choosingWhileFollowingSetsTheModeNowShowing() {
    let source = Source(ThemeChoice(theme: .platinum, followsSystem: true), systemIsDark: true)
    let themes = ClassicThemeMenu(source: source)
    let menu = items(themes)
    let item = menu.items.first { $0.title == ChromeTheme.gizmo.name }!
    NSApp.sendAction(item.action!, to: item.target, from: item)
    #expect(source.themeChoice.dark == .gizmo && source.themeChoice.theme == .platinum)
    for item in menu.items { _ = themes.validateMenuItem(item) }
    #expect(menu.items.filter { $0.state == .on }.map(\.title).contains(ChromeTheme.gizmo.name))
}

@MainActor
@Test func theFollowItemTurnsFollowingOnAndOffKeepingWhatShows() {
    let source = Source(ThemeChoice(theme: .beos), systemIsDark: true)
    let themes = ClassicThemeMenu(source: source)
    let menu = items(themes)
    let follow = menu.items[0]
    NSApp.sendAction(follow.action!, to: follow.target, from: follow)
    #expect(source.themeChoice.followsSystem && source.currentTheme == .beosDark)   // BeOS's partner for dark
    NSApp.sendAction(follow.action!, to: follow.target, from: follow)
    #expect(!source.themeChoice.followsSystem && source.currentTheme == .beosDark)
}

@MainActor
@Test func thePaletteHasAnEntryForEachThemeAndChoosingOneChoosesIt() {
    let source = Source(ThemeChoice(theme: .hiTech))
    let entries = ClassicThemeMenu(source: source).paletteEntries()
    #expect(entries.count == ChromeTheme.builtIn.count)
    #expect(entries.filter { $0.detail == "current" }.map(\.title) == [ChromeTheme.hiTech.name])
    entries.first { $0.id == "theme:\(ChromeTheme.phosphor.id)" }!.perform()
    #expect(source.themeChoice.theme == .phosphor)
}
