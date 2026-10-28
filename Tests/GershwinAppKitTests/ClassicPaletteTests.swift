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
