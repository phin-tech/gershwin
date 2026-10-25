import AppKit
import GershwinAppKit
import GershwinChrome
import SwiftUI

/// SwiftUI views in a ClassicSplitView: the panes laid out as a SplitTree, with dividers the person drags (as an
/// outline, as in System 7) and, if `defaultsKey` is given, kept where they were put.
///
/// Each pane's view is made once, so it must read what it shows from an observable model, not from values passed in.
/// The split view doesn't own its panes' views, it places them; `ClassicSplitPanesView` holds both.
public struct ClassicSplitPanes<PaneID: Hashable & Sendable & Codable>: NSViewRepresentable {
    let layout: SplitTree<PaneID>
    let panes: [PaneID: AnyView]
    let themes: ClassicThemeStore
    /// Read here, so that a change of theme reaches the split view, which isn't SwiftUI.
    let theme: ClassicTheme
    let defaultsKey: String?

    public init(layout: SplitTree<PaneID>, themes: ClassicThemeStore, defaultsKey: String? = nil,
                panes: [PaneID: AnyView]) {
        self.layout = layout
        self.panes = panes
        self.themes = themes
        theme = themes.theme
        self.defaultsKey = defaultsKey
    }

    public func makeNSView(context: Context) -> ClassicSplitPanesView<PaneID> {
        ClassicSplitPanesView(layout: layout, themes: themes, defaultsKey: defaultsKey, panes: panes)
    }

    public func updateNSView(_ view: ClassicSplitPanesView<PaneID>, context: Context) {
        view.split.theme = theme
    }
}

@MainActor
public final class ClassicSplitPanesView<PaneID: Hashable & Sendable & Codable>: NSView {
    public let split: ClassicSplitView<PaneID>
    private var hosts: [PaneID: NSView] = [:]

    init(layout: SplitTree<PaneID>, themes: ClassicThemeStore, defaultsKey: String?, panes: [PaneID: AnyView]) {
        split = ClassicSplitView(pane: layout.panes[0], theme: themes.theme)
        super.init(frame: .zero)
        split.showsScrollBars = false          // the panes scroll themselves
        split.makePane = nil                   // a fixed layout: the person drags dividers, not splits panes
        for (id, content) in panes {
            let host = NSHostingView(rootView: ClassicThemed(themes) { content })
            host.sizingOptions = []            // the split view sizes it, not its content
            addSubview(host)
            hosts[id] = host
        }
        // Last, so on top of the panes: it draws the outline of a divider being dragged, which the panes would
        // otherwise cover. It passes clicks through to them except on the dividers.
        addSubview(split)
        split.paneView = { [weak self] id in self?.hosts[id] }

        let wanted = Set(layout.panes)
        var tree = layout
        if let defaultsKey, let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(SplitTree<PaneID>.self, from: data), Set(saved.panes) == wanted {
            tree = saved
        }
        split.setTree(tree, focused: tree.panes[0])
        if let defaultsKey {
            split.onChange = { tree in
                if let data = try? JSONEncoder().encode(tree) { UserDefaults.standard.set(data, forKey: defaultsKey) }
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func layout() {
        split.frame = bounds
        super.layout()
    }
}
