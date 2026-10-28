// For SwiftUI: an edit-text field with the era's focus ring (ClassicTextField), and Mac OS 8's tab control, a row of
// tabs over a panel showing the chosen tab's page (ClassicTabBar's tabs).

import AppKit
import GershwinAppKit
import GershwinChrome
import SwiftUI

// MARK: - Field

/// An edit-text field in the theme's style, with the keyboard focus shown as its era showed it (ClassicTextField).
/// SwiftUI's TextField draws macOS's own focus ring, which `.classicField()` can't take off.
public struct ClassicField: NSViewRepresentable {
    @Environment(\.classicTheme) private var theme
    @Binding var text: String
    let placeholder: String?
    let focusesOnAppear: Bool
    let onSubmit: ((_ shift: Bool) -> Void)?
    let onCancel: (() -> Void)?
    let isSecure: Bool
    let leadingInset: CGFloat
    let trailingInset: CGFloat

    /// `onSubmit` is Return (and whether shift was down), `onCancel` Esc; without them, they do what they would.
    /// `isSecure` shows bullets for what's typed. The insets leave room inside the box for a glyph drawn over it.
    public init(_ placeholder: String? = nil, text: Binding<String>, focusesOnAppear: Bool = false,
                isSecure: Bool = false, leadingInset: CGFloat = 0, trailingInset: CGFloat = 0,
                onSubmit: ((_ shift: Bool) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.isSecure = isSecure
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
        _text = text
        self.placeholder = placeholder
        self.focusesOnAppear = focusesOnAppear
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public func makeNSView(context: Context) -> ClassicTextField {
        let field = ClassicTextField(theme: theme, isSecure: isSecure)
        field.focusesOnAppear = focusesOnAppear
        field.setContentHuggingPriority(.required, for: .vertical)
        return field
    }

    public func updateNSView(_ field: ClassicTextField, context: Context) {
        if field.theme != theme { field.theme = theme }
        field.leadingInset = leadingInset
        field.trailingInset = trailingInset
        if field.placeholder != placeholder { field.placeholder = placeholder }
        field.stringValue = text
        let binding = $text
        field.onChange = { binding.wrappedValue = $0 }
        field.onSubmit = onSubmit
        field.onCancel = onCancel
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView field: ClassicTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 200 * theme.scale, height: field.intrinsicContentSize.height)
    }
}

// MARK: - Tabs

/// Mac OS 8's tab control: a row of tabs (or System 7's folder tabs) over a raised panel, the chosen tab joined to it.
/// `content` is the chosen tab's page; switch on `selection` to give it.
public struct ClassicTabView<Content: View>: View {
    @Environment(\.classicTheme) private var theme
    @Binding var selection: Int
    let titles: [String]
    let content: Content

    public init(selection: Binding<Int>, titles: [String], @ViewBuilder content: () -> Content) {
        _selection = selection
        self.titles = titles
        self.content = content()
    }

    public var body: some View {
        let s = theme.scale
        VStack(spacing: 0) {
            TabStrip(selection: $selection, titles: titles)
                .frame(height: ChromeMetrics.tabBarHeight * s)
            content
                .padding(12 * s)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Color(theme.palette.background))
                .overlay(PanelEdge())
        }
    }
}

private struct TabStrip: NSViewRepresentable {
    @Environment(\.classicTheme) private var theme
    @Binding var selection: Int
    let titles: [String]

    func makeNSView(context: Context) -> ClassicTabBar {
        let bar = ClassicTabBar(theme: theme)
        bar.opensOntoPanel = true
        return bar
    }

    func updateNSView(_ bar: ClassicTabBar, context: Context) {
        if bar.theme != theme {
            bar.theme = theme
            bar.needsLayout = true
        }
        bar.titles = titles
        bar.selectedIndex = selection
        let binding = $selection
        bar.onSelect = { binding.wrappedValue = $0 }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView bar: ClassicTabBar, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 300 * theme.scale, height: ChromeMetrics.tabBarHeight * theme.scale)
    }
}

/// The panel's outline down its sides and along its bottom (the tabs draw its top), with a raised bevel inside.
private struct PanelEdge: View {
    @Environment(\.classicTheme) private var theme

    var body: some View {
        let p = theme.palette, u = theme.scale
        Canvas { context, size in
            let w = size.width, h = size.height
            let border = Color(p.border), light = Color(p.light), dark = Color(p.dark)
            context.fill(Path(CGRect(x: 0, y: 0, width: u, height: h)), with: .color(border))
            context.fill(Path(CGRect(x: w - u, y: 0, width: u, height: h)), with: .color(border))
            context.fill(Path(CGRect(x: 0, y: h - u, width: w, height: u)), with: .color(border))
            context.fill(Path(CGRect(x: u, y: 0, width: u, height: h - 2 * u)), with: .color(light))
            context.fill(Path(CGRect(x: w - 2 * u, y: 0, width: u, height: h - 2 * u)), with: .color(dark))
            context.fill(Path(CGRect(x: 2 * u, y: h - 2 * u, width: w - 4 * u, height: u)), with: .color(dark))
        }
        .allowsHitTesting(false)
    }
}
