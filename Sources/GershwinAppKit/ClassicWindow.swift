import AppKit
import GershwinChrome

/// Whatever owns a tabbed window's tabs. File ▸ Close Tab asks it to close the front one; a window without it closes.
@MainActor
public protocol ClassicTabDelegate: AnyObject {
    func closeFrontTab(of window: ClassicWindow)
}

/// A window drawn in its appearance's own shape (FanfareKit's ChromeFamily): the classic Mac's, square and outlined
/// in black under a pinstriped title bar with a close box on the left and zoom and collapse boxes on the right; or
/// BeOS's, a grey frame under a yellow title tab. It is borderless, so macOS draws none of its own frame; everything is
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
        let opaque = theme.chrome.family == .macintosh
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
        let start = NSEvent.mouseLocation
        let startFrame = frame
        let outline = ResizeOutline(frame: startFrame, theme: theme, style: frameView.style)
        outline.orderFront(nil)
        defer { outline.orderOut(nil) }
        var proposed = startFrame
        while let next = nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let now = NSEvent.mouseLocation
            let width = max(minSize.width, startFrame.width + (now.x - start.x))
            let height = max(minSize.height, startFrame.height - (now.y - start.y))
            proposed = NSRect(x: startFrame.minX, y: startFrame.maxY - height, width: width, height: height)
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
            let top = (theme.chrome.family == .beos ? BeOSMetrics.tabHeight(for: style) : style.collapsedHeight)
                * theme.scale
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
        family == .macintosh ? macLayout.main : beLayout.main
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
        let main = family == .macintosh
            ? WindowChromeLayout(bounds: big, style: style, showsTabBar: showsTabBar).main
            : BeOSChromeLayout(bounds: big, style: style, titleWidths: [0]).main
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
            scrollBar?.isHidden = isCollapsed
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

    private enum Box { case close, zoom, collapse }

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
    public override var isOpaque: Bool { family == .macintosh }

    private var family: ChromeFamily { theme.chrome.family }

    /// Draws the window as frontmost whatever its state, for tests and the debug driver's snapshots, which look at a
    /// copy of the app running in the background.
    public var drawsAsActive = false {
        didSet { activeStateChanged() }
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
        (family == .beos ? BeOSMetrics.tabHeight(for: style) : style.collapsedHeight) * theme.scale
    }

    // MARK: Tabs

    /// The Mac family's tab bar shows from two tabs; BeOS's tabs are in its title row.
    var showsTabBar: Bool { family == .macintosh && tabTitles.count > 1 }

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
        guard style == .utility else { return theme.font(size: 12) }
        return family == .beos ? theme.font(size: 10) : ClassicTheme.smallFont(size: 9)
    }

    private var macLayout: WindowChromeLayout {
        WindowChromeLayout(bounds: bounds, style: style, isCollapsed: isCollapsed, showsTabBar: showsTabBar)
    }

    /// The titles a BeOS window's tabs show: the tabs', or with one tab the window's own.
    private var beTitles: [String] {
        tabTitles.count > 1 ? tabTitles : [window?.title ?? ""]
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
        }
        if let grow = family == .macintosh ? macLayout.growBox : beLayout.growBox { drawGrowBox(grow) }
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
        case .close:
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

    // MARK: Mouse

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public override func mouseDown(with event: NSEvent) {
        guard let window = window as? ClassicWindow else { return super.mouseDown(with: event) }
        let point = convert(event.locationInWindow, from: nil)
        switch family {
        case .macintosh: macMouseDown(event, at: point, in: window)
        case .beos: beMouseDown(event, at: point, in: window)
        }
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
