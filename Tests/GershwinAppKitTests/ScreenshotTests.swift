import AppKit
import Foundation
import GershwinChrome
import SwiftUI
import Testing
@testable import GershwinAppKit
@testable import GershwinSwiftUI

private struct Entry: Identifiable { let id: String; var children: [Entry]? }

/// What the README's screenshots show: a window of controls.
private struct Showcase: View {
    @State private var name = "Fanfare"
    @State private var segment = 1
    @State private var selection: String? = "Budget.xls"
    @State private var expanded: Set<String> = ["Documents"]
    @State private var volume = 0.6
    @State private var copies = 3.0
    @State private var color = ClassicColorWell.palette[6]
    private let tree = [
        Entry(id: "Documents", children: [Entry(id: "Letters", children: []), Entry(id: "Budget.xls")]),
        Entry(id: "Pictures", children: []), Entry(id: "ReadMe"),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                ClassicSearchField(text: $name).frame(width: 250)
                ClassicSegmentedControl(selection: $segment, options: [(0, "Icon"), (1, "List"), (2, "Column")])
                ClassicOutline(tree, children: \.children, selection: $selection, expanded: $expanded, title: { $0.id })
                    .frame(width: 250, height: 110)
                ClassicTabView(selection: .constant(0), titles: ["Appearance", "Text"]) {
                    VStack(alignment: .leading, spacing: 8) {
                        ClassicSlider(value: $volume).frame(width: 220)
                        HStack { Text("Copies: \(Int(copies))"); ClassicLittleArrows(value: $copies, in: 1...10) }
                    }
                    .padding(6)
                }
                .frame(width: 250)
            }
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Checked", isOn: .constant(true))
                ClassicLevelIndicator(value: 6)
                ClassicColorWell(selection: $color)
                ClassicProgressView(value: 0.6).frame(width: 150)
                HStack { Button("Cancel") {}; Button("OK") {}.classicDefault() }
            }
        }
        .padding(14)
    }
}

/// Writes a window of controls in each built-in theme to GERSHWIN_SCREENSHOTS, for the README. Off unless that's set.
@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["GERSHWIN_SCREENSHOTS"] != nil))
func writeScreenshots() throws {
    let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GERSHWIN_SCREENSHOTS"]!)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for chrome in ChromeTheme.builtIn {
        let theme = ClassicTheme(chrome, scale: 2)
        let window = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), style: .document,
                                   theme: theme)
        window.title = chrome.name
        window.frameView.drawsAsActive = true
        let host = NSHostingView(rootView: Showcase().gershwin(theme))
        window.frameView.mainView = host
        window.setContentSize(window.frameSize(forContentSize: host.fittingSize))
        window.contentView?.layoutSubtreeIfNeeded()
        let rep = NSBitmapImageRep(cgImage: try renderImage(window.contentView!))
        try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(
            "\(chrome.id).png"))
    }
}
