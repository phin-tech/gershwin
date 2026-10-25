import Foundation
import Testing
@testable import GershwinChrome

@Test(arguments: ChromeTheme.builtIn)
func everyThemeHasSixteenTextColours(theme: ChromeTheme) {
    #expect(theme.textColors.ansi.count == 16)
}

@Test func themesAreFoundAndSavedByTheirIds() throws {
    #expect(ChromeTheme.named("beosDark") == .beosDark)
    #expect(ChromeTheme.named("nextstep") == nil)
    #expect(String(decoding: try JSONEncoder().encode(ChromeTheme.gizmo), as: UTF8.self) == #""gizmo""#)
    #expect(try JSONDecoder().decode(ChromeTheme.self, from: Data(#""system7""#.utf8)) == .system7)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(ChromeTheme.self, from: Data(#""nextstep""#.utf8)) }
}

@Test func eachThemePairsWithOneForTheOtherMode() {
    #expect(ChromeTheme.platinum.darkCounterpart() == .hiTech)
    #expect(ChromeTheme.hiTech.lightCounterpart() == .platinum)
    #expect(ChromeTheme.platinumDark.lightCounterpart() == .platinum)
    #expect(ChromeTheme.beos.darkCounterpart() == .beosDark)
    #expect(ChromeTheme.beosDark.lightCounterpart() == .beos)
    #expect(ChromeTheme.gizmo.darkCounterpart() == .hiTech)   // no partner of its own
    #expect(ChromeTheme.gizmo.lightCounterpart() == .gizmo)
    for theme in ChromeTheme.builtIn {
        #expect(theme.darkCounterpart().isDark && !theme.lightCounterpart().isDark, "\(theme.id)")
    }
}

@Test func anAppsOwnThemeGetsTextColoursFromItsPalette() {
    let mine = ChromeTheme(id: "mine", name: "Mine", isDark: true, palette: .hiTech)
    #expect(mine.textColors.background == Palette.hiTech.content)
    #expect(mine.textColors.ansi.count == 16)
    #expect(mine.lightCounterpart(among: ChromeTheme.builtIn + [mine]) == .platinum)
}

@Test func followingMacOSShowsTheDarkThemeOnlyInDarkMode() {
    let following = ThemeChoice(theme: .gizmo, light: .system7, dark: .beos, followsSystem: true)
    #expect(following.theme(systemIsDark: false) == .system7)
    #expect(following.theme(systemIsDark: true) == .beos)
    #expect(ThemeChoice(theme: .gizmo, light: .system7, dark: .beos).theme(systemIsDark: true) == .gizmo)
}

@Test func aModeNotChosenYetGetsTheThemesPartner() {
    #expect(ThemeChoice(theme: .beos, followsSystem: true).theme(systemIsDark: true) == .beosDark)
    #expect(ThemeChoice(theme: .os2Dark, followsSystem: true).theme(systemIsDark: false) == .os2)
    #expect(ThemeChoice(theme: .platinum, followsSystem: true).theme(systemIsDark: true) == .hiTech)
    // No partner of its own: Hi-Tech, only until a dark one is chosen.
    #expect(ThemeChoice(theme: .gizmo, followsSystem: true).theme(systemIsDark: true) == .hiTech)
    #expect(ThemeChoice(theme: .gizmo, dark: .os2Dark, followsSystem: true).theme(systemIsDark: true) == .os2Dark)
}

@Test func choosingWhileFollowingSetsTheCurrentModesTheme() {
    var choice = ThemeChoice(theme: .platinum, followsSystem: true)
    choice.choose(.beosDark, systemIsDark: true)
    #expect(choice.dark == .beosDark && choice.light == nil && choice.theme == .platinum)
    choice.choose(.system1, systemIsDark: false)
    #expect(choice.light == .system1)
    var fixed = ThemeChoice()
    fixed.choose(.beos, systemIsDark: true)
    #expect(fixed.theme == .beos && fixed.dark == nil)
}

@Test(arguments: [false, true])
func turningFollowingOffAndOnKeepsEveryChoice(systemIsDark: Bool) {
    var choice = ThemeChoice(theme: .drawingBoard, light: .system7, dark: .os2Dark, followsSystem: true)
    let showing = choice.theme(systemIsDark: systemIsDark)
    choice.setFollowsSystem(false, systemIsDark: systemIsDark)
    #expect(choice.theme == showing)   // nothing changes on screen
    choice.setFollowsSystem(true, systemIsDark: systemIsDark)
    #expect(choice.light == .system7 && choice.dark == .os2Dark)
    #expect(choice.theme(systemIsDark: systemIsDark) == showing)
}

@Test func aChoiceIsSavedByThemeIdsAndReadBackLeniently() throws {
    let choice = ThemeChoice(theme: .drawingBoard, dark: .beos, followsSystem: true)
    let text = String(decoding: try JSONEncoder().encode(choice), as: UTF8.self)
    #expect(!text.contains("light"))   // not chosen: left out
    #expect(try JSONDecoder().decode(ThemeChoice.self, from: Data(text.utf8)) == choice)
    let partial = try JSONDecoder().decode(ThemeChoice.self, from: Data(#"{"theme": "nextstep", "followsSystem": true}"#.utf8))
    #expect(partial == ThemeChoice(theme: .platinum, followsSystem: true))
}

@Test func turningFollowingOffAndOnKeepsAModeNotChosenAsItWas() {
    // Gizmo has no dark partner, so dark is Hi-Tech; choose OS/2 Warp Dark for it, light never chosen.
    var choice = ThemeChoice(theme: .gizmo, dark: .os2Dark, followsSystem: true)
    choice.setFollowsSystem(false, systemIsDark: true)
    #expect(choice.theme == .os2Dark)
    choice.setFollowsSystem(true, systemIsDark: true)
    #expect(choice.lightTheme() == .gizmo && choice.darkTheme() == .os2Dark)
}
