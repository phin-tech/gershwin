import AppKit
import Foundation
import GershwinChrome
import SwiftUI
import Testing
@testable import GershwinAppKit
@testable import GershwinSwiftUI

private struct Node: Identifiable { let id: String; var children: [Node]? }

private struct NewWidgets: View {
    @State var text = "hello"
    @State var seg = 1
    @State var sel: String? = "b.txt"
    @State var open: Set<String> = ["Docs"]
    @State var date = Date(timeIntervalSince1970: 1_700_000_000)
    @State var color = ClassicColorWell.palette[6]
    @State var pop = true
    let tree = [Node(id: "Docs", children: [Node(id: "a.txt"), Node(id: "b.txt")]), Node(id: "Pics", children: [])]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ClassicSearchField(text: $text)
            ClassicSecureField("Password", text: $text)
            ClassicComboBox("Font", text: $text, options: ["a"])
            ClassicSegmentedControl(selection: $seg, options: [(0, "Icon"), (1, "List"), (2, "Column")])
            ClassicOutline(tree, children: \.children, selection: $sel, expanded: $open, title: { $0.id })
                .frame(height: 90)
            ClassicLevelIndicator(value: 6)
            ClassicDatePicker(date: $date)
            ClassicForm { ClassicFormRow("Name:") { ClassicField(text: $text) } }
            ClassicColorWell(selection: $color)
        }
        .padding(12).frame(width: 260)
    }
}

@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["GERSHWIN_GALLERY"] != nil))
func writeNewWidgets() throws {
    let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GERSHWIN_GALLERY"]!)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for id in ["platinum", "gel", "beos", "classic"] {
        guard let chrome = ChromeTheme.builtIn.first(where: { $0.id == id }) else { continue }
        let theme = ClassicTheme(chrome, scale: 1.5)
        let host = NSHostingView(rootView: NewWidgets().gershwin(theme))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("new-\(id).png"))
    }
}
