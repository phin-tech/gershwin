import AppKit
import GershwinChrome
import Testing
@testable import GershwinAppKit

@MainActor
private final class Target: NSObject {
    var calls: [String] = []
    @objc func split(_ sender: Any?) { calls.append("split") }
    @objc func close(_ sender: Any?) { calls.append("close") }
}

@MainActor
private func menu(_ target: Target) -> NSMenu {
    // A menu validates its items through the application; without one (no earlier test made it) they all stay disabled.
    _ = NSApplication.shared
    let bar = NSMenu()
    let panes = NSMenu(title: "Panes")
    let split = NSMenuItem(title: "Split Right", action: #selector(Target.split(_:)), keyEquivalent: "d")
    split.keyEquivalentModifierMask = [.command, .shift]
    split.target = target
    panes.addItem(split)
    panes.addItem(.separator())
    let nested = NSMenu(title: "Go to")
    let close = NSMenuItem(title: "Close", action: #selector(Target.close(_:)), keyEquivalent: "")
    close.target = target
    nested.addItem(close)
    let nestedItem = NSMenuItem(title: "Go to", action: nil, keyEquivalent: "")
    nestedItem.submenu = nested
    panes.addItem(nestedItem)
    let hidden = NSMenuItem(title: "Hidden", action: #selector(Target.close(_:)), keyEquivalent: "")
    hidden.target = target
    hidden.isHidden = true
    panes.addItem(hidden)
    panes.addItem(NSMenuItem(title: "Does Nothing", action: nil, keyEquivalent: ""))
    let top = NSMenuItem(title: "Panes", action: nil, keyEquivalent: "")
    top.submenu = panes
    bar.addItem(top)
    return bar
}

@MainActor
@Test func menuItemsBecomeEntriesWithTheirMenusAsDetail() {
    // An item's target is weak: held here, or its items would be disabled.
    let target = Target()
    let entries = PaletteEntry.entries(from: menu(target))
    withExtendedLifetime(target) {}
    #expect(entries.map(\.title) == ["Split Right", "Close"])
    #expect(entries.map(\.detail) == ["Panes", "Panes ▸ Go to"])
    #expect(entries.map(\.group) == ["Menu", "Menu"])
    #expect(entries.map(\.shortcut) == ["⇧⌘D", nil])
}

@MainActor
@Test func choosingAnEntrySendsTheItemsAction() throws {
    let target = Target()
    let entries = PaletteEntry.entries(from: menu(target))
    try #require(entries.count == 2)
    entries[0].perform()
    entries[1].perform()
    #expect(target.calls == ["split", "close"])
}

@MainActor
@Test func aDisabledItemIsLeftOut() {
    let target = Target()
    let bar = menu(target)
    bar.autoenablesItems = false
    bar.items[0].submenu?.autoenablesItems = false
    bar.items[0].submenu?.items[0].isEnabled = false
    #expect(PaletteEntry.entries(from: bar).map(\.title) == ["Close"])
}

@Test func shortcutsAreDrawnInTheOrderMacOSDrew() {
    let item = NSMenuItem(title: "x", action: nil, keyEquivalent: "k")
    item.keyEquivalentModifierMask = [.command, .shift, .option, .control]
    #expect(PaletteEntry.shortcutLabel(for: item) == "⌃⌥⇧⌘K")
}

@MainActor
@Test func includingLeavesOutTheItemsItSaysNoTo() {
    let target = Target()
    let entries = PaletteEntry.entries(from: menu(target)) { $0.action != #selector(Target.close(_:)) }
    withExtendedLifetime(target) {}
    #expect(entries.map(\.title) == ["Split Right"])
}
