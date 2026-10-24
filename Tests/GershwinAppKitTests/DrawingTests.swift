import AppKit
import GershwinChrome
import GershwinSwiftUI
import SwiftUI
import Testing
@testable import GershwinAppKit
import GershwinSwiftUI

/// The pixels of a view drawn at one pixel a point into an sRGB bitmap, read back as bytes so nothing converts them.
private struct Pixels {
    let context: CGContext

    /// The pixel at (x, y), counting y down from the top as the views do.
    func callAsFunction(_ x: Int, _ y: Int) -> RGB {
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        // CGContext's memory starts at the top row.
        let i = y * context.bytesPerRow + x * 4
        return RGB(UInt32(bytes[i]) << 16 | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2]))
    }

    func alpha(_ x: Int, _ y: Int) -> UInt8 {
        context.data!.assumingMemoryBound(to: UInt8.self)[y * context.bytesPerRow + x * 4 + 3]
    }
}

/// The view drawn at one pixel a point, as an image.
@MainActor
func renderImage(_ view: NSView) throws -> CGImage {
    try #require(try render(view).context.makeImage())
}

@MainActor
private func render(_ view: NSView) throws -> Pixels {
    let size = view.bounds.size
    let context = try #require(CGContext(
        data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    view.displayIgnoringOpacity(view.bounds, in: NSGraphicsContext(cgContext: context, flipped: false))
    return Pixels(context: context)
}

@MainActor
private func frameView(_ style: ClassicWindowStyle, _ theme: ClassicTheme, size: NSSize = NSSize(width: 300, height: 200))
    -> ClassicFrameView {
    let view = ClassicFrameView(style: style, theme: theme)
    view.frame = NSRect(origin: .zero, size: size)
    view.layoutSubtreeIfNeeded()
    return view
}

@MainActor
@Test(arguments: ClassicTheme.all)
func windowIsOutlinedAndBevelled(theme: ClassicTheme) throws {
    let rep = try render(frameView(.panel, theme))
    let p = theme.palette
    #expect(rep(0, 0) == p.border)
    #expect(rep(299, 199) == p.border)
    #expect(rep(1, 1) == p.light)        // highlight inside the outline, top-left
    #expect(rep(298, 198) == p.dark)     // shade inside the outline, bottom-right
    #expect(rep(150, 100) == p.background)
}

@MainActor
@Test func inactiveWindowHasNoPinstripesOrBoxes() throws {
    // Outside a window, the view is inactive, as a window behind the front one is.
    let layout = WindowChromeLayout(bounds: NSRect(x: 0, y: 0, width: 300, height: 200), style: .document)
    let rep = try render(frameView(.document, .platinum))
    let stripeRow = Int(layout.titleBar.minY + ChromeMetrics.stripeInset)
    #expect(rep(40, stripeRow) == Palette.platinum.background)
    #expect(rep(Int(layout.closeBox.midX), Int(layout.closeBox.minY)) == Palette.platinum.background)
}

@MainActor
@Test func scrollBarDrawsItsThumbWhereTheGeometryPutsIt() throws {
    let bar = ClassicScrollBar(theme: .platinum)
    bar.frame = NSRect(x: 0, y: 0, width: 16, height: 216)
    let position = ScrollPosition(total: 48, offset: 0, visible: 24)
    bar.position = position
    let thumb = try #require(ScrollbarGeometry(bounds: bar.bounds).thumb(for: position))
    let rep = try render(bar)
    #expect(rep(8, Int(thumb.minY) + 3) == Palette.platinum.thumb)
    #expect(rep(8, Int(thumb.maxY) + 10) == Palette.platinum.well)
    // The up arrow's triangle, black in its middle.
    #expect(rep(8, 9) == Palette.platinum.border)
}

@MainActor
@Test func scrollBarWithNothingToScrollIsAnEmptyTrack() throws {
    let bar = ClassicScrollBar(theme: .platinum)
    bar.frame = NSRect(x: 0, y: 0, width: 16, height: 216)
    bar.position = ScrollPosition(total: 24, offset: 0, visible: 24)
    let rep = try render(bar)
    #expect(rep(8, 100) == Palette.platinum.background)
    #expect(rep(8, 9) == Palette.platinum.disabledText)   // the arrows are dimmed
}

@MainActor
@Test(arguments: [1.0, 1.5, 2.0] as [CGFloat])
func mainViewCoversTheScaledContentAreaUnscaled(scale: CGFloat) throws {
    let window = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 420), style: .document,
                                theme: ClassicTheme(.platinum, scale: scale))
    let content = NSView()
    window.frameView.mainView = content
    window.contentView?.layoutSubtreeIfNeeded()
    // The chrome is laid out in Mac OS 9 pixels, the window's size over the scale...
    let pixels = NSRect(x: 0, y: 0, width: 600 / scale, height: 420 / scale)
    #expect(window.frameView.bounds.size == pixels.size)
    let layout = WindowChromeLayout(bounds: pixels, style: .document)
    // ...and the content sits over its main area, in points, and is not itself scaled.
    let expected = NSRect(x: layout.main.minX * scale, y: layout.main.minY * scale,
                          width: layout.main.width * scale, height: layout.main.height * scale)
    #expect(abs(content.frame.minX - expected.minX) < 0.01 && abs(content.frame.width - expected.width) < 0.01)
    #expect(abs(content.frame.minY - expected.minY) < 0.01 && abs(content.frame.height - expected.height) < 0.01)
    #expect(content.bounds.size == content.frame.size)
    #expect(content.superview === window.contentView)
}

@MainActor
@Test func windowSizeForContentAddsTheScaledChrome() {
    let window = ClassicWindow(contentRect: .zero, style: .panel, theme: ClassicTheme(.platinum, scale: 2))
    // A panel's chrome: 6 pixels each side, 21 above, 6 below.
    #expect(window.frameSize(forContentSize: NSSize(width: 100, height: 100)) == NSSize(width: 124, height: 154))
}

@MainActor
@Test func activeWindowHasPinstripesAndOutlinedBoxes() throws {
    let view = frameView(.document, .platinum)
    view.drawsAsActive = true
    let layout = WindowChromeLayout(bounds: view.bounds, style: .document)
    let rep = try render(view)
    let stripeRow = Int(layout.titleBar.minY + ChromeMetrics.stripeInset)
    #expect(rep(40, stripeRow) == Palette.platinum.pinstripe)
    #expect(rep(40, stripeRow + 1) == Palette.platinum.light)
    // Each box's face is outlined in black, one point inside its recess.
    for box in layout.boxes {
        #expect(rep(Int(box.minX) + 1, Int(box.midY)) == Palette.platinum.border)
    }
}

@MainActor
@Test func oneBitScrollTrackIsDithered() throws {
    let bar = ClassicScrollBar(theme: ClassicTheme(.system1))
    bar.frame = NSRect(x: 0, y: 0, width: 16, height: 216)
    bar.position = ScrollPosition(total: 48, offset: 0, visible: 24)
    let rep = try render(bar)
    // Below the thumb, neighbouring pixels alternate black and white.
    #expect(rep(6, 150) != rep(7, 150))
    #expect(rep(6, 150) != rep(6, 151))
    #expect([rep(6, 150), rep(7, 150)].allSatisfy { $0 == RGB(0x000000) || $0 == RGB(0xFFFFFF) })
}

@MainActor
@Test(arguments: [ChromeTheme.platinum, .system7])
func frontTabOpensOntoTheContentAndBackTabsSitBehind(appearance: ChromeTheme) throws {
    let bar = ClassicTabBar(theme: ClassicTheme(appearance))
    bar.frame = NSRect(x: 0, y: 0, width: 400, height: ChromeMetrics.tabBarHeight)
    bar.titles = ["one", "two"]
    bar.selectedIndex = 1
    let tabs = bar.tabRects
    let rep = try render(bar)
    let palette = appearance.palette
    let baseline = Int(bar.bounds.maxY) - 1
    // Inside each tab, near the bottom and clear of the label: the front one is the content's own colour.
    #expect(rep(Int(tabs[1].minX) + 12, baseline - 2) == palette.content)
    #expect(rep(Int(tabs[0].minX) + 12, baseline - 2) == palette.well)
    // The edge the tabs stand on runs under the back tab but not under the front one.
    #expect(rep(Int(tabs[0].midX), baseline) == palette.border)
    #expect(rep(Int(tabs[1].midX), baseline) == palette.content)
}

@MainActor
@Test func beosWindowIsTransparentBesideItsTabAndYellowWhenActive() throws {
    let window = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), style: .document,
                                theme: ClassicTheme(.beos))
    window.title = "Terminal"
    let view = window.frameView
    window.contentView?.layoutSubtreeIfNeeded()
    let tab = try #require(BeOSChromeLayout(bounds: view.bounds, style: .document,
                                            titleWidths: [ClassicTheme(.beos).textWidth("Terminal",
                                                font: ClassicTheme(.beos).font(size: 12))]).tabs.first)
    var rep = try render(view)
    #expect(rep.alpha(Int(tab.maxX) + 20, 5) == 0)                       // beside the tab: nothing
    #expect(rep(Int(tab.maxX) - 30, 3) == Palette.beos.titleTab!.inactiveFace)   // inactive: grey
    view.drawsAsActive = true
    rep = try render(view)
    #expect(rep(Int(tab.maxX) - 30, 3) == Palette.beos.titleTab!.face)   // frontmost: yellow
    #expect(rep.alpha(200, 150) == 255)                                   // the body is opaque
    #expect(!window.isOpaque)
}

// MARK: - Menus and pop-ups

@MainActor
private func sampleMenu() -> NSMenu {
    let menu = NSMenu()
    menu.addItem(withTitle: "New Window", action: nil, keyEquivalent: "n")
    menu.addItem(withTitle: "New Tab", action: nil, keyEquivalent: "t")
    menu.addItem(.separator())
    let checked = menu.addItem(withTitle: "Follow System", action: nil, keyEquivalent: "")
    checked.state = .on
    let disabled = menu.addItem(withTitle: "Disabled", action: nil, keyEquivalent: "")
    disabled.isEnabled = false
    menu.autoenablesItems = false
    return menu
}

@MainActor
@Test(arguments: [(ChromeTheme.platinum, true), (.system7, false), (.beos, false)] as [(ChromeTheme, Bool)])
func menuHighlightsItsRowInTheThemesWay(chrome: ChromeTheme, invertsText: Bool) throws {
    let view = ClassicMenuPreview.view(for: sampleMenu(), theme: ClassicTheme(chrome), highlighted: 0)
    let rep = try render(view)
    let palette = chrome.palette
    // Row 0 starts 3 pixels down and is 18 tall; sample its left edge, clear of the text.
    let expected = MenuStyle(chrome) == .beos ? palette.dark : palette.highlight
    #expect(rep(3, 10) == expected)
    // The row below isn't highlighted.
    #expect(rep(3, 28) == palette.background)
    _ = invertsText
}

@MainActor
@Test func platinumMenusHaveAHardShadowAndBeOSMenusDont() throws {
    // A hard shadow is offset down and right: the view's top-right corner is clear, the right edge below it dark.
    let platinumView = ClassicMenuPreview.view(for: sampleMenu(), theme: .platinum)
    let platinum = try render(platinumView)
    let w = Int(platinumView.bounds.width), h = Int(platinumView.bounds.height)
    #expect(platinum.alpha(w - 1, 0) == 0)
    #expect(platinum.alpha(w - 1, h / 2) > 0)
    // BeOS's is macOS's soft one, outside the view: its corner is its own outline.
    let beosView = ClassicMenuPreview.view(for: sampleMenu(), theme: ClassicTheme(.beos))
    let beos = try render(beosView)
    #expect(beos.alpha(Int(beosView.bounds.width) - 1, 0) == 255)
}

@MainActor
@Test(arguments: [1.0, 1.5, 2.0] as [CGFloat])
func popUpButtonSizeScalesWithTheTheme(scale: CGFloat) {
    let one = ClassicPopUpButton(titles: ["Platinum", "Hi-Tech"], theme: ClassicTheme(.platinum))
    let scaled = ClassicPopUpButton(titles: ["Platinum", "Hi-Tech"], theme: ClassicTheme(.platinum, scale: scale))
    #expect(scaled.intrinsicContentSize.width == one.intrinsicContentSize.width * scale)
    #expect(scaled.intrinsicContentSize.height == 21 * scale)
}

/// Writes each component in each built-in theme to PNGs in GERSHWIN_GALLERY, to look at. Off unless that's set.
@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["GERSHWIN_GALLERY"] != nil))
func writeGallery() throws {
    let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GERSHWIN_GALLERY"]!)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for chrome in ChromeTheme.builtIn {
        let theme = ClassicTheme(chrome, scale: 2)
        let pieces: [(String, NSView)] = [
            ("menu", ClassicMenuPreview.view(for: sampleMenu(), theme: theme, highlighted: 1)),
            ("popup", {
                let button = ClassicPopUpButton(titles: ["Drawing Board", "Platinum"], theme: theme)
                button.frame = NSRect(origin: .zero, size: button.intrinsicContentSize)
                button.layoutSubtreeIfNeeded()
                return button
            }()),
        ]
        let alert = ClassicAlert(icon: chrome.id == "system1" ? .stop : chrome.family == .beos ? .note : .caution,
                                 message: "Close the window “~”?",
                                 informativeText: "vim is still running in it. Closing the window ends it.",
                                 buttons: ["Close", "Cancel"])
        let alertView = alert.view(theme: theme)
        alertView.layoutSubtreeIfNeeded()
        let progress = ClassicProgressBar(value: 0.6, theme: theme)
        progress.frame = NSRect(x: 0, y: 0, width: 240, height: progress.intrinsicContentSize.height)
        progress.layoutSubtreeIfNeeded()
        let pole = ClassicProgressBar(value: nil, theme: theme)
        pole.frame = progress.frame
        pole.layoutSubtreeIfNeeded()
        let balloon = ClassicBalloon.view(text: "Close box: To close this window, click here.", theme: theme)
        let utility = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 160, height: 90), style: .utility,
                                    theme: theme)
        utility.title = "Colours"
        utility.frameView.drawsAsActive = true
        utility.contentView?.layoutSubtreeIfNeeded()
        let controls = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), style: .panel,
                                     theme: theme)
        controls.title = "Controls"
        controls.frameView.drawsAsActive = true
        controls.frameView.mainView = NSHostingView(rootView: GalleryControls().gershwin(theme))
        controls.setContentSize(controls.frameSize(forContentSize: controls.frameView.mainView!.fittingSize))
        controls.contentView?.layoutSubtreeIfNeeded()
        let document = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 140), style: .document,
                                     theme: theme)
        document.frameView.tabTitles = chrome.family == .os2 ? ["~ — fish", "make"] : []
        document.frameView.selectedTab = chrome.family == .os2 ? 0 : nil
        document.title = "make"
        document.frameView.drawsAsActive = true
        document.frameView.placardText = "80 × 24  ·  ~/src"
        document.frameView.placardProgress = .fraction(0.4)
        let drop = ClassicDropHighlight(theme: theme)
        drop.isHidden = false
        drop.frame = NSRect(x: 0, y: 0, width: 300, height: 140)
        document.frameView.mainView = drop
        document.contentView?.layoutSubtreeIfNeeded()
        let focused = ClassicTextField(theme: theme)
        focused.stringValue = "pear"
        focused.drawsFocus = true
        focused.frame = NSRect(x: 0, y: 0, width: 220 * theme.scale, height: focused.intrinsicContentSize.height)
        focused.layoutSubtreeIfNeeded()
        let all = [("field", focused as NSView)] + pieces + [("alert", alertView), ("progress", progress), ("pole", pole), ("balloon", balloon),
                            ("utility", utility.contentView!), ("controls", controls.contentView!),
                            ("document", document.contentView!)]
        for (name, view) in all {
            let rep = NSBitmapImageRep(cgImage: try renderImage(view))
            try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(
                "\(chrome.id)-\(name).png"))
        }
    }
}

// MARK: - Buttons and alerts

@MainActor
@Test(arguments: ChromeTheme.builtIn)
func alertPutsItsDefaultButtonOnTheRight(chrome: ChromeTheme) throws {
    let alert = ClassicAlert(message: "Close?", informativeText: "vim is running.", buttons: ["Close", "Cancel"])
    let view = alert.view(theme: ClassicTheme(chrome))
    let buttons = view.subviews.compactMap { $0 as? ClassicButton }
    #expect(buttons.map(\.title) == ["Close", "Cancel"])
    let close = try #require(buttons.first), cancel = try #require(buttons.last)
    #expect(close.isDefault && !cancel.isDefault)
    #expect(close.frame.minX > cancel.frame.maxX - 8)   // right of Cancel (their rings may overlap)
    #expect(close.frame.maxX <= view.bounds.maxX)
}

@MainActor
@Test func buttonSizeScalesAndKeepsRoomForTheRing() {
    let one = ClassicButton(title: "OK", theme: .platinum)
    let two = ClassicButton(title: "OK", theme: ClassicTheme(.platinum, scale: 2))
    #expect(two.intrinsicContentSize == NSSize(width: one.intrinsicContentSize.width * 2,
                                              height: one.intrinsicContentSize.height * 2))
    #expect(one.intrinsicContentSize.height == 28)   // 20, and the ring's 4 each side
}

// MARK: - Progress and Balloon Help

@MainActor
@Test func progressFillsAsFarAsItsValue() throws {
    let bar = ClassicProgressBar(value: 0.5, theme: .platinum)
    bar.frame = NSRect(x: 0, y: 0, width: 104, height: 12)
    bar.layoutSubtreeIfNeeded()
    let rep = try render(bar)
    // Inside the well (2 pixels in), half of 100 is filled with the highlight.
    #expect(rep(10, 6) == Palette.platinum.highlight)
    #expect(rep(48, 6) == Palette.platinum.highlight)
    #expect(rep(60, 6) == Palette.platinum.well)
}

@MainActor
@Test func balloonHelpNamesThePartUnderTheMouse() throws {
    let window = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), style: .document,
                               theme: .platinum)
    window.contentView?.layoutSubtreeIfNeeded()
    let layout = WindowChromeLayout(bounds: window.frameView.bounds, style: .document)
    let close = try #require(window.frameView.help(at: CGPoint(x: layout.closeBox.midX, y: layout.closeBox.midY)))
    #expect(close.0.hasPrefix("Close box"))
    #expect(close.1 == layout.closeBox)
    let title = try #require(window.frameView.help(at: CGPoint(x: 200, y: 10)))
    #expect(title.0.hasPrefix("Title bar"))
    #expect(window.frameView.help(at: CGPoint(x: layout.main.midX, y: layout.main.midY)) == nil)
}

/// The SwiftUI controls, for the gallery.
private struct GalleryControls: View {
    @State private var open = true
    @State private var volume = 0.6
    @State private var count = 3.0
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup("Details", isExpanded: $open) { Text("Shown when open.") }
            ClassicSlider(value: $volume).frame(width: 160)
            HStack {
                Text("Copies: \(Int(count))")
                ClassicLittleArrows(value: $count, in: 1...10)
            }
            HStack {
                Button("Bevel") {}.buttonStyle(ClassicBevelButtonStyle())
                Button("On") {}.buttonStyle(ClassicBevelButtonStyle(isOn: true))
            }
            ClassicField("Name", text: .constant("Fanfare")).frame(width: 200)
            ClassicTabView(selection: .constant(1), titles: ["Appearance", "Text", "Sound"]) {
                Text("The Text tab's page.")
            }
            .frame(width: 360)
        }
        .padding(12)
    }
}

@MainActor
@Test func placardShowsProgressAtItsRight() throws {
    let view = frameView(.document, .platinum)
    view.drawsAsActive = true
    let placard = try #require(WindowChromeLayout(bounds: view.bounds, style: .document).placard)
    let row = Int(placard.midY)
    #expect(try render(view)(Int(placard.maxX) - 10, row) == Palette.platinum.background)
    view.placardProgress = .fraction(1)
    // A third of the placard, 4 pixels in from its right, filled with the highlight inside the well.
    #expect(try render(view)(Int(placard.maxX) - 10, row) == Palette.platinum.highlight)
}

@MainActor
@Test(arguments: [(ChromeTheme.platinum, Palette.platinum.highlight), (.system7, Palette.system7.border)]
      as [(ChromeTheme, RGB)])
func dropHighlightIsABandInsideTheEdge(chrome: ChromeTheme, color: RGB) throws {
    let highlight = ClassicDropHighlight(theme: ClassicTheme(chrome))
    highlight.frame = NSRect(x: 0, y: 0, width: 100, height: 60)
    let rep = try render(highlight)
    #expect(rep.alpha(0, 30) == 0)
    #expect(rep(1, 30) == color)
    #expect(rep(2, 30) == color)
    #expect(rep.alpha(3, 30) == 0)
    #expect(rep.alpha(50, 30) == 0)
    #expect(highlight.hitTest(NSPoint(x: 50, y: 30)) == nil)
}

@MainActor
@Test func utilityWindowLeavesTheDocumentMain() {
    let utility = ClassicWindow(contentRect: .zero, style: .utility, theme: .platinum)
    let panel = ClassicWindow(contentRect: .zero, style: .panel, theme: .platinum)
    #expect(!utility.canBecomeMain)
    #expect(panel.canBecomeMain)
    #expect(utility.canBecomeKey)
}


@MainActor
@Test(arguments: [(ChromeTheme.platinum, true), (.system7, false), (.beos, true)] as [(ChromeTheme, Bool)])
func fieldShowsTheFocusAsItsEraDid(chrome: ChromeTheme, hasRing: Bool) throws {
    let theme = ClassicTheme(chrome)
    let field = ClassicTextField(theme: theme)
    field.frame = NSRect(x: 0, y: 0, width: 120, height: field.intrinsicContentSize.height)
    field.layoutSubtreeIfNeeded()
    let mid = Int(field.bounds.midY)
    let plain = try render(field)
    #expect(plain(60, mid) == chrome.palette.content)
    field.drawsFocus = true
    let focused = try render(field)
    switch chrome.family {
    case .beos:
        // A blue outline just inside the sunken edge.
        #expect(focused(4, mid) != plain(4, mid))
    default:
        // Platinum's ring, two pixels outside the box (which starts 3 in); System 7 has none.
        #expect((focused.alpha(1, mid) == 255 && focused(1, mid) == chrome.palette.highlight) == hasRing)
        #expect(plain.alpha(1, mid) == 0)
    }
    #expect(focused(60, mid) == chrome.palette.content)
}

@MainActor
@Test func dialogTabsOpenOntoAPanelInTheWindowsColour() throws {
    let bar = ClassicTabBar(theme: .platinum)
    bar.titles = ["Appearance", "Text"]
    bar.selectedIndex = 0
    bar.frame = NSRect(x: 0, y: 0, width: 300, height: ChromeMetrics.tabBarHeight)
    bar.layoutSubtreeIfNeeded()
    let front = try #require(bar.tabRects.first)
    let inside = (Int(front.minX) + 6, Int(front.maxY) - 2)
    #expect(try render(bar)(inside.0, inside.1) == Palette.platinum.content)   // a document's tabs
    bar.opensOntoPanel = true
    #expect(try render(bar)(inside.0, inside.1) == Palette.platinum.background)
}

@MainActor
@Test(arguments: [ClassicTheme(.os2), ClassicTheme(.os2Dark)])
func anOS2WindowHasABlueTitleBarWhenActive(theme: ClassicTheme) throws {
    let view = frameView(.document, theme)
    let layout = OS2ChromeLayout(bounds: view.bounds, style: .document)
    let face = try #require(theme.palette.titleTab)
    #expect(try render(view)(Int(layout.titleBar.midX) - 60, Int(layout.titleBar.midY)) == face.inactiveFace)
    view.drawsAsActive = true
    let rep = try render(view)
    #expect(rep(Int(layout.titleBar.midX) - 60, Int(layout.titleBar.midY)) == face.face)
    #expect(rep(0, 0) == theme.palette.border)
    #expect(rep(2, 100) == theme.palette.background)   // the sizing border
    #expect(rep(Int(layout.closeButton.minX), Int(layout.closeButton.midY)) == theme.palette.border)   // its outline
}
