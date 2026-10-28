import AppKit
import GershwinChrome
import Testing
@testable import GershwinAppKit

private func entry(_ title: String, group: String = "Menu") -> PaletteEntry {
    PaletteEntry(id: title, title: title, group: group, perform: {})
}

@MainActor
private func view(_ entries: [PaletteEntry], theme: ClassicTheme = .platinum) -> ClassicPaletteView {
    let view = ClassicPaletteView(theme: theme, visibleRows: 3)
    view.frame = NSRect(origin: .zero, size: view.preferredSize)
    view.reset(entries: entries)
    view.layoutSubtreeIfNeeded()
    return view
}

/// The colour at (x, y) of the view drawn at one pixel a point, y counted down from the top.
@MainActor
private func pixel(_ view: NSView, _ x: Int, _ y: Int) throws -> RGB {
    let size = view.bounds.size
    let context = try #require(CGContext(
        data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    view.displayIgnoringOpacity(view.bounds, in: NSGraphicsContext(cgContext: context, flipped: false))
    let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
    let i = y * context.bytesPerRow + x * 4
    return RGB(UInt32(bytes[i]) << 16 | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2]))
}

@MainActor
@Test func theFirstRowStartsSelectedInTheHighlightAndTheNextIsOnTheContent() throws {
    let v = view([entry("New Tab"), entry("Close Tab")])
    let p = ClassicTheme.platinum.palette
    // The well starts 33 down and 8 in at one pixel a point; its rows are 18 high, inside a one-pixel edge.
    #expect(try pixel(v, 10, 40) == p.highlight)
    #expect(try pixel(v, 10, 58) == p.content)
}

@MainActor
@Test func movingTheSelectionMovesTheHighlight() throws {
    let v = view([entry("New Tab"), entry("Close Tab")])
    let p = ClassicTheme.platinum.palette
    v.move(by: 1)
    #expect(try pixel(v, 10, 40) == p.content)
    #expect(try pixel(v, 10, 58) == p.highlight)
}

@MainActor
@Test func theArrowsWrapRoundAtTheEnds() {
    let v = view([entry("a"), entry("b"), entry("c")])
    v.move(by: -1)
    #expect(v.selected == 2)
    v.move(by: 1)
    #expect(v.selected == 0)
}

@MainActor
@Test func typingNarrowsTheListAndSelectsItsFirstRow() {
    let v = view([entry("New Tab"), entry("Close Tab"), entry("Split Right")])
    v.move(by: 1)
    v.search("sr")
    #expect(v.matches.map(\.entry.title) == ["Split Right"])
    #expect(v.selected == 0)
    v.search("")
    #expect(v.matches.count == 3)
}

@MainActor
@Test func returnChoosesTheSelectedEntryAndNothingMatchedChoosesNothing() {
    let v = view([entry("New Tab"), entry("Close Tab")])
    var chosen: [String] = []
    v.onChoose = { chosen.append($0.title) }
    v.move(by: 1)
    v.chooseSelected()
    #expect(chosen == ["Close Tab"])
    v.search("zzz")
    #expect(v.matches.isEmpty)
    v.chooseSelected()
    #expect(chosen == ["Close Tab"])
}

@MainActor
@Test func theListScrollsToKeepTheSelectionInView() {
    let v = view((0..<10).map { entry("Row \($0)") })
    for _ in 0..<5 { v.move(by: 1) }
    #expect(v.selected == 5)
    v.move(by: -5)
    #expect(v.selected == 0)
}

@MainActor
@Test func newEntriesKeepTheSelectionOnTheSameEntryWhenItIsStillThere() {
    let v = view([entry("a"), entry("b"), entry("c")])
    v.move(by: 1)
    v.setEntries([entry("x"), entry("a"), entry("b"), entry("c")])
    #expect(v.matches[v.selected].entry.title == "b")
}

@MainActor
@Test(arguments: ClassicTheme.all)
func everyThemeDrawsTheList(theme: ClassicTheme) throws {
    let v = view([entry("New Tab"), entry("Close Tab")], theme: theme)
    // Not blank: the well isn't the window's background, and the window's background is drawn around it.
    #expect(try pixel(v, 2, 2) == theme.palette.background)
    #expect(try pixel(v, 10, 58) == theme.palette.content)
}

@MainActor
@Test func theTextFieldHasTheFocusAsSoonAsThePaletteOpens() {
    let palette = ClassicPalette(theme: .platinum)
    palette.show(entries: [entry("New Tab")])
    // The field's editor is the window's first responder, so typing goes into it.
    let editor = palette.window?.firstResponder as? NSTextView
    #expect(editor?.delegate is NSTextField)
    // And again after it's closed and opened a second time.
    palette.hide()
    palette.show(entries: [entry("New Tab")], query: "ne")
    #expect((palette.window?.firstResponder as? NSTextView)?.delegate is NSTextField)
    palette.hide()
}

// MARK: Lists inside lists

@MainActor
private func folder(_ title: String, _ children: @escaping @MainActor @Sendable () -> [PaletteEntry]) -> PaletteEntry {
    PaletteEntry(id: title, title: title, group: "List", opens: children)
}

@MainActor
private func titles(_ palette: ClassicPalette) -> [String] {
    palette.content?.matches.map(\.entry.title) ?? []
}

@MainActor
@Test func choosingAnEntryThatOpensAListShowsItsChildrenInsteadOfClosing() {
    let palette = ClassicPalette(theme: .platinum)
    palette.show(entries: [entry("New Tab"), folder("Herdr") { [entry("api"), entry("web")] }])
    palette.content?.search("herdr")
    palette.content?.chooseSelected()
    #expect(palette.isVisible)
    #expect(palette.depth == 1)
    #expect(titles(palette) == ["api", "web"])
    #expect(palette.content?.query == "")
    #expect(palette.window?.title == "Command Palette ▸ Herdr")
    palette.hide()
}

@MainActor
@Test func theChildrenAreMadeWhenTheEntryIsChosenNotBefore() {
    final class Counter: @unchecked Sendable { var made = 0 }
    let counter = Counter()
    let palette = ClassicPalette(theme: .platinum)
    palette.show(entries: [folder("Herdr") { counter.made += 1; return [entry("api")] }])
    #expect(counter.made == 0)
    palette.content?.chooseSelected()
    #expect(counter.made == 1)
    palette.hide()
}

@MainActor
@Test func backReturnsToTheListAsItWasLeft() {
    let palette = ClassicPalette(theme: .platinum)
    palette.show(entries: [entry("New Tab"), entry("Close Tab"), folder("Herdr") { [entry("api")] }, entry("Split")])
    palette.content?.search("t")
    palette.content?.move(by: 1)
    let before = palette.content?.matches.map(\.entry.title)
    let row = palette.content?.selected
    palette.content?.search("herdr")
    palette.content?.chooseSelected()
    #expect(palette.depth == 1)
    // ⌫ in an empty field goes back, with the text and the row as they were left (not as typed to get here).
    palette.content?.onBack?()
    #expect(palette.depth == 0)
    #expect(palette.content?.query == "herdr")
    #expect(palette.window?.title == "Command Palette")
    palette.content?.search("t")
    #expect(palette.content?.matches.map(\.entry.title) == before)
    #expect(row != nil)
    palette.hide()
}

@MainActor
@Test func escGoesBackOneListAndOnlyClosesFromTheFirst() {
    let palette = ClassicPalette(theme: .platinum)
    palette.show(entries: [folder("A") { [folder("B") { [entry("leaf")] }] }])
    palette.content?.chooseSelected()
    palette.content?.chooseSelected()
    #expect(palette.depth == 2)
    #expect(palette.window?.title == "Command Palette ▸ A ▸ B")
    palette.content?.onCancel?()
    #expect(palette.depth == 1 && palette.isVisible)
    palette.content?.onCancel?()
    #expect(palette.depth == 0 && palette.isVisible)
    palette.content?.onCancel?()
    #expect(!palette.isVisible)
}

@MainActor
@Test func backspaceOnTheFirstListDoesNothing() {
    let palette = ClassicPalette(theme: .platinum)
    palette.show(entries: [entry("New Tab")])
    palette.content?.onBack?()
    #expect(palette.isVisible && palette.depth == 0)
    palette.hide()
}

@MainActor
@Test func onlyTheEntryActuallyChosenIsRemembered() async throws {
    final class Ran: @unchecked Sendable { var titles: [String] = [] }
    let ran = Ran()
    let palette = ClassicPalette(theme: .platinum)
    let leaf = PaletteEntry(id: "leaf", title: "api", group: "Herdr") { ran.titles.append("api") }
    palette.show(entries: [folder("Herdr") { [leaf] }])
    palette.content?.chooseSelected()
    #expect(palette.history.recent.isEmpty)
    palette.content?.chooseSelected()
    #expect(palette.history.recent == ["leaf"])
    #expect(!palette.isVisible)
    try await Task.sleep(for: .milliseconds(100))
    #expect(ran.titles == ["api"])
}

@MainActor
@Test func theOpeningListsQueryHookIsQuietInsideAnEntry() {
    var heard: [String] = []
    let palette = ClassicPalette(theme: .platinum)
    palette.onQueryChange = { heard.append($0) }
    palette.show(entries: [folder("Herdr") { [entry("api")] }])
    palette.content?.search("he")
    palette.content?.chooseSelected()
    palette.content?.search("ap")
    #expect(heard == ["he"])
    palette.hide()
}

@MainActor
@Test func updateReplacesTheListBeingShown() {
    let palette = ClassicPalette(theme: .platinum)
    palette.show(entries: [folder("Herdr") { [] }])
    palette.content?.chooseSelected()
    #expect(titles(palette).isEmpty)
    palette.update(entries: [entry("late one")])
    #expect(titles(palette) == ["late one"])
    // Back to the opening list: it's as it was, not what the nested update put in.
    palette.content?.onBack?()
    #expect(titles(palette) == ["Herdr"])
    palette.hide()
}

@MainActor
@Test func anEntryThatOpensAListDrawsAMarker() throws {
    // The second row isn't selected, so it's on the well's own colour; the marker is at the right edge of the row,
    // past the group's column, where a row that opens nothing has only that colour.
    let marked = view([entry("a"), PaletteEntry(id: "f", title: "Herdr", opens: { [] })])
    let plain = view([entry("a"), entry("Herdr", group: "")])
    let content = ClassicTheme.platinum.palette.content
    func inked(_ v: ClassicPaletteView) throws -> Bool {
        for y in 56...62 { for x in 396...404 where try pixel(v, x, y) != content { return true } }
        return false
    }
    #expect(try inked(plain) == false)
    #expect(try inked(marked))
}

@MainActor
@Test func anAppCanChooseAnEntryByIDToOpenIntoItsList() {
    let palette = ClassicPalette(theme: .platinum)
    palette.show(entries: [entry("New Tab"), PaletteEntry(id: "herdr", title: "Herdr", opens: { [entry("api")] })])
    #expect(palette.choose(id: "nothing") == false)
    #expect(palette.choose(id: "herdr"))
    #expect(palette.depth == 1 && titles(palette) == ["api"])
    palette.hide()
}
