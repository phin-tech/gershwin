import AppKit
import GershwinChrome
import SwiftUI
import Testing
@testable import GershwinAppKit
@testable import GershwinSwiftUI

@MainActor
@Test func theSplitViewIsAboveItsPanesSoItsDragOutlineShows() throws {
    let themes = ClassicThemeStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID())/s.json"),
                                   systemIsDark: false)
    var tree = SplitTree(pane: "left")
    tree.split("left", along: .sideBySide, adding: "right")
    let view = ClassicSplitPanesView(layout: tree, themes: themes, defaultsKey: nil,
                                     panes: ["left": AnyView(Text("L")), "right": AnyView(Text("R"))])
    #expect(view.subviews.count == 3)
    #expect(view.subviews.last === view.split)
    // And it passes clicks inside a pane through to the pane: only dividers are its own.
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
    view.layoutSubtreeIfNeeded()
    #expect(view.split.hitTest(NSPoint(x: 50, y: 150)) == nil || view.split.hitTest(NSPoint(x: 50, y: 150)) !== view.split)
}
