import AppKit
import GershwinChrome

/// A window's content in adjustable panes, each the app's own view: put this view over them, in the same superview,
/// and it lays them out, draws the dividers between them in the theme's style, gives each its own scroll bar, and
/// splits, closes, resizes and moves between them. It never takes the panes' views into itself: it only sets their
/// frames, so a view that must not be moved to another parent (a terminal's, whose shell would end) stays where the app
/// put it. Clicks pass through to the panes except on the dividers, the split boxes and the scroll bars.
///
/// Few of these systems split a window, so each theme borrows what its era had: Mac OS 8 and 9 the split windows of
/// BBEdit and CodeWarrior, a bevelled bar and a split box above each scroll bar that you drag down to split; System 7
/// MPW's double line; BeOS Haiku's split view; OS/2 the split bar of a folder's details view. The pane being typed in
/// has its scroll bar drawn active, the others as in a window behind.
///
/// The app makes a pane's view when asked (`makePane`), lets it go when told (`onClose`), and feeds in each pane's
/// scroll position; menu commands call `split(_:)`, `closeFocusedPane()` and `focusNeighbor(_:)`, and a pane whose
/// content ends goes with `closePane(_:)`. Clicking into a pane focuses it. With a window's frame, set its
/// `panesHaveScrollBars` and this view's `corner` from its `paneCorner`.
@MainActor
public final class ClassicSplitView<PaneID: Hashable & Sendable & Codable>: NSView {
    public var theme: ClassicTheme {
        didSet {
            scrollBars.values.forEach { $0.theme = theme }
            needsLayout = true
            needsDisplay = true
        }
    }

    public private(set) var tree: SplitTree<PaneID>
    public private(set) var focused: PaneID

    /// The app's view for a pane, wherever it lives (beside this view, beneath it).
    public var paneView: (PaneID) -> NSView? = { _ in nil }
    /// A new pane for a split: the app makes its view, puts it in this view's superview, and gives its id; nil to
    /// refuse.
    public var makePane: (() -> PaneID?)?
    /// A pane closed (`closeFocusedPane`): the app lets its view go.
    public var onClose: ((PaneID) -> Void)?
    /// Another pane is the one being typed in.
    public var onFocus: ((PaneID) -> Void)?
    /// A pane's scroll bar asks to scroll.
    public var onScroll: ((PaneID, ScrollRequest) -> Void)?
    /// The tree changed (a split, a close, a divider dragged): to keep it, say.
    public var onChange: ((SplitTree<PaneID>) -> Void)?

    /// Each pane gets a scroll bar along its right side (and in the Mac's themes, a split box above it).
    public var showsScrollBars = true { didSet { needsLayout = true } }
    /// The bottom-right corner the scroll bars stop short of, in Mac OS 9 pixels (ClassicFrameView's `paneCorner`).
    public var corner: CGSize = .zero { didSet { needsLayout = true } }
    /// No pane is made smaller than this across, in Mac OS 9 pixels.
    public var minimumPaneSize: CGFloat = 48

    private var scrollBars: [PaneID: ClassicScrollBar] = [:]
    private var positions: [PaneID: ScrollPosition] = [:]
    private var geometry = SplitGeometry<PaneID>(frames: [:], dividers: [])
    private var splitBoxes: [PaneID: CGRect] = [:]
    /// Where a divider being dragged will go, outlined until the mouse is let go (pixels).
    private var dragLine: CGRect?
    private var observers: [NSObjectProtocol] = []
    private var responderObservation: NSKeyValueObservation?

    public init(pane: PaneID, theme: ClassicTheme) {
        tree = SplitTree(pane: pane)
        focused = pane
        self.theme = theme
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var isFlipped: Bool { true }
    public override var isOpaque: Bool { false }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var style: DividerStyle { DividerStyle(theme.chrome) }
    private var scale: CGFloat { theme.scale }

    // MARK: Commands

    /// Puts another tree in (another tab's): its panes' views must be the app's already.
    public func setTree(_ tree: SplitTree<PaneID>, focused: PaneID) {
        self.tree = tree
        self.focused = tree.contains(focused) ? focused : tree.panes[0]
        for (id, bar) in scrollBars where !tree.contains(id) {
            bar.removeFromSuperview()
            scrollBars[id] = nil
        }
        needsLayout = true
        needsDisplay = true
    }

    /// Splits the pane being typed in, the new one to its right or below it, and types in that. `fraction` is how much
    /// of the pane the first side (left or top) keeps, 0.05 to 0.95.
    public func split(_ axis: SplitAxis, fraction: Double = 0.5) {
        guard let new = makePane?() else { return NSSound.beep() }
        tree.split(focused, along: axis, adding: new, fraction: fraction)
        changed()
        focus(new)
    }

    /// Closes the pane being typed in, its neighbour taking its space and the typing. False with only one pane.
    @discardableResult
    public func closeFocusedPane() -> Bool {
        closePane(focused)
    }

    /// Closes `pane` (its program ended, say), its neighbour taking its space, and the typing if it had it. False with
    /// only one pane, or one not in the tree.
    @discardableResult
    public func closePane(_ closing: PaneID) -> Bool {
        // The typing goes to the pane that takes its space, as in iTerm2 and Ghostty.
        guard let next = tree.heir(of: closing), tree.close(closing) else { return false }
        scrollBars.removeValue(forKey: closing)?.removeFromSuperview()
        positions[closing] = nil
        onClose?(closing)
        changed()
        if closing == focused { focus(next) }
        return true
    }

    /// Types in the pane next to this one in `direction`; false if there's none.
    @discardableResult
    public func focusNeighbor(_ direction: SplitDirection) -> Bool {
        guard let next = tree.neighbor(of: focused, direction, in: pixelBounds, divider: style.thickness) else {
            return false
        }
        focus(next)
        return true
    }

    /// Makes `pane` the one being typed in, its view the window's first responder.
    public func focus(_ pane: PaneID) {
        guard tree.contains(pane) else { return }
        if pane != focused {
            focused = pane
            updateScrollBars()
            onFocus?(pane)
        }
        if let view = paneView(pane), let window, !isWithin(window.firstResponder, view) {
            window.makeFirstResponder(view)
        }
    }

    /// Where a pane's content is scrolled to, for its scroll bar; nil for nothing to scroll.
    public func setScrollPosition(_ position: ScrollPosition?, for pane: PaneID) {
        positions[pane] = position
        scrollBars[pane]?.position = position
    }

    private func changed() {
        needsLayout = true
        needsDisplay = true
        onChange?(tree)
    }

    // MARK: Layout

    private var pixelBounds: CGRect {
        CGRect(x: 0, y: 0, width: bounds.width / scale, height: bounds.height / scale)
    }

    private func points(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
    }

    private func pixels(_ point: NSPoint) -> CGPoint { CGPoint(x: point.x / scale, y: point.y / scale) }

    public override func layout() {
        super.layout()
        let area = pixelBounds
        geometry = tree.layout(in: area, divider: style.thickness)
        splitBoxes = [:]
        for id in tree.panes {
            guard let frame = geometry.frames[id] else { continue }
            var content = frame
            if showsScrollBars {
                var bar = CGRect(x: frame.maxX - SplitMetrics.scrollBarWidth, y: frame.minY, width: SplitMetrics.scrollBarWidth,
                                 height: frame.height)
                content.size.width = max(0, bar.minX - frame.minX)
                if theme.chrome.family == .macintosh {
                    splitBoxes[id] = CGRect(x: bar.minX, y: bar.minY, width: bar.width, height: SplitMetrics.splitBoxHeight)
                    bar.origin.y += SplitMetrics.splitBoxHeight
                    bar.size.height -= SplitMetrics.splitBoxHeight
                }
                if corner != .zero, frame.maxX >= area.maxX - 0.5, frame.maxY >= area.maxY - 0.5 {
                    bar.size.height = max(0, bar.height - corner.height)
                }
                let scrollBar = self.scrollBar(for: id)
                scrollBar.frame = points(bar)
                scrollBar.isHidden = false
            } else {
                scrollBars[id]?.isHidden = true
            }
            if let view = paneView(id) {
                let target = points(content)
                view.frame = view.superview.map { convert(target, to: $0) } ?? target
            }
        }
        updateScrollBars()
        window?.invalidateCursorRects(for: self)
    }

    private func scrollBar(for pane: PaneID) -> ClassicScrollBar {
        if let bar = scrollBars[pane] { return bar }
        let bar = ClassicScrollBar(theme: theme)
        bar.position = positions[pane]
        bar.onScroll = { [weak self] request in
            guard let self else { return }
            self.focus(pane)
            self.onScroll?(pane, request)
        }
        addSubview(bar)
        scrollBars[pane] = bar
        return bar
    }

    /// The window is frontmost (or its frame is drawn as if it were, for snapshots).
    private var windowIsActive: Bool {
        if let frame = (window as? ClassicWindow)?.frameView, frame.drawsAsActive { return true }
        return window.map { $0.isKeyWindow || $0.isMainWindow } ?? false
    }

    private func updateScrollBars() {
        for (id, bar) in scrollBars { bar.isActive = windowIsActive && id == focused }
        needsDisplay = true
    }

    // MARK: Following the window

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        responderObservation = nil
        guard let window else { return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                     NSWindow.didBecomeMainNotification, NSWindow.didResignMainNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) {
                [weak self] _ in MainActor.assumeIsolated { self?.updateScrollBars() }
            })
        }
        // Clicking into a pane (or anything giving it the keyboard) makes it the focused one.
        responderObservation = window.observe(\.firstResponder, options: [.new]) { [weak self] window, _ in
            MainActor.assumeIsolated {
                guard let self, let responder = window.firstResponder else { return }
                if let pane = self.tree.panes.first(where: { id in
                    self.paneView(id).map { self.isWithin(responder, $0) } ?? false
                }), pane != self.focused {
                    self.focused = pane
                    self.updateScrollBars()
                    self.onFocus?(pane)
                }
            }
        }
        updateScrollBars()
    }

    private func isWithin(_ responder: NSResponder?, _ view: NSView) -> Bool {
        guard let responder else { return false }
        if responder === view { return true }
        if let other = responder as? NSView { return other.isDescendant(of: view) }
        return false
    }

    // MARK: Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        for divider in geometry.dividers { draw(divider) }
        for box in splitBoxes.values { drawSplitBox(box) }
        if let line = dragLine { drawOutline(line) }
        context.restoreGState()
    }

    private func draw(_ divider: SplitDivider) {
        let t = theme, r = divider.rect
        let across = divider.axis == .sideBySide
        // The long edges, which meet the panes.
        func edges(_ color: NSColor) {
            color.setFill()
            if across {
                NSRect(x: r.minX, y: r.minY, width: 1, height: r.height).fill()
                NSRect(x: r.maxX - 1, y: r.minY, width: 1, height: r.height).fill()
            } else {
                NSRect(x: r.minX, y: r.minY, width: r.width, height: 1).fill()
                NSRect(x: r.minX, y: r.maxY - 1, width: r.width, height: 1).fill()
            }
        }
        let inner = across ? r.insetBy(dx: 1, dy: 0) : r.insetBy(dx: 0, dy: 1)
        switch style {
        case .platinum, .os2:
            t.background.setFill()
            r.fill()
            edges(t.border)
            t.drawRaisedBevel(inner)
            if style == .platinum { drawGrip(in: inner, across: across) }
        case .classic:
            // MPW's double line: black, white, black.
            t.light.setFill()
            r.fill()
            edges(t.border)
        case .beos:
            t.background.setFill()
            r.fill()
            t.drawRaisedBevel(r)
            drawGrip(in: inner, across: across, dots: true)
        }
    }

    /// Ridges across the middle of a divider, as on Platinum's scroll thumb; for BeOS, dots.
    private func drawGrip(in rect: CGRect, across: Bool, dots: Bool = false) {
        let t = theme
        let c = CGPoint(x: rect.midX.rounded(.down), y: rect.midY.rounded(.down))
        for i in -2...2 {
            let along = CGFloat(i * 3)
            let mark: CGRect = across
                ? CGRect(x: rect.minX + 1, y: c.y + along, width: max(1, rect.width - 2), height: 1)
                : CGRect(x: c.x + along, y: rect.minY + 1, width: 1, height: max(1, rect.height - 2))
            if dots {
                t.dark.setFill()
                CGRect(x: across ? c.x : mark.minX, y: across ? mark.minY : c.y, width: 1, height: 1).fill()
            } else {
                t.dark.setFill()
                mark.fill()
                t.light.setFill()
                mark.offsetBy(dx: across ? 0 : 1, dy: across ? 1 : 0).fill()
            }
        }
    }

    private func drawSplitBox(_ rect: CGRect) {
        let t = theme
        t.background.setFill()
        rect.fill()
        t.drawOutline(rect)
        t.drawRaisedBevel(rect.insetBy(dx: 1, dy: 1))
    }

    /// A dotted line around where a divider will go, black and white, so it shows over anything.
    private func drawOutline(_ rect: CGRect) {
        for (color, phase) in [(NSColor.white, CGFloat(0)), (NSColor.black, 2)] {
            let path = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
            path.lineWidth = 1
            path.setLineDash([2, 2], count: 2, phase: phase)
            color.setStroke()
            path.stroke()
        }
    }

    // MARK: Mouse

    public override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point), hit !== self { return hit }   // a scroll bar
        let p = pixels(convert(point, from: superview))
        return divider(at: p) != nil || splitBoxes.values.contains(where: { $0.contains(p) }) ? self : nil
    }

    private func divider(at point: CGPoint) -> SplitDivider? {
        geometry.dividers.last { $0.rect.insetBy(dx: -SplitMetrics.grab, dy: -SplitMetrics.grab).contains(point) }
    }

    public override func resetCursorRects() {
        for divider in geometry.dividers {
            addCursorRect(points(divider.rect.insetBy(dx: -SplitMetrics.grab, dy: -SplitMetrics.grab)),
                          cursor: divider.axis == .sideBySide ? .resizeLeftRight : .resizeUpDown)
        }
        for box in splitBoxes.values { addCursorRect(points(box), cursor: .resizeUpDown) }
    }

    public override func mouseDown(with event: NSEvent) {
        let p = pixels(convert(event.locationInWindow, from: nil))
        if let (pane, _) = splitBoxes.first(where: { $0.value.contains(p) }) {
            return trackSplit(of: pane)
        }
        if let divider = divider(at: p) { trackDivider(divider) }
    }

    /// Drags a divider: an outline follows the mouse, and the panes take their new sizes once, when it's let go (a
    /// terminal would redraw for every size on the way otherwise, as with the grow box).
    private func trackDivider(_ divider: SplitDivider) {
        guard let window else { return }
        let thickness = style.thickness
        var proposed = tree
        while let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let p = pixels(convert(event.locationInWindow, from: nil))
            proposed = tree
            proposed.move(divider, to: (divider.axis == .sideBySide ? p.x : p.y) - thickness / 2,
                          thickness: thickness, minimum: minimumPaneSize)
            dragLine = proposed.layout(in: pixelBounds, divider: thickness).dividers.first { $0.path == divider.path }?.rect
            needsDisplay = true
            if event.type == .leftMouseUp { break }
        }
        dragLine = nil
        if proposed != tree {
            tree = proposed
            changed()
        }
        needsDisplay = true
    }

    /// The Mac's split box: dragged down from above a pane's scroll bar, a line follows; let go, the pane splits there,
    /// the new one below.
    private func trackSplit(of pane: PaneID) {
        guard let window, let frame = geometry.frames[pane] else { return }
        let thickness = style.thickness
        var y: CGFloat?
        while let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let p = pixels(convert(event.locationInWindow, from: nil))
            let low = frame.minY + minimumPaneSize, high = frame.maxY - minimumPaneSize - thickness
            y = p.y >= low && high > low ? min(p.y, high) : nil
            dragLine = y.map { CGRect(x: frame.minX, y: $0, width: frame.width, height: thickness) }
            needsDisplay = true
            if event.type == .leftMouseUp { break }
        }
        dragLine = nil
        needsDisplay = true
        guard let y, let new = makePane?() else { return }
        tree.split(pane, along: .stacked, adding: new, fraction: Double((y - frame.minY) / (frame.height - thickness)))
        changed()
        focus(new)
    }
}

/// A split view's sizes, in Mac OS 9 pixels (outside it: a generic type can't hold stored statics).
private enum SplitMetrics {
    static let scrollBarWidth: CGFloat = 16
    static let splitBoxHeight: CGFloat = 7
    /// A divider can be caught this far either side of it.
    static let grab: CGFloat = 2
}

/// How a theme draws a split's divider.
enum DividerStyle {
    case platinum, classic, beos, os2

    init(_ chrome: ChromeTheme) {
        switch (chrome.family, chrome.tabStyle) {
        case (.beos, _): self = .beos
        case (.os2, _): self = .os2
        case (_, .folder): self = .classic
        default: self = .platinum
        }
    }

    /// In Mac OS 9 pixels.
    var thickness: CGFloat {
        switch self {
        case .platinum: 7
        case .classic: 4
        case .beos: 6
        case .os2: 6
        }
    }
}
