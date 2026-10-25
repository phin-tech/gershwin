import Foundation
import GershwinChrome
import Testing
@testable import GershwinAppKit

private func tempFile() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("gershwin-\(UUID().uuidString)/settings.json")
}

@MainActor
@Test func settingsSurviveARelaunch() {
    let file = tempFile()
    let store = ClassicThemeStore(fileURL: file, systemIsDark: false)
    store.settings.themeChoice.theme = .hiTech
    store.settings.interfaceScale = 2
    let again = ClassicThemeStore(fileURL: file, systemIsDark: false)
    #expect(again.settings.themeChoice.theme == .hiTech)
    #expect(again.theme.scale == 2)
}

@MainActor
@Test func aFollowingChoiceSwitchesWithTheSystem() {
    let store = ClassicThemeStore(fileURL: tempFile(), systemIsDark: true)
    store.settings.themeChoice = ThemeChoice(theme: .platinum, light: .platinum, dark: .hiTech, followsSystem: true)
    #expect(store.theme.chrome == .hiTech)
}

@MainActor
@Test func changesAreReported() {
    let store = ClassicThemeStore(fileURL: tempFile(), systemIsDark: false)
    var calls = 0
    store.onChange = { calls += 1 }
    store.settings.interfaceScale = 1.5
    store.settings.interfaceScale = 1.5   // no change, no call
    #expect(calls == 1)
}

@Test func anUnknownScaleIsTheDefault() throws {
    let decoded = try JSONDecoder().decode(ClassicThemeSettings.self, from: Data(#"{"interfaceScale": 7}"#.utf8))
    #expect(decoded.interfaceScale == 1)
    #expect(decoded.themeChoice == ThemeChoice())
}
