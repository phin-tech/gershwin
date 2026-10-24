import Testing
@testable import GershwinChrome

private let dracula = """
# Dracula, as iTerm2-Color-Schemes publishes it for Ghostty
palette = 0=#21222c
palette = 1=#ff5555
palette = 15=#ffffff
palette = 200=#123456
background = #282a36
foreground = #f8f8f2
cursor-color = #f8f8f2
cursor-text = #282a36
selection-background = #44475a
selection-foreground = #ffffff
"""

@Test func aGhosttyThemeGivesItsColours() throws {
    let colors = try TextColors(ghosttyTheme: dracula, over: .platinum)
    #expect(colors.background == RGB(0x282A36) && colors.foreground == RGB(0xF8F8F2))
    #expect(colors.cursor == RGB(0xF8F8F2))
    #expect(colors.selectionBackground == RGB(0x44475A) && colors.selectionForeground == RGB(0xFFFFFF))
    #expect(colors.ansi[0] == RGB(0x21222C) && colors.ansi[1] == RGB(0xFF5555) && colors.ansi[15] == RGB(0xFFFFFF))
    #expect(colors.ansi.count == 16)
}

@Test func whatAThemeLeavesOutComesFromTheBase() throws {
    let colors = try TextColors(ghosttyTheme: "background = 101010\n", over: .platinum)
    #expect(colors.background == RGB(0x101010))
    #expect(colors.foreground == TextColors.platinum.foreground && colors.ansi == TextColors.platinum.ansi)
}

@Test func aBrokenLineSaysWhereAndWhy() {
    #expect(throws: GhosttyThemeError(line: 2, problem: "“#zzz999” isn't a colour like #282a36")) {
        try TextColors(ghosttyTheme: "# fine\nbackground = #zzz999\n", over: .platinum)
    }
    #expect(throws: GhosttyThemeError(line: 1, problem: "it isn't “key = value”")) {
        try TextColors(ghosttyTheme: "background #000000", over: .platinum)
    }
}

@Test(arguments: [("#282a36", 0x282A36), ("282A36", 0x282A36), ("#fff", 0xFFFFFF)] as [(String, UInt32)])
func hexColoursRead(text: String, value: UInt32) {
    #expect(RGB(hex: text) == RGB(value))
}
