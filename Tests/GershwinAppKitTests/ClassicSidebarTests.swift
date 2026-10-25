import AppKit
import GershwinChrome
import SwiftUI
import Testing
@testable import GershwinAppKit
@testable import GershwinSwiftUI

private let sections = [
    ClassicSidebarSection(title: "Workspaces", items: [
        ClassicSidebarItem(id: "a", title: "mini-weather", marker: .off),
        ClassicSidebarItem(id: "b", title: "guildhall", detail: "working", badge: "2", marker: .busy),
    ]),
]

@Test func aSectionIsNamedByItsTitleOrItsFirstRow() {
    #expect(sections[0].id == "Workspaces")
    #expect(ClassicSidebarSection(items: [ClassicSidebarItem(id: "x", title: "x")]).id == "x")
}

@Test func everyMarkerHasAName() {
    #expect(ClassicSidebarMarker.allCases.map(\.rawValue) == ["off", "on", "busy", "alert"])
}

/// The sidebar drawn at 1×, as a bitmap: (x, y) from the top left.
@MainActor
private func render(_ selection: String?, theme: ClassicTheme) throws -> (Int, Int) -> RGB {
    let view = ClassicSidebar(sections, selection: .constant(selection))
        .environment(\.classicTheme, theme)
        .frame(width: 160, height: 90)
    let host = NSHostingView(rootView: view)
    host.frame = NSRect(x: 0, y: 0, width: 160, height: 90)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: rep)
    // The bitmap is in pixels, twice the points on a Retina screen.
    let factor = rep.pixelsWide / 160
    return { x, y in
        let c = rep.colorAt(x: x * factor, y: y * factor)!.usingColorSpace(.sRGB)!
        return RGB(UInt32(c.redComponent * 255 + 0.5) << 16 | UInt32(c.greenComponent * 255 + 0.5) << 8
                   | UInt32(c.blueComponent * 255 + 0.5))
    }
}

@MainActor
@Test func theSelectedRowIsInTheHighlightColourAndTheRestInTheWell() throws {
    let theme = ClassicTheme(.platinum, scale: 1)
    let none = try render(nil, theme: theme)
    let picked = try render("b", theme: theme)
    // Along the far right of the rows, clear of text and badge.
    // The bitmap is colour-managed, so a colour comes back a little off.
    func near(_ a: RGB, _ b: RGB) -> Bool {
        abs(Int(a.red) - Int(b.red)) < 24 && abs(Int(a.green) - Int(b.green)) < 24 && abs(Int(a.blue) - Int(b.blue)) < 24
    }
    var highlighted = 0, welled = 0
    for y in 0..<90 {
        if near(picked(155, y), theme.palette.highlight) { highlighted += 1 }
        if near(none(155, y), theme.palette.well) { welled += 1 }
    }
    #expect(highlighted > 10 && highlighted < 45)
    #expect(welled == 90)
}
