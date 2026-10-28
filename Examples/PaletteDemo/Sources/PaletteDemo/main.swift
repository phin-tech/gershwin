import AppKit
import GershwinAppKit
import GershwinChrome

/// The window's content: a note on what to try and what was last chosen.
@MainActor
final class StatusView: NSView {
    private let label = NSTextField(wrappingLabelWithString: "")
    var theme: ClassicTheme { didSet { applyTheme() } }
    var text = "" {
        didSet { label.stringValue = text }
    }

    init(theme: ClassicTheme) {
        self.theme = theme
        super.init(frame: .zero)
        addSubview(label)
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func applyTheme() {
        label.font = ClassicTheme.smallFont(size: 12 * theme.scale)
        label.textColor = NSColor(theme.palette.contentText)
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 16, dy: 16)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(theme.palette.content).setFill()
        bounds.fill()
    }
}

@MainActor
final class Demo: NSObject, NSApplicationDelegate {
    private var theme = ClassicTheme.platinum
    private let palette: ClassicPalette
    private let window: ClassicWindow
    private let status: StatusView
    private var tabs = ["zsh — ~/src/gershwin", "vim notes.md", "htop", "ssh luigi"]
    private var lastChosen = "nothing yet"
    private let arguments: [String: String]

    override init() {
        arguments = Self.parse(CommandLine.arguments)
        if let name = arguments["--theme"], let chrome = ChromeTheme.named(name) ?? ChromeTheme.builtIn.first(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            theme = ClassicTheme(chrome)
        }
        palette = ClassicPalette(theme: theme)
        window = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 320), style: .document, theme: theme)
        status = StatusView(theme: theme)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMenu()
        window.title = "Palette Demo"
        window.frameView.mainView = status
        window.setContentSize(window.frameSize(forContentSize: NSSize(width: 560, height: 320)))
        window.center()
        window.makeKeyAndOrderFront(nil)
        updateStatus()

        if let data = UserDefaults.standard.data(forKey: "paletteHistory"),
           let saved = try? JSONDecoder().decode(PaletteHistory.self, from: data) {
            palette.history = saved
        }
        palette.onHistoryChange = { history in
            UserDefaults.standard.set(try? JSONEncoder().encode(history), forKey: "paletteHistory")
        }
        palette.onQueryChange = { [weak self] query in
            guard let self else { return }
            palette.update(entries: entries(query: query, late: true))
        }
        NSApp.activate(ignoringOtherApps: true)

        if let path = arguments["--snapshot"] {
            snapshot(to: path)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: Entries

    /// What the palette lists: the menus, the tabs, the themes, and some scripts. A script can give its entries late
    /// (`late`), and ones that depend on what's typed (the last, which runs whatever was typed).
    private func entries(query: String, late: Bool) -> [PaletteEntry] {
        var all = PaletteEntry.entries(from: NSApp.mainMenu ?? NSMenu()).filter { $0.title != "Command Palette…" }
        for (index, tab) in tabs.enumerated() {
            all.append(PaletteEntry(id: "tab:\(tab)", title: tab, detail: "tab \(index + 1)", group: "Tab",
                                    shortcut: index < 9 ? "⌘\(index + 1)" : nil) { [weak self] in
                self?.chose("Went to “\(tab)”")
            })
        }
        for chrome in ChromeTheme.builtIn {
            all.append(PaletteEntry(id: "theme:\(chrome.name)", title: chrome.name, group: "Theme") { [weak self] in
                self?.apply(ClassicTheme(chrome))
            })
        }
        for script in ["Deploy staging", "Tail the build log", "Open today's notes"] {
            all.append(PaletteEntry(id: "script:\(script)", title: script, detail: "scripts/\(script.lowercased().replacingOccurrences(of: " ", with: "-")).js",
                                    group: "Script") { [weak self] in
                self?.chose("Ran “\(script)”")
            })
        }
        if late {
            // An entry that opens lists of its own: choose it and Return shows the workspaces, and one of those its agents.
            all.append(PaletteEntry(id: "herdr", title: "Herdr: workspaces", detail: "2 workspaces", group: "Herdr",
                                    opens: { [weak self] in self?.workspaces() ?? [] }))
            all.append(PaletteEntry(id: "herdr:new", title: "Herdr: new worker", group: "Herdr") { [weak self] in
                self?.chose("Started a Herdr worker")
            })
        }
        let typed = query.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty {
            all.append(PaletteEntry(id: "run", title: "Run “\(typed)” in a shell", group: "Shell") { [weak self] in
                self?.chose("Would run: \(typed)")
            })
        }
        return all
    }

    private func workspaces() -> [PaletteEntry] {
        [("api", ["planner", "coder", "reviewer"]), ("web", ["designer", "coder"])].map { name, agents in
            PaletteEntry(id: "herdr:ws:\(name)", title: "\(name) workspace", detail: "\(agents.count) agents",
                         group: "Workspace", opens: {
                agents.map { agent in
                    PaletteEntry(id: "herdr:agent:\(name)/\(agent)", title: agent, detail: "in \(name)", group: "Agent") {
                        [weak self] in self?.chose("Focused \(agent) in the \(name) workspace")
                    }
                }
            })
        }
    }

    private func showPalette(query: String = "") {
        palette.show(entries: entries(query: query, late: false), query: query)
        // The way a script's entries come in: a moment after the palette opens, when its command has finished.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, palette.isVisible else { return }
            palette.update(entries: entries(query: query, late: true))
        }
    }

    // MARK: Actions

    private func chose(_ what: String) {
        lastChosen = what
        updateStatus()
    }

    private func apply(_ new: ClassicTheme) {
        theme = new
        window.theme = new
        palette.theme = new
        status.theme = new
        chose("Switched to \(new.chrome.name)")
    }

    private func updateStatus() {
        status.text = """
            Gershwin's command palette

            ⇧⌘P opens it. Type to narrow it, ↑ and ↓ to move, Return to choose, Esc to close.

            Try: “sr” for Split Right; “theme beos”; “tab 3”; a word with no match runs as a shell command. \
            Herdr's entries turn up a moment after it opens; \
            “Herdr: workspaces” opens a list of its own (Esc or ⌫ goes back).

            Last chosen: \(lastChosen)
            """
    }

    @objc private func command(_ sender: NSMenuItem) { chose("Menu ▸ \(sender.title)") }
    @objc private func togglePalette(_ sender: Any?) {
        if palette.isVisible { palette.hide() } else { showPalette() }
    }

    // MARK: Menus

    private func makeMenu() -> NSMenu {
        let bar = NSMenu()
        func submenu(_ title: String, _ items: [NSMenuItem]) {
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = menu
            bar.addItem(item)
        }
        func item(_ title: String, _ action: Selector, _ key: String = "", _ flags: NSEvent.ModifierFlags = .command)
            -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = flags
            item.target = self
            return item
        }
        submenu("Palette Demo", [item("Quit Palette Demo", #selector(NSApplication.terminate(_:)), "q")])
        bar.items[0].submenu?.items[0].target = NSApp
        submenu("File", [item("New Tab", #selector(command), "t"), item("Close Tab", #selector(command), "w"),
                         item("Rename Tab…", #selector(command))])
        submenu("Edit", [item("Copy", #selector(command), "c"), item("Paste", #selector(command), "v"),
                         item("Find…", #selector(command), "f")])
        submenu("View", [item("Command Palette…", #selector(togglePalette), "p", [.command, .shift]),
                         item("Bigger Text", #selector(command), "+"), item("Smaller Text", #selector(command), "-")])
        submenu("Panes", [item("Split Right", #selector(command), "d"),
                          item("Split Down", #selector(command), "d", [.command, .shift]),
                          item("Next Pane", #selector(command), "]"), item("Previous Pane", #selector(command), "[")])
        return bar
    }

    // MARK: Snapshot

    /// `--snapshot out.png`: opens the palette (narrowed by `--query`), writes its window to the file and quits.
    private func snapshot(to path: String) {
        showPalette(query: arguments["--query"] ?? "")
        // `--open herdr --open herdr:ws:api`: chosen in turn once the late entries are in, to see a list inside a list.
        let opens = CommandLine.arguments.enumerated().filter { $0.element == "--open" }
            .compactMap { CommandLine.arguments.indices.contains($0.offset + 1) ? CommandLine.arguments[$0.offset + 1] : nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            for id in opens { self?.palette.choose(id: id) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, let view = palette.window?.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
            view.cacheDisplay(in: view.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
            do { try png.write(to: URL(fileURLWithPath: path)) } catch { print("\(error)"); exit(1) }
            exit(0)
        }
    }

    private static func parse(_ arguments: [String]) -> [String: String] {
        var found: [String: String] = [:]
        var index = 1
        while index < arguments.count {
            if arguments[index].hasPrefix("--"), index + 1 < arguments.count {
                found[arguments[index]] = arguments[index + 1]
                index += 2
            } else {
                index += 1
            }
        }
        return found
    }
}

let app = NSApplication.shared
let demo = Demo()
app.delegate = demo
app.setActivationPolicy(.regular)
app.run()
