import GershwinAppKit
import GershwinChrome
import SwiftUI

public extension View {
    /// A dialog over this view while `isPresented`, in the theme's style: Aqua's hangs from the top of the window as
    /// a sheet did, the others sit a third of the way down as the Dialog Manager put them. Clicks and keys do not
    /// reach what's beneath it, so it is modal. Esc closes it unless `dismissesOnEscape` is false (a text field in
    /// the dialog keeps Esc for itself, to cancel its own editing); `content` should still give a button for it.
    func classicSheet<Sheet: View>(isPresented: Binding<Bool>, dismissesOnEscape: Bool = true,
                                   @ViewBuilder content: @escaping () -> Sheet) -> some View {
        modifier(ClassicSheetModifier(isPresented: isPresented, dismissesOnEscape: dismissesOnEscape, sheet: content))
    }

    /// A small panel hanging below this view while `isPresented`, in the theme's style: a pop-up's worth of choices,
    /// a colour palette. It doesn't block what's beneath; Esc closes it, and the owner closes it on a choice.
    func classicPopover<Popover: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Popover)
        -> some View {
        modifier(ClassicPopoverModifier(isPresented: isPresented, popover: content))
    }
}

private struct ClassicSheetModifier<Sheet: View>: ViewModifier {
    @Environment(\.classicTheme) private var theme
    @Binding var isPresented: Bool
    let dismissesOnEscape: Bool
    let sheet: () -> Sheet
    @FocusState private var hasFocus: Bool

    func body(content: Content) -> some View {
        content
            .disabled(isPresented)
            .overlay {
                if isPresented { panel }
            }
    }

    private var panel: some View {
        let s = theme.scale
        return GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Takes the clicks the dialog doesn't.
                Color.clear.contentShape(Rectangle()).onTapGesture {}
                SheetFrame { sheet() }
                    .padding(.top, theme.isAqua ? 0 : geometry.size.height / 3 - 40 * s)
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($hasFocus)
        .onAppear { hasFocus = true }
        .onKeyPress(.escape) {
            guard dismissesOnEscape else { return .ignored }
            isPresented = false
            return .handled
        }
        .accessibilityAddTraits(.isModal)
    }
}

private struct SheetFrame<Content: View>: View {
    @Environment(\.classicTheme) private var theme
    let content: Content
    let margin: CGFloat

    init(margin: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.margin = margin
        self.content = content()
    }

    var body: some View {
        let p = theme.palette, s = theme.scale
        content
            .padding(margin * s)
            .background {
                if theme.isAqua { AquaPinstripes() } else { Color(p.background) }
            }
            .overlay {
                switch Family(theme.chrome) {
                case .platinum, .beos:
                    ZStack {
                        Rectangle().strokeBorder(Color(p.border), lineWidth: s)
                        Bevel(light: Color(p.light), dark: Color(p.dark), unit: s).padding(s)
                    }
                case .classic:
                    // System 1 to 7's modal dialog: a double border.
                    ZStack {
                        Rectangle().strokeBorder(Color(p.border), lineWidth: s)
                        Rectangle().strokeBorder(Color(p.border), lineWidth: s).padding(3 * s)
                    }
                case .aqua:
                    UnevenRoundedRectangle(bottomLeadingRadius: 6 * s, bottomTrailingRadius: 6 * s)
                        .strokeBorder(Color(p.border), lineWidth: s)
                }
            }
            .compositingGroup()
            .shadow(color: .black.opacity(theme.isAqua ? 0.4 : 0.3), radius: theme.isAqua ? 8 * s : 0,
                    x: theme.isAqua ? 0 : 2 * s, y: theme.isAqua ? 3 * s : 2 * s)
    }
}

private struct ClassicPopoverModifier<Popover: View>: ViewModifier {
    @Binding var isPresented: Bool
    let popover: () -> Popover
    @FocusState private var hasFocus: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomLeading) {
            if isPresented {
                // Its top edge on this view's bottom edge, drawn over what's below.
                SheetFrame(margin: 6) { popover() }
                    .fixedSize()
                    .alignmentGuide(.bottom) { $0[.top] }
                    .focusable()
                    .focusEffectDisabled()
                    .focused($hasFocus)
                    .onAppear { hasFocus = true }
                    .onKeyPress(.escape) {
                        isPresented = false
                        return .handled
                    }
                    .zIndex(1)
            }
        }
    }
}
