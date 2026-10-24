import AppKit
import GershwinChrome

/// Whatever owns a tabbed window's tabs. File ▸ Close Tab asks it to close the front one; a window without it closes.
@MainActor
public protocol ClassicTabDelegate: AnyObject {
    func closeFrontTab(of window: ClassicWindow)
}

/// A window drawn in its appearance's own shape (ChromeFamily): the classic Mac's, square and outlined in black under
/// a pinstriped title bar with a close box on the left and zoom and collapse boxes on the right; BeOS's, a grey frame
/// under a yellow title tab; or OS/2 Warp's, a sizing border round a blue title bar with the system menu at its left and
/// its buttons at its right. It is borderless, so macOS draws none of its own frame; everything is
/// in `frameView`, and the window does what its boxes ask itself (a borderless window has no buttons for
/// `performClose`/`performZoom` to press).
///
/// Put the window's content in `frameView.mainView`.
///
/// The chrome is drawn in Mac OS 9 pixels and scaled by the theme's `scale`: the frame view's coordinates are scaled,
/// so every line, bevel and glyph grows together, crisply at 1.5 or 2 on a Retina screen. The window's content is not
/// scaled (a Metal terminal under a scaled view would be resampled and blur): it sits in `container`, beside the frame
/// view rather than in it, over the frame's content area.
@MainActor
open class ClassicWindow: NSWindow {
    public let frameView: ClassicFrameView
    let container: ChromeContainerView

    public var theme: ClassicTheme {
        didSet {
            frameView.theme = theme
            applyTheme()
        }
    }

    /// Rolled up into its title bar (WindowShade), or for BeOS, into its tab.
    public private(set) var isCollapsed = false
    /// Told after the window collapses or expands, so content that draws continually (a terminal) can pause.
    public var onCollapsedChange: ((Bool) -> Void)?

    /// Set for a window with tabs; see `performCloseTab(_:)`.
    public weak var tabDelegate: ClassicTabDelegate?

    private var expandedHeight: CGFloat?
    private var unzoomedFrame: NSRect?

    public init(contentRect: NSRect, style: ClassicWindowStyle, theme: ClassicTheme) {
        self.theme = theme
        frameView = ClassicFrameView(style: style, theme: theme)
        container = ChromeContainerView(frameView: frameView)
        super.init(contentRect: contentRect, styleMask: [.borderless, .resizable, .miniaturizable],
                   backing: .buffered, defer: false)
        contentView = container
        hasShadow = true
        isReleasedWhenClosed = false
        minSize = NSSize(width: 220, height: 120)
        // macOS's own window tabs; Fanfare draws its own.
        tabbingMode = .disallowed
        applyTheme()
    }

    private func applyTheme() {
        appearance = theme.nsAppearance
        // A BeOS window is transparent beside its tabs, and clicks there go to whatever is behind.
        let opaque = theme.chrome.family != .beos
        isOpaque = opaque
        backgroundColor = opaque ? theme.background : .clear
        container.needsLayout = true
        invalidateShadow()
    }

    /// The window's size for content of `size` (in points) inside its chrome.
    public func frameSize(forContentSize size: NSSize) -> NSSize {
        frameView.chromeSize(around: size)
    }

    open override var canBecomeKey: Bool { true }
    /// A utility window floats over the document it works on, which stays the main window and drawn as active.
    open override var canBecomeMain: Bool { frameView.style != .utility }

    open override var title: String {
        didSet { frameView.titleChanged() }
    }

    open override func becomeKey() {
        super.becomeKey()
        frameView.activeStateChanged()
    }

    open override func resignKey() {
        super.resignKey()
        frameView.activeStateChanged()
    }

    open override func becomeMain() {
        super.becomeMain()
        frameView.activeStateChanged()
    }

    open override func resignMain() {
        super.resignMain()
        frameView.activeStateChanged()
    }

    /// The frame view's chrome got taller or shorter (a tab bar came or went): grow or shrink the window to match,
    /// keeping its top-left where it is, so the content keeps its size.
    func chromeHeightChanged(by delta: CGFloat) {
        guard delta != 0, isVisible, !isCollapsed else { return }
        let delta = delta * theme.scale
        var frame = self.frame
        frame.size.height += delta
        frame.origin.y -= delta
        setFrame(frame, display: true)
    }

    // MARK: Boxes

    /// The close box, and File ▸ Close: asks the delegate, then closes.
    open override func performClose(_ sender: Any?) {
        if let delegate, delegate.responds(to: #selector(NSWindowDelegate.windowShouldClose(_:))),
           delegate.windowShouldClose?(self) == false {
            return
        }
        close()
    }

    /// File ▸ Close Tab (⌘W): the front tab, or the window if it has no tabs. The window answers this itself, ahead
    /// of its delegate in the responder chain, so Settings and About close with ⌘W too.
    @objc open func performCloseTab(_ sender: Any?) {
        if let tabDelegate { tabDelegate.closeFrontTab(of: self) } else { performClose(sender) }
    }

    open override func performMiniaturize(_ sender: Any?) {
        miniaturize(sender)
    }

    open override func performZoom(_ sender: Any?) {
        zoom(sender)
    }

    /// The zoom box: between the size the user gave the window and the whole screen, as Mac OS 9 did. In one step,
    /// not animated: every frame of an animation is a resize, and each one makes the terminal reflow and its shell
    /// redraw.
    open override func zoom(_ sender: Any?) {
        if isCollapsed { toggleCollapsed() }
        guard let screen = screen ?? NSScreen.main else { return }
        if let unzoomed = unzoomedFrame, frame == screen.visibleFrame {
            unzoomedFrame = nil
            setFrame(unzoomed, display: true)
        } else {
            unzoomedFrame = frame
            setFrame(screen.visibleFrame, display: true)
        }
    }

    /// The collapse box, or a double-click on the title bar or tab: rolls the window up, or back down.
    public func toggleCollapsed() {
        if isCollapsed {
            isCollapsed = false
            let height = expandedHeight ?? 300
            styleMask.insert(.resizable)
            frameView.isCollapsed = false
            setFrame(WindowShade.expandedFrame(from: frame, height: height), display: true, animate: true)
        } else {
            expandedHeight = frame.height
            isCollapsed = true
            frameView.isCollapsed = true
            styleMask.remove(.resizable)
            let height = frameView.collapsedHeight
            let saved = minSize
            minSize = NSSize(width: saved.width, height: height)
            setFrame(WindowShade.collapsedFrame(from: frame, height: height), display: true, animate: true)
            minSize = saved
        }
        invalidateShadow()
        onCollapsedChange?(isCollapsed)
    }

    /// The grow box, as Mac OS 9 did it: a dotted outline follows the mouse, keeping the window's top-left where it
    /// is, and the window takes the new size once, when the mouse is let go. A live resize would hand the terminal a
    /// new size on every mouse movement, and a shell that redraws its prompt for each (fish, with a right prompt)
    /// leaves the stale ones wrapped across the screen.
    func trackGrow(from event: NSEvent) {
        trackResize(from: event, corner: .bottomRight)
    }

    /// The window's corners, for resizing from one (OPEN LOOK's resize corners).
    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    /// As `trackGrow`, from any corner: the opposite one stays where it is.
    func trackResize(from event: NSEvent, corner: Corner) {
        let start = NSEvent.mouseLocation
        let startFrame = frame
        let outline = ResizeOutline(frame: startFrame, theme: theme, style: frameView.style)
        outline.orderFront(nil)
        defer { outline.orderOut(nil) }
        var proposed = startFrame
        let left = corner == .topLeft || corner == .bottomLeft, top = corner == .topLeft || corner == .topRight
        while let next = nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let now = NSEvent.mouseLocation
            let dx = now.x - start.x, dy = now.y - start.y
            let width = max(minSize.width, startFrame.width + (left ? -dx : dx))
            let height = max(minSize.height, startFrame.height + (top ? dy : -dy))
            proposed = NSRect(x: left ? startFrame.maxX - width : startFrame.minX,
                              y: top ? startFrame.minY : startFrame.maxY - height, width: width, height: height)
            outline.setFrame(proposed, display: true)
            if next.type == .leftMouseUp { break }
        }
        if proposed != startFrame { setFrame(proposed, display: true) }
        invalidateShadow()
    }
}

/// The dotted outline the grow box drags: a window of its own, above the one being resized, that the mouse passes
/// through.
@MainActor
final class ResizeOutline: NSWindow {
    init(frame: NSRect, theme: ClassicTheme, style: ClassicWindowStyle) {
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = .floating
        contentView = OutlineView(theme: theme, style: style)
    }

    private final class OutlineView: NSView {
        let theme: ClassicTheme
        let style: ClassicWindowStyle

        init(theme: ClassicTheme, style: ClassicWindowStyle) {
            self.theme = theme
            self.style = style
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override var isFlipped: Bool { true }

        /// A one-point dotted line around the window, and another under where its title bar ends, in black and
        /// white so it shows over anything.
        override func draw(_ dirtyRect: NSRect) {
            NSColor.clear.setFill()
            bounds.fill(using: .copy)
            let top = ClassicFrameView.collapsedHeight(family: theme.chrome.family, style: style) * theme.scale
            for (color, phase) in [(NSColor.white, CGFloat(0)), (NSColor.black, 2)] {
                let path = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
                path.move(to: NSPoint(x: bounds.minX, y: top - 0.5))
                path.line(to: NSPoint(x: bounds.maxX, y: top - 0.5))
                path.lineWidth = 1
                path.setLineDash([2, 2], count: 2, phase: phase)
                color.setStroke()
                path.stroke()
            }
        }
    }
}

/// A window's content view: the frame view, scaled, filling it, and the window's own content, unscaled, over the
/// frame's content area.
@MainActor
final class ChromeContainerView: NSView {
    let frameView: ClassicFrameView

    init(frameView: ClassicFrameView) {
        self.frameView = frameView
        super.init(frame: .zero)
        addSubview(frameView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { frameView.isOpaque }

    override func layout() {
        super.layout()
        let scale = frameView.theme.scale
        frameView.frame = bounds
        // Points to Mac OS 9 pixels: the frame view draws and lays out its own parts in the latter.
        frameView.setBoundsSize(NSSize(width: bounds.width / scale, height: bounds.height / scale))
        if let main = frameView.mainView {
            if main.superview !== self { addSubview(main, positioned: .above, relativeTo: frameView) }
            main.frame = frameView.convert(frameView.mainRect, to: self)
        }
    }
}

/// Draws a window's frame, title bar or tabs, boxes, placard and grow box, in its appearance's family, and lays out
/// the views inside it: the window's own content (`mainView`), and for a document its scroll bar and, for the Mac
/// family with more than one tab, its tab bar.
@MainActor
public final class ClassicFrameView: NSView {
    public let style: ClassicWindowStyle
    public var theme: ClassicTheme {
        didSet {
            scrollBar?.theme = theme
            tabBar?.theme = theme
            tabsChanged()
            relayout()
            needsDisplay = true
        }
    }

    /// The window's content. It lives in the window's container, not in this (scaled) view, placed over `mainRect`.
    public var mainView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            relayout()
        }
    }

    /// Where `mainView` goes, in this view's (Mac OS 9 pixel) coordinates.
    var mainRect: CGRect {
        switch family {
        case .macintosh: let l = macLayout; return paneArea(main: l.main, scrollBar: l.scrollBar, grow: nil)
        case .beos: let l = beLayout; return paneArea(main: l.main, scrollBar: l.scrollBar, grow: l.growBox)
        case .os2: let l = os2Layout; return paneArea(main: l.main, scrollBar: l.scrollBar, grow: nil)
        case .amiga: let l = amigaLayout; return paneArea(main: l.main, scrollBar: l.scrollBar, grow: l.sizeGadget)
        case .openLook: let l = openLookLayout; return paneArea(main: l.main, scrollBar: l.scrollBar, grow: nil)
        }
    }

    /// The content panes draw their own scroll bars in (a ClassicSplitView's): the window's own scroll bar hides, and
    /// `mainView` takes its column too. Set it before the window is sized (`frameSize(forContentSize:)`).
    public var panesHaveScrollBars = false {
        didSet {
            scrollBar?.isHidden = panesHaveScrollBars || isCollapsed
            relayout()
        }
    }

    /// With `panesHaveScrollBars`, the bottom-right corner of `mainView` the panes' scroll bars stop short of, in
    /// Mac OS 9 pixels: a BeOS window's grow box. Zero for the Mac's, which is in the placard row below, and OS/2's.
    public var paneCorner: CGSize {
        guard panesHaveScrollBars else { return .zero }
        switch family {
        case .beos: return beLayout.growBox?.size ?? .zero
        case .amiga:
            // The size gadget, below the arrows in the right border.
            guard let size = amigaLayout.sizeGadget else { return .zero }
            return CGSize(width: size.width, height: max(0, mainRect.maxY - size.minY))
        case .macintosh, .os2, .openLook: return .zero
        }
    }

    private func paneArea(main: CGRect, scrollBar: CGRect?, grow: CGRect?) -> CGRect {
        guard panesHaveScrollBars, let right = grow?.maxX ?? scrollBar?.maxX else { return main }
        return CGRect(x: main.minX, y: main.minY, width: right - main.minX, height: main.height)
    }

    /// Lays out this view's parts and the container's placing of `mainView`.
    private func relayout() {
        needsLayout = true
        superview?.needsLayout = true
    }

    /// The size, in points, of a window whose content is `size` points.
    func chromeSize(around size: NSSize) -> NSSize {
        // The chrome's own extent, from a layout of a big window; it doesn't depend on the window's size.
        let big = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        let main: CGRect
        switch family {
        case .macintosh:
            let layout = WindowChromeLayout(bounds: big, style: style, showsTabBar: showsTabBar)
            main = paneArea(main: layout.main, scrollBar: layout.scrollBar, grow: nil)
        case .beos:
            let layout = BeOSChromeLayout(bounds: big, style: style, titleWidths: [0])
            main = paneArea(main: layout.main, scrollBar: layout.scrollBar, grow: layout.growBox)
        case .os2:
            let layout = OS2ChromeLayout(bounds: big, style: style, showsTabBar: showsTabBar,
                                         titleBar: theme.chrome.titleBar)
            main = paneArea(main: layout.main, scrollBar: layout.scrollBar, grow: nil)
        case .amiga:
            let layout = AmigaChromeLayout(bounds: big, style: style, showsTabBar: showsTabBar)
            main = paneArea(main: layout.main, scrollBar: layout.scrollBar, grow: layout.sizeGadget)
        case .openLook:
            let layout = OpenLookChromeLayout(bounds: big, style: style, showsTabBar: showsTabBar)
            main = paneArea(main: layout.main, scrollBar: layout.scrollBar, grow: nil)
        }
        let scale = theme.scale
        return NSSize(width: size.width + (big.width - main.width) * scale,
                      height: size.height + (big.height - main.height) * scale)
    }

    /// The document's scroll bar, along the right of `mainView`; nil for a panel.
    public let scrollBar: ClassicScrollBar?

    /// The Mac family's tab bar, above `mainView` while there is more than one tab; nil for a panel.
    let tabBar: ClassicTabBar?

    /// The window's tabs' titles, left to right, and which is in front. With one (or none), the window shows no tabs
    /// of its own: a Mac window no tab bar, a BeOS window one title tab, the window's title.
    public var tabTitles: [String] = [] { didSet { if tabTitles != oldValue { tabsChanged() } } }
    public var selectedTab: Int? { didSet { if selectedTab != oldValue { tabsChanged() } } }
    /// A click on a tab, and a double-click beside them.
    public var onSelectTab: ((Int) -> Void)?
    /// A click on a BeOS tab's close box, with more than one tab (with one, the box closes the window).
    public var onCloseTab: ((Int) -> Void)?
    public var onNewTab: (() -> Void)? {
        didSet { tabBar?.onNewTab = onNewTab }
    }

    /// The text in the placard along the bottom of a Mac document window.
    public var placardText = "" {
        didSet { if placardText != oldValue { needsDisplay = true } }
    }

    /// What Balloon Help says about the placard: what it shows is the app's to say.
    public var placardHelp: String?

    /// A progress bar at the placard's right, for something going on in the window; nil for none.
    public var placardProgress: ClassicProgress? {
        didSet {
            guard placardProgress != oldValue else { return }
            needsDisplay = true
            updateProgressTimer()
        }
    }

    private var progressPhase: CGFloat = 0
    private var progressTimer: Timer?

    /// The barber pole moves while it shows; nothing ticks otherwise.
    private func updateProgressTimer() {
        let animate = placardProgress == .indeterminate && window != nil && family == .macintosh
        if animate, progressTimer == nil {
            progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let placard = self.macLayout.placard else { return }
                    self.progressPhase = (self.progressPhase + 1)
                        .truncatingRemainder(dividingBy: ClassicProgressBar.stripe * 2)
                    self.setNeedsDisplay(placard)
                }
            }
        } else if !animate {
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }

    var isCollapsed = false {
        didSet {
            mainView?.isHidden = isCollapsed
            scrollBar?.isHidden = isCollapsed || panesHaveScrollBars
            tabBar?.isHidden = isCollapsed || !showsTabBar
            relayout()
            needsDisplay = true
        }
    }

    /// How far a BeOS window's tabs have been slid right (shift-drag).
    private var tabSlide: CGFloat = 0
    private var pressedBox: Box?
    /// Which BeOS tab's close box is held down.
    private var pressedTab: Int?
    private var extraHeight: CGFloat = 0

    private enum Box { case close, zoom, collapse, hide, systemMenu }

    init(style: ClassicWindowStyle, theme: ClassicTheme) {
        self.style = style
        self.theme = theme
        scrollBar = style == .document ? ClassicScrollBar(theme: theme) : nil
        tabBar = style == .document ? ClassicTabBar(theme: theme) : nil
        super.init(frame: .zero)
        if let scrollBar { addSubview(scrollBar) }
        if let tabBar {
            tabBar.isHidden = true
            tabBar.onSelect = { [weak self] index in self?.onSelectTab?(index) }
            addSubview(tabBar)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var isFlipped: Bool { true }
    public override var isOpaque: Bool { family != .beos }

    private var family: ChromeFamily { theme.chrome.family }

    /// Draws the window as frontmost whatever its state, for tests and the debug driver's snapshots, which look at a
    /// copy of the app running in the background.
    public var drawsAsActive = false {
        didSet {
            activeStateChanged()
            // Content that draws itself active or not with the window (a split view's scroll bars) follows.
            mainView?.needsLayout = true
            mainView?.subviews.forEach { $0.needsLayout = true }
        }
    }

    /// Whether the window is frontmost, which is when Mac OS 9 draws its pinstripes, boxes and scroll bars, and BeOS
    /// its yellow tab.
    var isActive: Bool { drawsAsActive || (window.map { $0.isKeyWindow || $0.isMainWindow } ?? false) }

    func activeStateChanged() {
        needsDisplay = true
        scrollBar?.isActive = isActive
    }

    func titleChanged() {
        needsDisplay = true
        if family == .beos { relayout() }
    }

    /// The height of a collapsed window, in points.
    var collapsedHeight: CGFloat {
        Self.collapsedHeight(family: family, style: style) * theme.scale
    }

    /// In Mac OS 9 pixels: a Mac window's title bar, a BeOS window's tab, an OS/2 window's title bar in its border.
    static func collapsedHeight(family: ChromeFamily, style: ClassicWindowStyle) -> CGFloat {
        switch family {
        case .macintosh: style.collapsedHeight
        case .beos: BeOSMetrics.tabHeight(for: style)
        case .os2: OS2Metrics.collapsedHeight(for: style)
        case .amiga: AmigaMetrics.collapsedHeight(for: style)
        case .openLook: OpenLookMetrics.collapsedHeight(for: style)
        }
    }

    // MARK: Tabs

    /// The Mac's and OS/2's tab bar shows from two tabs; BeOS's tabs are in its title row.
    var showsTabBar: Bool { family != .beos && tabTitles.count > 1 }

    private func tabsChanged() {
        tabBar?.titles = tabTitles
        tabBar?.selectedIndex = selectedTab
        tabBar?.isHidden = !showsTabBar || isCollapsed
        // A tab bar coming or going (or the family changing) changes how tall the chrome is; the window keeps its
        // content's size by growing or shrinking to match.
        let height = showsTabBar ? ChromeMetrics.tabBarHeight : 0
        if height != extraHeight {
            let delta = height - extraHeight
            extraHeight = height
            (window as? ClassicWindow)?.chromeHeightChanged(by: delta)
        }
        relayout()
        needsDisplay = true
    }

    // MARK: Layout

    /// A utility window's title is small: Geneva 9, or for BeOS, a smaller bold.
    private var titleFont: NSFont {
        switch (family, style) {
        case (.os2, .utility), (.amiga, .utility), (.openLook, .utility): theme.font(size: 9)
        case (.os2, _), (.amiga, _), (.openLook, _): theme.font(size: 11)
        case (.beos, .utility): theme.font(size: 10)
        case (.macintosh, .utility): ClassicTheme.smallFont(size: 9)
        default: theme.font(size: 12)
        }
    }

    private var macLayout: WindowChromeLayout {
        WindowChromeLayout(bounds: bounds, style: style, isCollapsed: isCollapsed, showsTabBar: showsTabBar)
    }

    /// The titles a BeOS window's tabs show: the tabs', or with one tab the window's own.
    private var beTitles: [String] {
        tabTitles.count > 1 ? tabTitles : [window?.title ?? ""]
    }

    private var os2Layout: OS2ChromeLayout {
        OS2ChromeLayout(bounds: bounds, style: style, isCollapsed: isCollapsed, showsTabBar: showsTabBar,
                        titleBar: theme.chrome.titleBar)
    }

    private var openLookLayout: OpenLookChromeLayout {
        OpenLookChromeLayout(bounds: bounds, style: style, isCollapsed: isCollapsed, showsTabBar: showsTabBar)
    }

    private var amigaLayout: AmigaChromeLayout {
        AmigaChromeLayout(bounds: bounds, style: style, isCollapsed: isCollapsed, showsTabBar: showsTabBar)
    }

    private var beLayout: BeOSChromeLayout {
        BeOSChromeLayout(bounds: bounds, style: style, isCollapsed: isCollapsed,
                         titleWidths: beTitles.map { theme.textWidth($0, font: titleFont) },
                         frontTab: tabTitles.count > 1 ? (selectedTab ?? 0) : 0, slide: tabSlide)
    }

    public override func layout() {
        super.layout()
        switch family {
        case .macintosh:
            let layout = macLayout
            if let scrollBar, let rect = layout.scrollBar { scrollBar.frame = rect }
            if let tabBar, let rect = layout.tabBar { tabBar.frame = rect }
        case .beos:
            let layout = beLayout
            if let scrollBar, let rect = layout.scrollBar { scrollBar.frame = rect }
        case .os2:
            let layout = os2Layout
            if let scrollBar, let rect = layout.scrollBar { scrollBar.frame = rect }
            if let tabBar, let rect = layout.tabBar { tabBar.frame = rect }
        case .amiga:
            let layout = amigaLayout
            if let scrollBar, let rect = layout.scrollBar { scrollBar.frame = rect }
            if let tabBar, let rect = layout.tabBar { tabBar.frame = rect }
        case .openLook:
            let layout = openLookLayout
            if let scrollBar, let rect = layout.scrollBar { scrollBar.frame = rect }
            if let tabBar, let rect = layout.tabBar { tabBar.frame = rect }
        }
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        activeStateChanged()
        updateProgressTimer()
    }

    // MARK: Balloon Help

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways,
                                                             .inVisibleRect], owner: self))
    }

    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard ClassicBalloon.shared.isEnabled, let window else { return }
        guard let (text, rect) = help(at: convert(event.locationInWindow, from: nil)) else {
            return ClassicBalloon.shared.hide()
        }
        let onScreen = window.convertToScreen(convert(rect, to: nil))
        ClassicBalloon.shared.show(text, pointingAt: onScreen, theme: theme)
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        ClassicBalloon.shared.hide()
    }

    /// What Balloon Help says about the part of the window at `point`, and the part, as Mac OS 9 worded it.
    func help(at point: CGPoint) -> (String, CGRect)? {
        let scroll = "Scroll bar: To see more of what is in this window, click the arrows or drag the scroll box."
        let grow = "Size box: To make this window larger or smaller, drag here."
        switch family {
        case .macintosh:
            let layout = macLayout
            if layout.closeBox.contains(point) { return ("Close box: To close this window, click here.", layout.closeBox) }
            if let zoom = layout.zoomBox, zoom.contains(point) {
                return ("Zoom box: To make this window as large as the screen, or back to the size you gave it, "
                        + "click here.", zoom)
            }
            if layout.collapseBox.contains(point) {
                return ("Collapse box: To roll this window up into its title bar, or back down, click here.",
                        layout.collapseBox)
            }
            if layout.titleBar.contains(point) {
                return ("Title bar: To move this window, drag here. To roll it up into its title bar, double-click "
                        + "here.", layout.titleBar)
            }
            if let bar = layout.tabBar, bar.contains(point) {
                return ("Tabs: To see what's in a tab, click it. To open another, choose New Tab from the File menu.",
                        bar)
            }
            if let rect = layout.scrollBar, rect.contains(point) { return (scroll, rect) }
            if let rect = layout.growBox, rect.contains(point) { return (grow, rect) }
            if let rect = layout.placard, rect.contains(point), let placardHelp { return (placardHelp, rect) }
            return nil
        case .beos:
            let layout = beLayout
            if let tab = layout.closeBox(at: point) {
                return ("Close box: To close this \(tabTitles.count > 1 ? "tab" : "window"), click here.",
                        layout.closeBoxes[tab])
            }
            if let zoom = layout.zoomBox, zoom.contains(point) {
                return ("Zoom box: To make this window as large as the screen, or back, click here.", zoom)
            }
            if let tab = layout.tab(at: point) {
                return ("To move this window, drag its tab. To slide the tab along the window, Shift-drag it. To "
                        + "roll the window up into it, double-click.", layout.tabs[tab])
            }
            if let rect = layout.scrollBar, rect.contains(point) { return (scroll, rect) }
            if let rect = layout.growBox, rect.contains(point) { return (grow, rect) }
            return nil
        case .os2:
            let layout = os2Layout
            if layout.systemMenu.contains(point) {
                return ("System menu: To move, size, hide or close this window, click here. To close it, "
                        + "double-click.", layout.systemMenu)
            }
            if let hide = layout.hideButton, hide.contains(point) {
                return ("Hide button: To put this window away, click here.", hide)
            }
            if let maximize = layout.maximizeButton, maximize.contains(point) {
                return ("Maximize button: To make this window as large as the screen, or back, click here.", maximize)
            }
            if let close = layout.closeButton, close.contains(point) {
                return ("Close button: To close this window, click here.", close)
            }
            if layout.titleBar.contains(point) {
                return ("Title bar: To move this window, drag here. To maximize it, double-click here.",
                        layout.titleBar)
            }
            if let bar = layout.tabBar, bar.contains(point) {
                return ("Tabs: To see what's in a tab, click it.", bar)
            }
            if let rect = layout.scrollBar, rect.contains(point) { return (scroll, rect) }
            if !layout.content.contains(point) {
                return ("Sizing border: To make this window larger or smaller, drag here.", bounds)
            }
            return nil
        case .amiga:
            let layout = amigaLayout
            if layout.closeGadget.contains(point) {
                return ("Close gadget: To close this window, click here.", layout.closeGadget)
            }
            if let zoom = layout.zoomGadget, zoom.contains(point) {
                return ("Zoom gadget: To switch this window between its size and the whole screen, click here.", zoom)
            }
            if layout.depthGadget.contains(point) {
                return ("Depth gadget: To send this window behind the others, or bring it to the front, click here.",
                        layout.depthGadget)
            }
            if layout.titleBar.contains(point) { return ("Drag bar: To move this window, drag here.", layout.titleBar) }
            if let rect = layout.scrollBar, rect.contains(point) { return (scroll, rect) }
            if let rect = layout.sizeGadget, rect.contains(point) {
                return ("Size gadget: To make this window larger or smaller, drag here.", rect)
            }
            return nil
        case .openLook:
            let layout = openLookLayout
            if layout.button.contains(point) {
                return layout.hasPushpin
                    ? ("Pushpin: To put this window away, pull the pin out: click here.", layout.button)
                    : ("Window menu button: To close, size or put this window behind the others, click here.",
                       layout.button)
            }
            if let corner = layout.corner(at: point) {
                return ("Resize corner: To make this window larger or smaller, drag here.", layout.corners[corner])
            }
            if layout.header.contains(point) {
                return ("Header: To move this window, drag here. To make it full size, or back, double-click.",
                        layout.header)
            }
            if let rect = layout.scrollBar, rect.contains(point) {
                return ("Scrollbar: To scroll, click the elevator's arrows, drag it, or click the cable. To go to the "
                        + "start or the end, click an anchor.", rect)
            }
            return nil
        }
    }

    // MARK: Drawing

    public override func draw(_ dirtyRect: NSRect) {
        switch family {
        case .macintosh: drawMac(macLayout)
        case .beos:
            drawBeOS(beLayout)
            // The shadow follows the window's opaque shape, which the tabs change.
            window?.invalidateShadow()
        case .os2:
            drawOS2(os2Layout)
            return
        case .amiga:
            drawAmiga(amigaLayout)
            return
        case .openLook:
            drawOpenLook(openLookLayout)
            return
        }
        if let grow = family == .macintosh ? macLayout.growBox : beLayout.growBox { drawGrowBox(grow) }
    }

    private func drawOS2(_ layout: OS2ChromeLayout) {
        let t = theme
        // The sizing border: raised all round, the title bar and the content set into it. Windows 95's is its
        // two-level bevel instead: light grey and black outside, white and dark grey inside.
        t.background.setFill()
        bounds.fill()
        let inside = layout.isCollapsed ? layout.titleBar : layout.titleBar.union(layout.content)
        if layout.titleStyle == .windows95 {
            drawEdge(bounds, topLeft: t.background, bottomRight: t.border)
            drawEdge(bounds.insetBy(dx: 1, dy: 1), topLeft: t.light, bottomRight: t.dark)
        } else {
            t.drawOutline(bounds)
            t.drawRaisedBevel(bounds.insetBy(dx: 1, dy: 1))
            t.drawSunkenBevel(inside.insetBy(dx: -1, dy: -1))
        }
        if layout.titleStyle == .windows31 {
            // Its sizing border's notches, marking off the corners.
            t.border.setFill()
            let f = OS2Metrics.frameWidth(for: style), c = layout.titleBar.height + f
            for x in [bounds.minX + c, bounds.maxX - c] {
                NSRect(x: x, y: bounds.minY, width: 1, height: f).fill()
                NSRect(x: x, y: bounds.maxY - f, width: 1, height: f).fill()
            }
            for y in [bounds.minY + c, bounds.maxY - c] {
                NSRect(x: bounds.minX, y: y, width: f, height: 1).fill()
                NSRect(x: bounds.maxX - f, y: y, width: f, height: 1).fill()
            }
        }

        let colours = t.palette.titleTab
        (isActive ? colours.map { NSColor($0.face) } ?? t.highlight
            : colours.map { NSColor($0.inactiveFace) } ?? t.background).setFill()
        layout.titleBar.fill()
        let title = window?.title ?? ""
        let titleRect = layout.titleRect(textWidth: t.textWidth(title, font: titleFont),
                                         textHeight: ceil(titleFont.ascender - titleFont.descender))
        let ink = isActive ? colours.map { NSColor($0.text) } ?? t.selectedText
            : colours?.inactiveText.map { NSColor($0) } ?? t.text
        t.drawText(title, in: titleRect, font: titleFont, color: ink,
                   alignment: layout.titleStyle == .windows95 ? .left : .center)

        drawOS2Button(layout.systemMenu, glyph: .systemMenu, titleStyle: layout.titleStyle)
        if let hide = layout.hideButton { drawOS2Button(hide, glyph: .hide, titleStyle: layout.titleStyle) }
        if let maximize = layout.maximizeButton {
            drawOS2Button(maximize, glyph: .zoom, titleStyle: layout.titleStyle)
        }
        if let close = layout.closeButton { drawOS2Button(close, glyph: .close, titleStyle: layout.titleStyle) }
        if !layout.isCollapsed, layout.content.height > 0 {
            t.drawSunkenBevel(layout.content.insetBy(dx: -1, dy: -1))
        }
    }

    /// A bevel of one-pixel lines just inside `rect`.
    private func drawEdge(_ rect: CGRect, topLeft: NSColor, bottomRight: NSColor) {
        topLeft.setFill()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width - 1, height: 1).fill()
        NSRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height - 1).fill()
        bottomRight.setFill()
        NSRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1).fill()
        NSRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()
    }

    /// A title bar button: a raised grey square, sunk while pressed, and its glyph in the middle; in Windows' styles,
    /// Windows' glyphs.
    private func drawOS2Button(_ rect: CGRect, glyph: Box, titleStyle: TitleBarStyle) {
        let t = theme
        let pressed = pressedBox == glyph
        let c = CGPoint(x: (rect.midX).rounded(.down) + (pressed ? 1 : 0), y: (rect.midY).rounded(.down) + (pressed ? 1 : 0))
        switch titleStyle {
        case .windows31: return drawWindows31Button(rect, glyph: glyph, pressed: pressed, center: c)
        case .windows95: return drawWindows95Button(rect, glyph: glyph, pressed: pressed, center: c)
        case .warp: break
        }
        t.drawButtonFace(rect, pressed: pressed)
        let ink = t.text
        ink.setFill()
        switch glyph {
        case .systemMenu:
            // The window's icon: a small window, its title bar filled.
            t.drawOutline(NSRect(x: c.x - 5, y: c.y - 4, width: 10, height: 9), color: ink)
            NSRect(x: c.x - 5, y: c.y - 4, width: 10, height: 3).fill()
        case .hide:
            // Warp 4's hide button: a bar along the bottom.
            NSRect(x: c.x - 3, y: c.y + 2, width: 6, height: 2).fill()
        case .zoom:
            // Maximize: a window filling the button, its top thick.
            t.drawOutline(NSRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10), color: ink)
            NSRect(x: c.x - 5, y: c.y - 5, width: 10, height: 2).fill()
        case .close:
            for i in 0..<7 {
                NSRect(x: c.x - 3 + CGFloat(i), y: c.y - 3 + CGFloat(i), width: 2, height: 1).fill()
                NSRect(x: c.x + 2 - CGFloat(i), y: c.y - 3 + CGFloat(i), width: 2, height: 1).fill()
            }
        case .collapse:
            break
        }
    }

    private func drawMac(_ layout: WindowChromeLayout) {
        let t = theme
        t.background.setFill()
        bounds.fill()
        t.drawOutline(bounds)
        t.drawRaisedBevel(bounds.insetBy(dx: 1, dy: 1))

        if !layout.isCollapsed, layout.content.width > 0 {
            // The content sits in a shallow well cut into the frame.
            t.drawSunkenBevel(layout.content.insetBy(dx: -1, dy: -1))
        }

        let title = window?.title ?? ""
        let titleRect = layout.titleRect(textWidth: t.textWidth(title, font: titleFont),
                                         textHeight: ceil(titleFont.ascender - titleFont.descender))
        if isActive {
            drawPinstripes(layout.stripeAreas(title: titleRect))
            drawMacBox(layout.closeBox, glyph: .close, pressed: pressedBox == .close)
            if let zoom = layout.zoomBox { drawMacBox(zoom, glyph: .zoom, pressed: pressedBox == .zoom) }
            drawMacBox(layout.collapseBox, glyph: .collapse, pressed: pressedBox == .collapse)
        }
        t.drawText(title, in: titleRect, font: titleFont, color: isActive ? t.text : t.disabledText, alignment: .center)

        if let placard = layout.placard { drawPlacard(placard) }
    }

    private func drawPinstripes(_ areas: [CGRect]) {
        for area in areas {
            for y in stride(from: area.minY, to: area.maxY - 1, by: 2) {
                theme.pinstripe.setFill()
                NSRect(x: area.minX, y: y, width: area.width, height: 1).fill()
                theme.light.setFill()
                NSRect(x: area.minX, y: y + 1, width: area.width, height: 1).fill()
            }
        }
    }

    private func drawMacBox(_ rect: CGRect, glyph: Box, pressed: Bool) {
        let t = theme
        // The recess the box sits in, then the box itself.
        t.drawSunkenBevel(rect)
        let face = rect.insetBy(dx: 1, dy: 1)
        t.drawButtonFace(face, pressed: pressed)
        let ink = pressed ? t.light : t.border
        switch glyph {
        case .close, .hide, .systemMenu:
            break
        case .zoom:
            // A smaller window in the top-left of the box.
            t.drawOutline(NSRect(x: face.minX + 2, y: face.minY + 2, width: 5, height: 5), color: ink)
        case .collapse:
            // The window rolled up: a bar across the middle.
            t.drawOutline(NSRect(x: face.minX + 2, y: face.midY - 2, width: face.width - 4, height: 4), color: ink)
        }
    }

    private func drawPlacard(_ rect: CGRect) {
        let t = theme
        t.background.setFill()
        rect.fill()
        t.drawOutline(rect)
        t.drawRaisedBevel(rect.insetBy(dx: 1, dy: 1))
        var textRect = rect.insetBy(dx: 6, dy: 0)
        if let placardProgress {
            // At the right, a third of the placard up to 100 pixels, its text in what's left.
            let width = min(100, floor(rect.width / 3))
            let bar = NSRect(x: rect.maxX - 4 - width, y: rect.minY + 3, width: width, height: rect.height - 6)
            ClassicProgressBar.draw(value: placardProgress.fraction, phase: progressPhase, in: bar, theme: t)
            textRect.size.width = max(0, bar.minX - 6 - textRect.minX)
        }
        t.drawText(placardText, in: textRect, font: ClassicTheme.smallFont(size: 10),
                   color: isActive ? t.text : t.disabledText)
    }

    private func drawGrowBox(_ rect: CGRect) {
        let t = theme
        t.background.setFill()
        rect.fill()
        t.drawOutline(rect)
        t.drawRaisedBevel(rect.insetBy(dx: 1, dy: 1))
        guard isActive || family == .beos else { return }
        // Three grooves running down to the corner.
        for i in 0..<3 {
            let reach = CGFloat(4 + i * 3)
            for k in 0..<Int(reach) {
                let x = rect.maxX - 4 - CGFloat(k)
                let y = rect.maxY - 4 - reach + 1 + CGFloat(k)
                t.dark.setFill()
                NSRect(x: x, y: y, width: 1, height: 1).fill()
                t.light.setFill()
                NSRect(x: x + 1, y: y, width: 1, height: 1).fill()
            }
        }
    }

    private func drawBeOS(_ layout: BeOSChromeLayout) {
        let t = theme
        // Nothing beside the tabs: the desktop shows through.
        NSColor.clear.setFill()
        bounds.fill(using: .copy)

        if !layout.isCollapsed, layout.body.height > 0 {
            t.background.setFill()
            layout.body.fill()
            t.drawOutline(layout.body)
            t.drawRaisedBevel(layout.body.insetBy(dx: 1, dy: 1))
            t.drawSunkenBevel(layout.content.insetBy(dx: -1, dy: -1))
        }

        let titles = beTitles
        for i in layout.tabs.indices where i != layout.frontTab {
            drawTitleTab(layout.tabs[i], title: titles[i], titleRect: layout.titles[i], front: false)
        }
        let front = layout.frontTab
        drawTitleTab(layout.tabs[front], title: titles[front], titleRect: layout.titles[front], front: true)
        for (i, box) in layout.closeBoxes.enumerated() {
            drawBeBox(box, glyph: .close, pressed: pressedBox == .close && pressedTab == i, lit: i == front)
        }
        if let zoom = layout.zoomBox { drawBeBox(zoom, glyph: .zoom, pressed: pressedBox == .zoom, lit: true) }
    }

    private func drawTitleTab(_ rect: CGRect, title: String, titleRect: CGRect, front: Bool) {
        let t = theme
        let colours = t.palette.titleTab
        let lit = front && isActive
        NSColor(lit ? colours?.face ?? t.palette.highlight : colours?.inactiveFace ?? t.palette.background).setFill()
        rect.fill()
        t.drawOutline(rect)
        // Its own bevel: yellow's highlight and shade when lit, the frame's greys otherwise.
        let light = lit ? colours.map { NSColor($0.light) } ?? t.light : t.light
        let dark = lit ? colours.map { NSColor($0.dark) } ?? t.dark : t.dark
        let inner = rect.insetBy(dx: 1, dy: 1)
        light.setFill()
        NSRect(x: inner.minX, y: inner.minY, width: inner.width - 1, height: 1).fill()
        NSRect(x: inner.minX, y: inner.minY, width: 1, height: inner.height - 1).fill()
        dark.setFill()
        NSRect(x: inner.maxX - 1, y: inner.minY + 1, width: 1, height: inner.height - 1).fill()
        let ink = lit ? colours.map { NSColor($0.text) } ?? t.text : t.disabledText
        t.drawText(title, in: titleRect, font: titleFont, color: ink)
    }

    /// `lit`: on the front tab, which is coloured while the window is frontmost.
    private func drawBeBox(_ rect: CGRect, glyph: Box, pressed: Bool, lit front: Bool) {
        let t = theme
        let colours = t.palette.titleTab
        let lit = isActive && front
        let face = pressed ? (colours.map { NSColor($0.dark) } ?? t.dark)
            : lit ? (colours.map { NSColor($0.light) } ?? t.light) : t.light
        face.setFill()
        rect.fill()
        t.drawOutline(rect, color: t.border)
        if pressed { t.drawSunkenBevel(rect.insetBy(dx: 1, dy: 1)) } else { t.drawRaisedBevel(rect.insetBy(dx: 1, dy: 1)) }
        if glyph == .zoom {
            // BeOS's zoom box: a small window over the corner of a bigger one.
            t.drawOutline(NSRect(x: rect.minX + 4, y: rect.minY + 4, width: 7, height: 7), color: t.border)
            face.setFill()
            NSRect(x: rect.minX + 2, y: rect.minY + 2, width: 5, height: 5).fill()
            t.drawOutline(NSRect(x: rect.minX + 2, y: rect.minY + 2, width: 5, height: 5), color: t.border)
        }
    }

    /// Windows 3.1's: the control-menu box (a long bar with a shadow, in a grey box), and the minimize ▼ and
    /// maximize ▲ buttons, raised.
    private func drawWindows31Button(_ rect: CGRect, glyph: Box, pressed: Bool, center c: CGPoint) {
        let t = theme
        t.background.setFill()
        rect.fill()
        t.drawOutline(rect)
        if glyph == .systemMenu {
            t.dark.setFill()
            NSRect(x: c.x - 5, y: c.y, width: 12, height: 3).fill()
            t.light.setFill()
            NSRect(x: c.x - 6, y: c.y - 1, width: 12, height: 3).fill()
            t.drawOutline(NSRect(x: c.x - 6, y: c.y - 1, width: 12, height: 3))
            return
        }
        if pressed { t.drawSunkenBevel(rect.insetBy(dx: 1, dy: 1)) } else {
            drawEdge(rect.insetBy(dx: 1, dy: 1), topLeft: t.light, bottomRight: t.dark)
            drawEdge(rect.insetBy(dx: 2, dy: 2), topLeft: t.light, bottomRight: t.dark)
        }
        t.border.setFill()
        let down = glyph == .hide
        for row in 0..<4 {
            let w = CGFloat(7 - row * 2)
            let y = down ? c.y - 1 + CGFloat(row) : c.y + 2 - CGFloat(row)
            NSRect(x: c.x - w / 2 + 0.5, y: y, width: w, height: 1).fill()
        }
    }

    /// Windows 95's: raised buttons with _, □ and ✕, and the window's icon, a little terminal.
    private func drawWindows95Button(_ rect: CGRect, glyph: Box, pressed: Bool, center c: CGPoint) {
        let t = theme
        if glyph == .systemMenu {
            NSColor.black.setFill()
            rect.insetBy(dx: 1, dy: 2).fill()
            t.light.setFill()
            NSRect(x: rect.minX + 3, y: rect.minY + 5, width: 3, height: 1).fill()
            NSRect(x: rect.minX + 4, y: rect.minY + 6, width: 3, height: 1).fill()
            NSRect(x: rect.minX + 3, y: rect.minY + 7, width: 3, height: 1).fill()
            NSRect(x: rect.minX + 8, y: rect.minY + 9, width: 4, height: 1).fill()
            return
        }
        t.background.setFill()
        rect.fill()
        if pressed {
            drawEdge(rect, topLeft: t.border, bottomRight: t.light)
            drawEdge(rect.insetBy(dx: 1, dy: 1), topLeft: t.dark, bottomRight: t.background)
        } else {
            drawEdge(rect, topLeft: t.light, bottomRight: t.border)
            drawEdge(rect.insetBy(dx: 1, dy: 1), topLeft: t.background, bottomRight: t.dark)
        }
        t.border.setFill()
        switch glyph {
        case .hide:
            NSRect(x: c.x - 4, y: c.y + 2, width: 6, height: 2).fill()
        case .zoom:
            t.drawOutline(NSRect(x: c.x - 4, y: c.y - 4, width: 9, height: 8), color: t.border)
            NSRect(x: c.x - 4, y: c.y - 4, width: 9, height: 2).fill()
        case .close:
            for i in 0..<6 {
                NSRect(x: c.x - 3 + CGFloat(i), y: c.y - 3 + CGFloat(i), width: 2, height: 1).fill()
                NSRect(x: c.x + 2 - CGFloat(i), y: c.y - 3 + CGFloat(i), width: 2, height: 1).fill()
            }
        default:
            break
        }
    }

    // MARK: Amiga

    private func drawAmiga(_ layout: AmigaChromeLayout) {
        let t = theme
        let colours = t.palette.titleTab
        // The active window's borders and drag bar in its colour (Workbench's blue), the rest in grey.
        let frame = isActive ? colours.map { NSColor($0.face) } ?? t.highlight : t.background
        frame.setFill()
        bounds.fill()
        drawEdge(bounds, topLeft: t.light, bottomRight: t.dark)
        if !layout.isCollapsed, layout.content.height > 0 {
            drawEdge(layout.content.insetBy(dx: -1, dy: -1), topLeft: t.dark, bottomRight: t.light)
        }
        drawEdge(layout.titleBar, topLeft: t.light, bottomRight: t.dark)
        let title = window?.title ?? ""
        let titleRect = layout.titleRect(textWidth: t.textWidth(title, font: titleFont),
                                         textHeight: ceil(titleFont.ascender - titleFont.descender))
        let ink = isActive ? colours.map { NSColor($0.text) } ?? t.text
            : colours?.inactiveText.map { NSColor($0) } ?? t.text
        t.drawText(title, in: titleRect, font: titleFont, color: ink)
        drawAmigaGadget(layout.closeGadget, glyph: .close, fill: frame)
        if let zoom = layout.zoomGadget { drawAmigaGadget(zoom, glyph: .zoom, fill: frame) }
        drawAmigaGadget(layout.depthGadget, glyph: .collapse, fill: frame)
        if let size = layout.sizeGadget { drawAmigaGadget(size, glyph: .hide, fill: frame) }
    }

    /// A gadget: raised (sunk while held) on the frame's colour, its picture in black and white. `.collapse` is the
    /// depth gadget, `.hide` the size gadget.
    private func drawAmigaGadget(_ rect: CGRect, glyph: Box, fill: NSColor) {
        let t = theme
        let pressed = pressedBox == glyph
        fill.setFill()
        rect.fill()
        if pressed { drawEdge(rect, topLeft: t.dark, bottomRight: t.light) } else {
            drawEdge(rect, topLeft: t.light, bottomRight: t.dark)
        }
        let c = CGPoint(x: rect.midX.rounded(.down), y: rect.midY.rounded(.down))
        switch glyph {
        case .close:
            // A small box with a dot in it.
            t.drawOutline(NSRect(x: c.x - 3, y: c.y - 3, width: 7, height: 7), color: t.dark)
            t.light.setFill()
            NSRect(x: c.x - 2, y: c.y - 2, width: 5, height: 5).fill()
            t.dark.setFill()
            NSRect(x: c.x, y: c.y, width: 1, height: 1).fill()
        case .zoom:
            // A window in a window.
            t.drawOutline(NSRect(x: c.x - 6, y: c.y - 4, width: 12, height: 9), color: t.dark)
            t.light.setFill()
            NSRect(x: c.x - 5, y: c.y - 3, width: 4, height: 3).fill()
            t.drawOutline(NSRect(x: c.x - 6, y: c.y - 4, width: 6, height: 5), color: t.dark)
        case .collapse:
            // Two windows, the front one white over the black one behind.
            t.drawOutline(NSRect(x: c.x - 6, y: c.y - 4, width: 8, height: 6), color: t.dark)
            t.light.setFill()
            NSRect(x: c.x - 2, y: c.y - 1, width: 8, height: 6).fill()
            t.drawOutline(NSRect(x: c.x - 2, y: c.y - 1, width: 8, height: 6), color: t.dark)
        case .hide:
            // The size gadget: a box with a smaller one at its corner.
            t.drawOutline(NSRect(x: c.x - 5, y: c.y - 3, width: 10, height: 7), color: t.dark)
            t.light.setFill()
            NSRect(x: c.x - 4, y: c.y - 2, width: 4, height: 3).fill()
        case .systemMenu:
            break
        }
    }

    // MARK: OPEN LOOK

    private func drawOpenLook(_ layout: OpenLookChromeLayout) {
        let t = theme
        let colours = t.palette.titleTab
        t.background.setFill()
        bounds.fill()
        t.drawOutline(bounds)
        drawEdge(bounds.insetBy(dx: 1, dy: 1), topLeft: t.light, bottomRight: t.dark)
        // The resize corners: an L in each corner, raised.
        for (i, corner) in layout.corners.enumerated() {
            let b = OpenLookMetrics.border(for: style)
            let right = i == 1 || i == 3, bottom = i >= 2
            let horizontal = CGRect(x: corner.minX, y: bottom ? corner.maxY - b : corner.minY, width: corner.width,
                                    height: b)
            let vertical = CGRect(x: right ? corner.maxX - b : corner.minX, y: corner.minY, width: b,
                                  height: corner.height)
            for arm in [horizontal, vertical] {
                t.well.setFill()
                arm.fill()
            }
            for arm in [horizontal, vertical] { drawEdge(arm, topLeft: t.light, bottomRight: t.border) }
        }
        // The header: the focused window's darker.
        (isActive ? colours.map { NSColor($0.face) } ?? t.well : t.background).setFill()
        layout.header.fill()
        t.dark.setFill()
        NSRect(x: layout.header.minX, y: layout.header.maxY, width: layout.header.width, height: 1).fill()
        let title = window?.title ?? ""
        let titleRect = layout.titleRect(textWidth: t.textWidth(title, font: titleFont),
                                         textHeight: ceil(titleFont.ascender - titleFont.descender))
        t.drawText(title, in: titleRect, font: titleFont, color: t.text, alignment: .center)
        if layout.hasPushpin { drawPushpin(layout.button) } else { drawWindowMenuButton(layout.button) }
        if !layout.isCollapsed, layout.content.height > 0 {
            drawEdge(layout.content.insetBy(dx: -1, dy: -1), topLeft: t.dark, bottomRight: t.light)
        }
    }

    /// The window menu button: a raised box with a triangle pointing down.
    private func drawWindowMenuButton(_ rect: CGRect) {
        let t = theme
        let pressed = pressedBox == .systemMenu
        t.background.setFill()
        rect.fill()
        drawEdge(rect, topLeft: pressed ? t.dark : t.light, bottomRight: pressed ? t.light : t.dark)
        t.border.setFill()
        let c = CGPoint(x: rect.midX.rounded(.down), y: rect.midY.rounded(.down))
        // An outlined triangle, pointing down.
        for row in 0..<5 {
            let half = CGFloat(4 - row)
            if row == 0 {
                NSRect(x: c.x - half, y: c.y - 2, width: half * 2 + 1, height: 1).fill()
            } else {
                NSRect(x: c.x - half, y: c.y - 2 + CGFloat(row), width: 1, height: 1).fill()
                NSRect(x: c.x + half, y: c.y - 2 + CGFloat(row), width: 1, height: 1).fill()
            }
        }
    }

    /// A pop-up's pushpin, pushed in: its head, and the shadow of its point.
    private func drawPushpin(_ rect: CGRect) {
        let t = theme
        let c = CGPoint(x: rect.midX.rounded(.down), y: rect.midY.rounded(.down))
        t.dark.setFill()
        NSRect(x: c.x - 1, y: c.y + 2, width: 5, height: 1).fill()
        let head = NSBezierPath(ovalIn: NSRect(x: c.x - 4, y: c.y - 4, width: 7, height: 7))
        t.light.setFill()
        head.fill()
        t.border.setStroke()
        head.lineWidth = 1
        head.stroke()
        t.dark.setFill()
        NSRect(x: c.x - 1, y: c.y - 1, width: 2, height: 2).fill()
    }

    private func openLookMouseDown(_ event: NSEvent, at point: CGPoint, in window: ClassicWindow) {
        let layout = openLookLayout
        if layout.button.contains(point) {
            // A pop-up's pushpin, pulled out, puts it away; a window's button opens its menu.
            if layout.hasPushpin { return window.performClose(nil) }
            return showWindowMenu(below: layout.button, in: window)
        }
        if let corner = layout.corner(at: point) {
            let corners: [ClassicWindow.Corner] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
            window.trackResize(from: event, corner: corners[corner])
            return
        }
        if layout.header.contains(point), event.clickCount == 2 {
            window.zoom(nil)
            return
        }
        window.performDrag(with: event)
    }

    /// OPEN LOOK's window menu: Close (to an icon), Full Size, Back, and Quit, which ends it.
    private func showWindowMenu(below rect: CGRect, in window: ClassicWindow) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let isFull = window.frame == (window.screen ?? NSScreen.main)?.visibleFrame
        for (title, action) in [("Close", #selector(NSWindow.miniaturize(_:))),
                                (isFull ? "Restore Size" : "Full Size", #selector(NSWindow.zoom(_:))),
                                ("Back", #selector(NSWindow.orderBack(_:))),
                                ("-", nil), ("Quit", #selector(NSWindow.performClose(_:)))] as [(String, Selector?)] {
            guard let action else {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = window
            menu.addItem(item)
        }
        pressedBox = .systemMenu
        setNeedsDisplay(rect)
        let onScreen = window.convertToScreen(convert(rect, to: nil))
        ClassicMenu.popUp(menu, at: NSPoint(x: onScreen.minX, y: onScreen.minY), theme: theme)
        pressedBox = nil
        setNeedsDisplay(rect)
    }

    // MARK: Mouse

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public override func mouseDown(with event: NSEvent) {
        guard let window = window as? ClassicWindow else { return super.mouseDown(with: event) }
        let point = convert(event.locationInWindow, from: nil)
        switch family {
        case .macintosh: macMouseDown(event, at: point, in: window)
        case .beos: beMouseDown(event, at: point, in: window)
        case .os2: os2MouseDown(event, at: point, in: window)
        case .amiga: amigaMouseDown(event, at: point, in: window)
        case .openLook: openLookMouseDown(event, at: point, in: window)
        }
    }

    private func amigaMouseDown(_ event: NSEvent, at point: CGPoint, in window: ClassicWindow) {
        let layout = amigaLayout
        if layout.closeGadget.contains(point) {
            if track(.close, in: layout.closeGadget) { window.performClose(nil) }
            return
        }
        if let zoom = layout.zoomGadget, zoom.contains(point) {
            if track(.zoom, in: zoom) { window.zoom(nil) }
            return
        }
        if layout.depthGadget.contains(point) {
            // Workbench's depth gadget: the front window goes to the back; one behind comes to the front.
            if track(.collapse, in: layout.depthGadget) {
                if window.isKeyWindow { window.orderBack(nil) } else { window.makeKeyAndOrderFront(nil) }
            }
            return
        }
        if let size = layout.sizeGadget, size.contains(point) {
            window.trackGrow(from: event)
            return
        }
        window.performDrag(with: event)
    }

    private func os2MouseDown(_ event: NSEvent, at point: CGPoint, in window: ClassicWindow) {
        let layout = os2Layout
        if layout.systemMenu.contains(point) {
            // A double-click on the window's icon closes it, as in OS/2.
            if event.clickCount == 2 { return window.performClose(nil) }
            return showSystemMenu(below: layout.systemMenu, in: window)
        }
        if let close = layout.closeButton, close.contains(point) {
            if track(.close, in: close) { window.performClose(nil) }
            return
        }
        if let maximize = layout.maximizeButton, maximize.contains(point) {
            if track(.zoom, in: maximize) { window.zoom(nil) }
            return
        }
        if let hide = layout.hideButton, hide.contains(point) {
            if track(.hide, in: hide) { window.miniaturize(nil) }
            return
        }
        if layout.titleBar.contains(point), event.clickCount == 2 {
            window.zoom(nil)
            return
        }
        window.performDrag(with: event)
    }

    /// The system menu, under the window's icon: what the window can do.
    private func showSystemMenu(below rect: CGRect, in window: ClassicWindow) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (title, action, key) in [("Restore", #selector(NSWindow.zoom(_:)), ""),
                                     ("Hide", #selector(NSWindow.miniaturize(_:)), ""),
                                     ("Maximize", #selector(NSWindow.zoom(_:)), ""),
                                     ("-", nil, ""),
                                     ("Close", #selector(NSWindow.performClose(_:)), "")] as [(String, Selector?, String)] {
            guard let action else {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = window
            menu.addItem(item)
        }
        let isMaximized = window.frame == (window.screen ?? NSScreen.main)?.visibleFrame
        menu.item(withTitle: "Restore")?.isEnabled = isMaximized
        menu.item(withTitle: "Maximize")?.isEnabled = !isMaximized && style == .document
        menu.item(withTitle: "Hide")?.isEnabled = style == .document
        pressedBox = .systemMenu
        setNeedsDisplay(rect)
        let onScreen = window.convertToScreen(convert(rect, to: nil))
        ClassicMenu.popUp(menu, at: NSPoint(x: onScreen.minX, y: onScreen.minY), theme: theme)
        pressedBox = nil
        setNeedsDisplay(rect)
    }

    private func macMouseDown(_ event: NSEvent, at point: CGPoint, in window: ClassicWindow) {
        let layout = macLayout
        if isActive {
            if layout.closeBox.contains(point) {
                if track(.close, in: layout.closeBox) { window.performClose(nil) }
                return
            }
            if let zoom = layout.zoomBox, zoom.contains(point) {
                if track(.zoom, in: zoom) { window.zoom(nil) }
                return
            }
            if layout.collapseBox.contains(point) {
                if track(.collapse, in: layout.collapseBox) { window.toggleCollapsed() }
                return
            }
            if let grow = layout.growBox, grow.contains(point) {
                window.trackGrow(from: event)
                return
            }
        }
        if layout.titleBar.contains(point), event.clickCount == 2 {
            window.toggleCollapsed()
            return
        }
        // Anywhere else on the frame moves the window, as the title bar does.
        window.performDrag(with: event)
    }

    private func beMouseDown(_ event: NSEvent, at point: CGPoint, in window: ClassicWindow) {
        let layout = beLayout
        if let tab = layout.closeBox(at: point) {
            // Each tab's box closes that tab, as each stacked window's does in Haiku; the last one closes the window.
            pressedTab = tab
            defer { pressedTab = nil }
            if track(.close, in: layout.closeBoxes[tab]) {
                if tabTitles.count > 1 { onCloseTab?(tab) } else { window.performClose(nil) }
            }
            return
        }
        if let zoom = layout.zoomBox, zoom.contains(point) {
            if track(.zoom, in: zoom) { window.zoom(nil) }
            return
        }
        if let grow = layout.growBox, grow.contains(point) {
            window.trackGrow(from: event)
            return
        }
        if let tab = layout.tab(at: point) {
            if event.modifierFlags.contains(.shift) {
                trackSlide(from: event)
                return
            }
            if tab != layout.frontTab, tabTitles.count > 1 {
                onSelectTab?(tab)
            } else if event.clickCount == 2 {
                window.toggleCollapsed()
                return
            }
        }
        window.performDrag(with: event)
    }

    /// Shift-dragging a BeOS tab slides the tabs along the top edge, as BeOS allowed.
    private func trackSlide(from event: NSEvent) {
        guard let window else { return }
        let start = convert(event.locationInWindow, from: nil).x
        let startSlide = tabSlide
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let x = convert(next.locationInWindow, from: nil).x
            tabSlide = min(max(0, startSlide + x - start), max(0, bounds.width - beLayout.tabsWidth))
            needsDisplay = true
            if next.type == .leftMouseUp { break }
        }
    }

    /// Holds `box` pressed while the mouse is inside it, as the Toolbox's TrackBox did. True if released inside.
    private func track(_ box: Box, in rect: CGRect) -> Bool {
        guard let window else { return false }
        pressedBox = box
        setNeedsDisplay(rect)
        var inside = true
        while let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            inside = rect.contains(convert(event.locationInWindow, from: nil))
            let next: Box? = inside ? box : nil
            if next != pressedBox {
                pressedBox = next
                setNeedsDisplay(rect)
            }
            if event.type == .leftMouseUp { break }
        }
        pressedBox = nil
        setNeedsDisplay(rect)
        return inside
    }
}

