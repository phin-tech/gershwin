import Foundation
import Testing
@testable import GershwinChrome

@Test(arguments: ChromeTheme.builtIn)
func everyThemeHasSixteenTextColours(theme: ChromeTheme) {
    #expect(theme.textColors.ansi.count == 16)
}

@Test func themesAreFoundAndSavedByTheirIds() throws {
    #expect(ChromeTheme.named("beosDark") == .beosDark)
    #expect(ChromeTheme.named("aqua") == nil)
    #expect(String(decoding: try JSONEncoder().encode(ChromeTheme.gizmo), as: UTF8.self) == #""gizmo""#)
    #expect(try JSONDecoder().decode(ChromeTheme.self, from: Data(#""system7""#.utf8)) == .system7)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(ChromeTheme.self, from: Data(#""aqua""#.utf8)) }
}

@Test func eachThemePairsWithOneForTheOtherMode() {
    #expect(ChromeTheme.platinum.darkCounterpart() == .hiTech)
    #expect(ChromeTheme.hiTech.lightCounterpart() == .platinum)
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
    let following = ThemeChoice(light: .system7, dark: .beos, followsSystem: true)
    #expect(following.theme(systemIsDark: false) == .system7)
    #expect(following.theme(systemIsDark: true) == .beos)
    #expect(ThemeChoice(light: .system7, dark: .beos).theme(systemIsDark: true) == .system7)
}

@Test func choosingWhileFollowingSetsTheCurrentModesTheme() {
    var choice = ThemeChoice(light: .platinum, dark: .hiTech, followsSystem: true)
    choice.choose(.gizmo, systemIsDark: true)
    #expect(choice.dark == .gizmo && choice.light == .platinum)
    choice.choose(.system1, systemIsDark: false)
    #expect(choice.light == .system1)
    var fixed = ThemeChoice()
    fixed.choose(.beos, systemIsDark: true)
    #expect(fixed.light == .beos)
}

@Test(arguments: [false, true])
func turningFollowingOnPutsTheThemeInUseInItsOwnModesSlot(systemIsDark: Bool) {
    for theme in ChromeTheme.builtIn {
        var choice = ThemeChoice(light: theme)
        choice.setFollowsSystem(true, systemIsDark: systemIsDark)
        #expect(choice.followsSystem)
        if theme.isDark {
            #expect(choice.dark == theme && !choice.light.isDark, "\(theme.id)")
        } else {
            #expect(choice.light == theme && choice.dark.isDark, "\(theme.id)")
        }
    }
}

@Test func followingFromADarkThemePairsItWithItsLightOne() {
    var choice = ThemeChoice(light: .beosDark)
    choice.setFollowsSystem(true, systemIsDark: true)
    #expect(choice.dark == .beosDark && choice.light == .beos)
    #expect(choice.theme(systemIsDark: true) == .beosDark)
}

@Test func turningFollowingOffKeepsTheThemeShowing() {
    var choice = ThemeChoice(light: .beos, dark: .beosDark, followsSystem: true)
    choice.setFollowsSystem(false, systemIsDark: true)
    #expect(choice.light == .beosDark && !choice.followsSystem)
}

@Test func aChoiceIsSavedByThemeIdsAndReadBackLeniently() throws {
    let choice = ThemeChoice(light: .drawingBoard, dark: .beos, followsSystem: true)
    #expect(try JSONDecoder().decode(ThemeChoice.self, from: JSONEncoder().encode(choice)) == choice)
    let partial = try JSONDecoder().decode(ThemeChoice.self, from: Data(#"{"light": "aqua", "followsSystem": true}"#.utf8))
    #expect(partial == ThemeChoice(light: .platinum, dark: .hiTech, followsSystem: true))
}
