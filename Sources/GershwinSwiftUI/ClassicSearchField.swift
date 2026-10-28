// Fields built on ClassicField: a search field (a magnifier at the left, a clear button at the right), a password
// field, and a combo box (a field with a menu of ready answers).

import AppKit
import GershwinAppKit
import GershwinChrome
import SwiftUI

// MARK: - Search

/// An edit-text field for searching: a magnifying glass at its left, and once there is text, a button at its right
/// that clears it. Esc clears it too.
public struct ClassicSearchField: View {
    @Environment(\.classicTheme) private var theme
    @Binding var text: String
    let prompt: String
    let onSubmit: (() -> Void)?

    public init(_ prompt: String = "Search", text: Binding<String>, onSubmit: (() -> Void)? = nil) {
        self.prompt = prompt
        _text = text
        self.onSubmit = onSubmit
    }

    public var body: some View {
        let s = theme.scale
        ClassicField(prompt, text: $text, leadingInset: 14, trailingInset: 14,
                     onSubmit: onSubmit.map { action in { _ in action() } }, onCancel: { text = "" })
            .overlay(alignment: .leading) {
                Magnifier().frame(width: 10 * s, height: 10 * s).padding(.leading, 7 * s).allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                if !text.isEmpty {
                    Button { text = "" } label: {
                        ClearGlyph().frame(width: 10 * s, height: 10 * s).frame(width: 16 * s, height: 18 * s)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 5 * s)
                    .accessibilityLabel("Clear")
                }
            }
    }
}

private struct Magnifier: View {
    @Environment(\.classicTheme) private var theme

    var body: some View {
        let p = theme.palette, s = theme.scale
        Canvas { context, size in
            let r = size.width * 0.38
            let lens = CGRect(x: s / 2, y: s / 2, width: r * 2, height: r * 2)
            context.stroke(Path(ellipseIn: lens), with: .color(Color(p.contentText)), lineWidth: 1.5 * s)
            var handle = Path()
            handle.move(to: CGPoint(x: lens.maxX - r * 0.3, y: lens.maxY - r * 0.3))
            handle.addLine(to: CGPoint(x: size.width - s, y: size.height - s))
            context.stroke(handle, with: .color(Color(p.contentText)), style: StrokeStyle(lineWidth: 2 * s, lineCap: .square))
        }
    }
}

private struct ClearGlyph: View {
    @Environment(\.classicTheme) private var theme

    var body: some View {
        let p = theme.palette, s = theme.scale
        Canvas { context, size in
            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .color(Color(p.dark)))
            var cross = Path()
            let inset = size.width * 0.3
            cross.move(to: CGPoint(x: inset, y: inset))
            cross.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
            cross.move(to: CGPoint(x: size.width - inset, y: inset))
            cross.addLine(to: CGPoint(x: inset, y: size.height - inset))
            context.stroke(cross, with: .color(Color(p.content)), lineWidth: 1.5 * s)
        }
    }
}

// MARK: - Password

/// An edit-text field that shows bullets for what's typed, with the same focus ring as ClassicField.
public struct ClassicSecureField: View {
    @Binding var text: String
    let placeholder: String?
    let onSubmit: (() -> Void)?

    public init(_ placeholder: String? = nil, text: Binding<String>, onSubmit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        _text = text
        self.onSubmit = onSubmit
    }

    public var body: some View {
        ClassicField(placeholder, text: $text, isSecure: true, onSubmit: onSubmit.map { action in { _ in action() } })
    }
}

// MARK: - Combo box

/// An edit-text field with a button at its right that opens a menu of ready answers; choosing one fills the field.
/// What's typed need not be one of them.
public struct ClassicComboBox: View {
    @Environment(\.classicTheme) private var theme
    @Binding var text: String
    let placeholder: String?
    let options: [String]

    public init(_ placeholder: String? = nil, text: Binding<String>, options: [String]) {
        self.placeholder = placeholder
        _text = text
        self.options = options
    }

    public var body: some View {
        let s = theme.scale
        ClassicField(placeholder, text: $text, trailingInset: 14)
            .overlay(alignment: .trailing) {
                Button(action: showMenu) {
                    ArrowGlyph().frame(width: 8 * s, height: 5 * s).frame(width: 16 * s, height: 18 * s)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 5 * s)
                .disabled(options.isEmpty)
                .accessibilityLabel("Show choices")
            }
    }

    private func showMenu() {
        let items = options.map { option in
            ClassicMenuItem(option, isChecked: option == text) { text = option }
        }
        ClassicMenuItem.popUp(items, theme: theme)
    }
}

private struct ArrowGlyph: View {
    @Environment(\.classicTheme) private var theme

    var body: some View {
        let p = theme.palette
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            path.closeSubpath()
            context.fill(path, with: .color(Color(p.contentText)))
        }
    }
}
