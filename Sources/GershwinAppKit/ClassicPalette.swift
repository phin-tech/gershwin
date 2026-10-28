import AppKit
import GershwinChrome

// A command palette as a floating utility window, as a Finder or Sherlock search was: a title bar, an edit-text field
// and under it a list in a sunken well. Typing narrows the list (`PaletteMatcher`), ↑ and ↓ move, Return or a click
// chooses, Esc closes. The matched letters of each title are underlined. The window is a utility window of the
// theme's own, so it's drawn in every appearance and scaled with the interface.
//
// The app makes the entries and says what each does; this knows nothing about what they are.

/// A palette window. One of these is kept and shown again, so the text field keeps its place and the window its
/// position; the entries are asked for each time it opens.
@MainActor
public final class ClassicPalette {
    public var theme: ClassicTheme {
        didSet {
            window?.theme = theme
            content?.theme = theme
            // A new scale makes the list bigger or smaller, and the window with it.
            if let window, let content { window.setContentSize(window.frameSize(forContentSize: content.preferredSize)) }
        }
    }

    /// The title bar's text.
    public var title = "Command Palette"
    public var placeholder = "Type a command"
    /// How many rows the list shows before it scrolls.
    public var visibleRows = 9
    /// What was chosen lately. Keep it between runs if you like; `onHistoryChange` says when it changes.
    public var history = PaletteHistory()
    public var onHistoryChange: ((PaletteHistory) -> Void)?
    /// Told on each edit of the text, so an app whose entries depend on it can `update` them.
    public var onQueryChange: ((String) -> Void)?

    public var isVisible: Bool { window?.isVisible ?? false }

    /// How many entries deep the palette is: 0 on the list it opened with.
    public var depth: Int { max(0, levels.count - 1) }

    /// The entries of the list being shown, before any text narrows them.
    public var entries: [PaletteEntry] { levels.last?.entries ?? [] }

    /// Back to the list this one was opened from, as Esc does; nothing on the first list.
    public func goBack() {
        back(orClose: false)
    }

    /// The window, once it's been shown.
    public private(set) var window: ClassicWindow?
    private(set) var content: ClassicPaletteView?
    /// The lists being shown, the first the one the palette opened on; each after it was opened by an entry. What was
    /// typed and chosen in a list is kept while the one over it is shown, for coming back to.
    private struct Level {
        var title: String?
        var entries: [PaletteEntry]
        var query = ""
        var selected = 0
    }
    private var levels: [Level] = []
    private var previousKeyWindow: NSWindow?
    private var closing: NSObjectProtocol?

    public init(theme: ClassicTheme) {
        self.theme = theme
    }

    /// Opens the palette over `entries`, or closes it if it's open. The text starts empty.
    public func toggle(entries: [PaletteEntry]) {
        if isVisible { hide() } else { show(entries: entries) }
    }

    /// Opens the palette over `entries`, with `query` already typed (for a palette that opens narrowed, to tabs say).
    public func show(entries: [PaletteEntry], query: String = "") {
        let view = makeContent()
        levels = [Level(title: nil, entries: entries, query: query)]
        view.reset(entries: entries, query: query)
        let window = makeWindow(content: view)
        window.title = windowTitle
        if !window.isVisible {
            previousKeyWindow = NSApp.keyWindow.flatMap { $0 === window ? nil : $0 }
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        // The frame view puts the content into the window when it lays out; until then the field has no window to take
        // the focus in.
        window.contentView?.layoutSubtreeIfNeeded()
        view.focus()
        DispatchQueue.main.async { [weak view] in view?.focus() }
    }

    /// Replaces the entries of the list being shown while it's open (a script's came in late, or depend on what was
    /// typed), keeping the text. An app that fills the opening list late should check `depth` first: by then the person
    /// may have gone into an entry.
    public func update(entries: [PaletteEntry]) {
        if !levels.isEmpty { levels[levels.count - 1].entries = entries }
        content?.setEntries(entries)
    }

    /// Chooses the entry with this id in the list being shown, as Return on it would: false if there isn't one. For an
    /// app that opens the palette straight into one of its lists.
    @discardableResult
    public func choose(id: String) -> Bool {
        guard let entry = levels.last?.entries.first(where: { $0.id == id }) else { return false }
        choose(entry)
        return true
    }

    /// The title bar's text: `title`, then the entries that were opened to get here ("Command Palette ▸ Herdr").
    private var windowTitle: String {
        ([title] + levels.compactMap(\.title)).joined(separator: " ▸ ")
    }

    public func hide() {
        window?.orderOut(nil)
        windowHidden()
    }

    private func makeContent() -> ClassicPaletteView {
        if let content { return content }
        let view = ClassicPaletteView(theme: theme, visibleRows: visibleRows)
        view.placeholder = placeholder
        // The opening list's app-supplied entries depend on the text; a list an entry opened doesn't.
        view.onQueryChange = { [weak self] in
            guard let self, depth == 0 else { return }
            onQueryChange?($0)
        }
        view.onChoose = { [weak self] entry in self?.choose(entry) }
        view.onCancel = { [weak self] in self?.back(orClose: true) }
        view.onBack = { [weak self] in self?.back(orClose: false) }
        view.history = { [weak self] in self?.history ?? PaletteHistory() }
        content = view
        return view
    }

    private func makeWindow(content view: ClassicPaletteView) -> ClassicWindow {
        view.visibleRows = visibleRows
        view.placeholder = placeholder
        let size = view.preferredSize
        if let window {
            // Setting it again would take it out of the window and put it back, losing the field's focus.
            if window.frameView.mainView !== view { window.frameView.mainView = view }
            window.title = title
            return window
        }
        let window = ClassicWindow(contentRect: NSRect(origin: .zero, size: size), style: .utility, theme: theme)
        window.setContentSize(window.frameSize(forContentSize: size))
        window.frameView.mainView = view
        window.title = title
        window.level = .floating
        window.hidesOnDeactivate = true
        closing = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                                         queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.windowHidden() }
        }
        self.window = window
        return window
    }

    private func windowHidden() {
        let key = previousKeyWindow
        previousKeyWindow = nil
        // What the palette was opened from takes the keyboard back, so an entry's action reaches it.
        if let key, key.isVisible { key.makeKeyAndOrderFront(nil) }
    }

    /// Esc, or ⌫ in an empty field: the list this one was opened from, as it was left; on the first list, Esc closes
    /// the palette and ⌫ does nothing.
    private func back(orClose close: Bool) {
        guard levels.count > 1, let content else {
            if close { hide() }
            return
        }
        levels.removeLast()
        let level = levels[levels.count - 1]
        content.restore(entries: level.entries, query: level.query, selected: level.selected)
        window?.title = windowTitle
    }

    private func choose(_ entry: PaletteEntry) {
        if let children = entry.children, let content {
            levels[levels.count - 1].query = content.query
            levels[levels.count - 1].selected = content.selected
            let entries = children()
            levels.append(Level(title: entry.title, entries: entries))
            content.reset(entries: entries)
            window?.title = windowTitle
            return
        }
        history.record(entry.id)
        onHistoryChange?(history)
        hide()
        // After the window the palette was opened from is key again, so a menu item's action finds it.
        DispatchQueue.main.async { entry.perform() }
    }
}

// MARK: - The content

/// The palette's text field and list, in one view: laid out in points, drawn at the theme's scale.
@MainActor
final class ClassicPaletteView: NSView {
    var theme: ClassicTheme {
        didSet {
            input.theme = theme
            invalidateLayout()
        }
    }
    var visibleRows: Int { didSet { invalidateLayout() } }
    var placeholder: String? {
        get { input.placeholder }
        set { input.placeholder = newValue }
    }

    var onQueryChange: ((String) -> Void)?
    var onChoose: ((PaletteEntry) -> Void)?
    var onCancel: (() -> Void)?
    var onBack: (() -> Void)?
    var history: () -> PaletteHistory = { PaletteHistory() }

    private let input: ClassicTextField
    private var entries: [PaletteEntry] = []
    private(set) var matches: [PaletteMatch] = []
    /// The highlighted row (an index into `matches`) and the first one showing.
    private(set) var selected = 0
    private var first = 0

    /// Sizes, in Mac OS 9 pixels.
    enum Metrics {
        static let width: CGFloat = 420
        static let padding: CGFloat = 8
        static let rowHeight: CGFloat = 18
        static let textInset: CGFloat = 6
        static let groupWidth: CGFloat = 56
        static let shortcutWidth: CGFloat = 58
        static let gap: CGFloat = 8
        static let fontSize: CGFloat = 12
        static let smallFontSize: CGFloat = 10
    }

    init(theme: ClassicTheme, visibleRows: Int) {
        self.theme = theme
        self.visibleRows = visibleRows
        input = ClassicTextField(theme: theme)
        super.init(frame: .zero)
        input.onChange = { [weak self] text in self?.queryChanged(text) }
        input.onSubmit = { [weak self] _ in self?.chooseSelected() }
        input.onCancel = { [weak self] in self?.onCancel?() }
        input.onMove = { [weak self] step in self?.move(by: step) }
        input.onDeleteWhenEmpty = { [weak self] in self?.onBack?() }
        addSubview(input)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }

    // MARK: Entries

    /// A new opening: no text, the entries as given.
    func reset(entries: [PaletteEntry], query: String = "") {
        input.stringValue = query
        self.entries = entries
        selected = 0
        first = 0
        refilter(keepingSelection: false)
    }

    /// The text typed so far.
    var query: String { input.stringValue }

    /// A list shown again, as it was left: its text, narrowed again, and the row that was chosen.
    func restore(entries: [PaletteEntry], query: String, selected: Int) {
        input.stringValue = query
        self.entries = entries
        refilter(keepingSelection: false)
        self.selected = min(max(selected, 0), max(0, matches.count - 1))
        keepSelectionVisible()
        needsDisplay = true
    }

    /// New entries under the text as it is.
    func setEntries(_ entries: [PaletteEntry]) {
        self.entries = entries
        refilter(keepingSelection: true)
    }

    func focus() {
        window?.makeFirstResponder(input.field)
    }

    /// Sets the text as typing would, for tests.
    func search(_ text: String) {
        input.stringValue = text
        queryChanged(text)
    }

    private func queryChanged(_ text: String) {
        onQueryChange?(text)
        refilter(keepingSelection: false)
    }

    private func refilter(keepingSelection: Bool) {
        let previous = keepingSelection && matches.indices.contains(selected) ? matches[selected].entry.id : nil
        matches = PaletteMatcher.rank(input.stringValue, entries, history: history())
        selected = previous.flatMap { id in matches.firstIndex { $0.entry.id == id } } ?? 0
        first = 0
        keepSelectionVisible()
        needsDisplay = true
    }

    // MARK: Moving and choosing

    func move(by step: Int) {
        guard !matches.isEmpty else { return }
        // Wraps round at the ends, as a menu's arrow keys do.
        selected = ((selected + step) % matches.count + matches.count) % matches.count
        keepSelectionVisible()
        needsDisplay = true
    }

    func chooseSelected() {
        guard matches.indices.contains(selected) else { return NSSound.beep() }
        onChoose?(matches[selected].entry)
    }

    private func keepSelectionVisible() {
        if selected < first { first = selected }
        if selected >= first + visibleRows { first = selected - visibleRows + 1 }
        first = max(0, min(first, max(0, matches.count - visibleRows)))
    }

    // MARK: Layout

    var preferredSize: NSSize {
        let s = theme.scale
        return NSSize(width: Metrics.width * s, height: listRect(height: nil).maxY + Metrics.padding * s)
    }

    private func invalidateLayout() {
        needsLayout = true
        needsDisplay = true
    }

    private func fieldRect() -> NSRect {
        let s = theme.scale
        return NSRect(x: Metrics.padding * s - 3 * s, y: Metrics.padding * s - 3 * s,
                      width: bounds.width - (Metrics.padding * 2 - 6) * s, height: input.intrinsicContentSize.height)
    }

    /// The well the rows are in. With no `height` it's as tall as `visibleRows` rows.
    private func listRect(height: CGFloat?) -> NSRect {
        let s = theme.scale
        let top = Metrics.padding * s - 3 * s + input.intrinsicContentSize.height + 4 * s
        let rows = CGFloat(visibleRows) * Metrics.rowHeight * s + 2 * s
        let width = height == nil ? Metrics.width * s : bounds.width
        return NSRect(x: Metrics.padding * s, y: top, width: width - Metrics.padding * 2 * s,
                      height: rows)
    }

    override func layout() {
        super.layout()
        input.frame = fieldRect()
    }

    // MARK: Drawing

    private var style: MenuStyle { MenuStyle(theme.chrome) }

    override func draw(_ dirtyRect: NSRect) {
        let t = theme, s = t.scale
        t.background.setFill()
        bounds.fill()

        let well = listRect(height: bounds.height)
        t.fillWellContent(well, scale: s)
        guard !matches.isEmpty else {
            let message = input.stringValue.isEmpty ? "Nothing to choose" : "No matches"
            t.drawText(message, in: well.insetBy(dx: Metrics.textInset * s, dy: 0).divided(atDistance: Metrics.rowHeight * s, from: .minYEdge).slice,
                       font: ClassicTheme.smallFont(size: Metrics.fontSize * s), color: t.disabledText)
            return
        }

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(rect: well.insetBy(dx: s, dy: s)).addClip()
        let end = min(matches.count, first + visibleRows + 1)
        for index in first..<end {
            drawRow(index, in: rowRect(index, well: well))
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func rowRect(_ index: Int, well: NSRect) -> NSRect {
        let s = theme.scale
        return NSRect(x: well.minX + s, y: well.minY + s + CGFloat(index - first) * Metrics.rowHeight * s,
                      width: well.width - 2 * s, height: Metrics.rowHeight * s)
    }

    private func drawRow(_ index: Int, in rect: NSRect) {
        let t = theme, s = t.scale
        let match = matches[index]
        let isSelected = index == selected
        if isSelected {
            (style == .beos ? t.dark : t.highlight).setFill()
            rect.fill()
        }
        let onContent = NSColor(t.palette.contentText)
        let text = isSelected && style != .beos ? t.selectedText : (style == .beos && isSelected ? t.text : onContent)
        let dim = isSelected ? text : t.disabledText

        let font = ClassicTheme.smallFont(size: Metrics.fontSize * s)
        let small = ClassicTheme.smallFont(size: Metrics.smallFontSize * s)
        let inset = Metrics.textInset * s
        var right = rect.maxX - inset
        // An entry that opens a list says so, as a menu's submenu rows do.
        if match.entry.opensList {
            let r = NSRect(x: right - 10 * s, y: rect.minY, width: 10 * s, height: rect.height)
            t.drawText("▸", in: r, font: font, color: dim, alignment: .right)
            right = r.minX - 4 * s
        }
        // The group, at the right edge, and the shortcut before it.
        if !match.entry.group.isEmpty {
            let r = NSRect(x: right - Metrics.groupWidth * s, y: rect.minY, width: Metrics.groupWidth * s, height: rect.height)
            t.drawText(match.entry.group, in: r, font: small, color: dim, alignment: .right)
            right = r.minX - Metrics.gap * s
        }
        if let shortcut = match.entry.shortcut, !shortcut.isEmpty {
            let r = NSRect(x: right - Metrics.shortcutWidth * s, y: rect.minY, width: Metrics.shortcutWidth * s, height: rect.height)
            t.drawText(shortcut, in: r, font: font, color: dim, alignment: .right)
            right = r.minX - Metrics.gap * s
        }

        // The title, with the matched letters underlined, then the detail after it in what room is left.
        let titleRect = NSRect(x: rect.minX + inset, y: rect.minY, width: max(0, right - rect.minX - inset), height: rect.height)
        let attributed = NSMutableAttributedString(string: match.entry.title, attributes: [
            .font: font, .foregroundColor: text, .paragraphStyle: Self.truncating])
        let characters = Array(match.entry.title)
        for offset in match.titleMatches where offset < characters.count {
            let location = String(characters[..<offset]).utf16.count
            attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue,
                                    range: NSRange(location: location, length: String(characters[offset]).utf16.count))
        }
        let height = ceil(font.ascender - font.descender)
        let line = NSRect(x: titleRect.minX, y: titleRect.midY - height / 2, width: titleRect.width, height: height)
        attributed.draw(with: line, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])

        if let detail = match.entry.detail, !detail.isEmpty {
            let used = min(titleRect.width, ceil(attributed.size().width)) + Metrics.gap * s
            if titleRect.width - used > 24 * s {
                let r = NSRect(x: titleRect.minX + used, y: rect.minY, width: titleRect.width - used, height: rect.height)
                t.drawText(detail, in: r, font: small, color: dim)
            }
        }
    }

    private static let truncating: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }()

    // MARK: Mouse

    private func row(at point: NSPoint) -> Int? {
        let well = listRect(height: bounds.height)
        guard well.insetBy(dx: theme.scale, dy: theme.scale).contains(point) else { return nil }
        let index = first + Int((point.y - well.minY - theme.scale) / (Metrics.rowHeight * theme.scale))
        return matches.indices.contains(index) ? index : nil
    }

    override func mouseMoved(with event: NSEvent) {
        guard let index = row(at: convert(event.locationInWindow, from: nil)), index != selected else { return }
        selected = index
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard let index = row(at: convert(event.locationInWindow, from: nil)) else { return }
        selected = index
        needsDisplay = true
        chooseSelected()
    }

    override func scrollWheel(with event: NSEvent) {
        guard matches.count > visibleRows else { return }
        let rows = Int((event.scrollingDeltaY / (event.hasPreciseScrollingDeltas ? 12 : 1)).rounded())
        guard rows != 0 else { return }
        first = max(0, min(first - rows, matches.count - visibleRows))
        needsDisplay = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private extension ClassicTheme {
    /// The list's well: the content colour, sunken.
    func fillWellContent(_ rect: NSRect, scale s: CGFloat) {
        NSColor(palette.content).setFill()
        rect.fill()
        dark.setFill()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width - s, height: s).fill()
        NSRect(x: rect.minX, y: rect.minY, width: s, height: rect.height - s).fill()
        light.setFill()
        NSRect(x: rect.minX + s, y: rect.maxY - s, width: rect.width - s, height: s).fill()
        NSRect(x: rect.maxX - s, y: rect.minY + s, width: s, height: rect.height - s).fill()
    }
}
