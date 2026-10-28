import Foundation
import Testing
@testable import GershwinChrome

private func entry(_ title: String, group: String = "", detail: String? = nil, id: String? = nil) -> PaletteEntry {
    PaletteEntry(id: id ?? title, title: title, detail: detail, group: group, perform: {})
}

private func titles(_ matches: [PaletteMatch]) -> [String] { matches.map(\.entry.title) }

@Test func anEmptyQueryMatchesEverythingInTheOrderGiven() {
    let all = [entry("New Tab"), entry("Close Tab"), entry("Split Right")]
    #expect(titles(PaletteMatcher.rank("", all)) == ["New Tab", "Close Tab", "Split Right"])
    #expect(titles(PaletteMatcher.rank("   ", all)) == ["New Tab", "Close Tab", "Split Right"])
}

@Test func anEmptyQueryDoesntReorderByTitleLength() {
    // With nothing typed there is no "closer match": the app's order (menus, then tabs) is the one to show.
    let all = [entry("Split Right"), entry("Close Tab"), entry("New")]
    #expect(titles(PaletteMatcher.rank("", all)) == ["Split Right", "Close Tab", "New"])
}

@Test func whatWasChosenLatelyComesFirstForAnEmptyQuery() {
    let all = [entry("New Tab"), entry("Close Tab"), entry("Split Right")]
    var history = PaletteHistory()
    history.record("Split Right")
    history.record("Close Tab")
    #expect(titles(PaletteMatcher.rank("", all, history: history)) == ["Close Tab", "Split Right", "New Tab"])
}

@Test func lettersMustAppearInOrderButNeedNotBeTogether() {
    // "Rights Split" has its r before its s, so it doesn't match.
    let all = [entry("Split Right"), entry("Close Tab"), entry("Rights Split")]
    #expect(titles(PaletteMatcher.rank("sr", all)) == ["Split Right"])
}

@Test func matchingIgnoresCase() {
    let all = [entry("Split Right")]
    #expect(titles(PaletteMatcher.rank("SPLIT", all)) == ["Split Right"])
    #expect(titles(PaletteMatcher.rank("right", [entry("RIGHT")])) == ["RIGHT"])
}

@Test func theStartsOfWordsBeatTheMiddlesOfThem() {
    let all = [entry("Transpose"), entry("New Split")]
    #expect(titles(PaletteMatcher.rank("ns", all)) == ["New Split", "Transpose"])
}

@Test func aPrefixBeatsLettersAtTheStartsOfLaterWords() {
    let all = [entry("Show Panes List"), entry("Split Right")]
    #expect(titles(PaletteMatcher.rank("spl", all)) == ["Split Right", "Show Panes List"])
}

@Test func everyWordOfTheQueryMustMatch() {
    let all = [entry("Split Right"), entry("Split Down")]
    #expect(titles(PaletteMatcher.rank("split right", all)) == ["Split Right"])
    #expect(PaletteMatcher.rank("split xyz", all).isEmpty)
}

@Test func wordsMayComeInAnyOrder() {
    #expect(titles(PaletteMatcher.rank("right split", [entry("Split Right")])) == ["Split Right"])
}

@Test func theGroupAndDetailAreSearchedToo() {
    let all = [entry("BeOS", group: "Theme"), entry("Platinum", group: "Theme"), entry("Beos Notes", group: "Menu")]
    #expect(titles(PaletteMatcher.rank("theme beos", all)) == ["BeOS"])
    let tab = entry("zsh", group: "Tab", detail: "vim notes.md")
    #expect(titles(PaletteMatcher.rank("vim", [tab, entry("Vimeo")])) == ["Vimeo", "zsh"])
}

@Test func aTitleMatchOutranksOneInTheDetail() {
    let inDetail = entry("Server", detail: "deploy")
    let inTitle = entry("Deploy")
    #expect(titles(PaletteMatcher.rank("deploy", [inDetail, inTitle])) == ["Deploy", "Server"])
}

@Test func titleMatchesSaysWhichCharactersMatched() throws {
    let match = try #require(PaletteMatcher.rank("sr", [entry("Split Right")]).first)
    #expect(match.titleMatches == [0, 6])
    let grouped = try #require(PaletteMatcher.rank("tab", [entry("zsh", group: "Tab")]).first)
    #expect(grouped.titleMatches.isEmpty)
}

@Test func aWordPicksTheBestPlaceNotTheFirstOne() throws {
    // "ri" could use the "r" of "Prior", but the start of "Right" is the better fit.
    let match = try #require(PaletteMatcher.rank("ri", [entry("Prior Right")]).first)
    #expect(match.titleMatches == [6, 7])
}

@Test func aShorterTitleWinsATie() {
    let all = [entry("Close Window"), entry("Close")]
    #expect(titles(PaletteMatcher.rank("close", all)) == ["Close", "Close Window"])
}

@Test func equalMatchesKeepTheOrderGiven() {
    let all = [entry("Go A", id: "1"), entry("Go B", id: "2")]
    #expect(PaletteMatcher.rank("go", all).map(\.entry.id) == ["1", "2"])
}

@Test func aRecentChoiceFloatsAboveAnEqualMatch() {
    let all = [entry("Go A", id: "1"), entry("Go B", id: "2")]
    var history = PaletteHistory()
    history.record("2")
    #expect(PaletteMatcher.rank("go", all, history: history).map(\.entry.id) == ["2", "1"])
}

@Test func aBetterMatchBeatsARecentOne() {
    let all = [entry("Split Right"), entry("Show Panes List")]
    var history = PaletteHistory()
    history.record("Show Panes List")
    #expect(titles(PaletteMatcher.rank("spl", all, history: history)) == ["Split Right", "Show Panes List"])
}

@Test func historyMovesARepeatedChoiceToTheFrontAndKeepsFifty() throws {
    var history = PaletteHistory()
    history.record("a")
    history.record("b")
    history.record("a")
    #expect(history.recent == ["a", "b"])
    for i in 0..<60 { history.record("id\(i)") }
    #expect(history.recent.count == PaletteHistory.capacity)
    #expect(history.recent.first == "id59")
}

@Test func historyRoundTripsThroughJSON() throws {
    var history = PaletteHistory()
    history.record("x")
    history.record("y")
    let data = try JSONEncoder().encode(history)
    #expect(try JSONDecoder().decode(PaletteHistory.self, from: data) == history)
}

@Test func aQueryLongerThanTheTitleMatchesNothing() {
    #expect(PaletteMatcher.rank("close tabs now", [entry("Close")]).isEmpty)
    #expect(PaletteMatcher.rank("abcdef", [entry("abc")]).isEmpty)
}
