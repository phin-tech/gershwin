// SwiftUI controls in the Platinum style, the way NeoBrutalism does its own (github.com/rational-kunal/NeoBrutalism):
// the theme rides in the environment, and one root modifier, `.platinum(_:)`, restyles every native Button, Toggle
// and GroupBox beneath it through SwiftUI's own style protocols. A Button is still a Button: same code, same
// accessibility. Controls SwiftUI gives no style protocol for on macOS (Picker, TextField) have Platinum views or
// modifiers of their own here: ClassicRadioGroup and `classicField()`.

import GershwinAppKit
import GershwinChrome
import SwiftUI

public extension EnvironmentValues {
    /// The Platinum theme in this part of the view hierarchy; set it with `.platinum(_:)`.
    @Entry var classicTheme: ClassicTheme = .platinum
}

public extension Color {
    init(_ rgb: RGB) {
        self.init(.sRGB, red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255)
    }
}

public extension View {
    /// Applies the Platinum theme and every Platinum control style to this view tree, and fills it with the theme's
    /// background. Apply it once, at the root of a window's SwiftUI content.
    func gershwin(_ theme: ClassicTheme) -> some View {
        modifier(GershwinRootModifier(theme: theme))
    }

    /// A sunken white text well around a plain `TextField`.
    func classicField() -> some View {
        modifier(ClassicFieldModifier())
    }
}

struct GershwinRootModifier: ViewModifier {
    let theme: ClassicTheme

    func body(content: Content) -> some View {
        content
            .buttonStyle(ClassicButtonStyle())
            .toggleStyle(ClassicCheckboxStyle())
            .groupBoxStyle(ClassicGroupBoxStyle())
            .disclosureGroupStyle(ClassicDisclosureGroupStyle())
            .textFieldStyle(.plain)
            .font(Font(theme.font(size: 12 * theme.scale)))
            .foregroundStyle(Color(theme.palette.text))
            .tint(Color(theme.palette.highlight))
            .environment(\.classicTheme, theme)
            .background {
                if theme.isAqua { AquaPinstripes() } else { Color(theme.palette.background) }
            }
    }
}

// MARK: - Aqua

/// Aqua's pinstripes, behind a window's controls as behind its title.
struct AquaPinstripes: View {
    @Environment(\.classicTheme) private var theme

    var body: some View {
        let p = theme.palette, band = AquaMetrics.pinstripe * theme.scale
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(p.background)))
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: band)),
                             with: .color(Color(p.light).opacity(0.6)))
                y += band * 2
            }
        }
        .allowsHitTesting(false)
    }
}

/// Gel in `shape`: lighter at the top, the colour through the middle, glowing at the bottom, a gloss over its upper
/// half and an edge of the colour, darker (GershwinAppKit's `drawGel`, for SwiftUI).
struct AquaGel<S: InsettableShape>: View {
    let shape: S
    var color: Color
    var pressed = false

    var body: some View {
        let base = pressed ? color.mix(with: .black, by: 0.25) : color
        GeometryReader { geometry in
            let h = geometry.size.height
            ZStack(alignment: .top) {
                shape.fill(LinearGradient(stops: [
                    .init(color: base.mix(with: .white, by: 0.45), location: 0), .init(color: base, location: 0.5),
                    .init(color: base, location: 0.75), .init(color: base.mix(with: .white, by: 0.35), location: 1),
                ], startPoint: .top, endPoint: .bottom))
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.15)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: geometry.size.width * 0.8, height: h * 0.45)
                    .padding(.top, 1)
                    .clipShape(shape)
                shape.strokeBorder(base.mix(with: .black, by: 0.45).opacity(0.8), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Aqua's white gel, for a button that isn't the default.
let aquaWhite = Color(white: 0.9)

private extension Color {
    func mix(with other: Color, by fraction: Double) -> Color {
        Color(NSColor(self).blended(withFraction: fraction, of: NSColor(other)) ?? NSColor(self))
    }
}

// Every size below is in Mac OS 9 pixels, times the theme's scale (`s`), as the windows' chrome is.

/// A raised edge: light along the top and left, dark along the bottom and right, one pixel (`unit` points) wide.
struct Bevel: View {
    var light: Color
    var dark: Color
    var unit: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height, u = unit
            context.fill(Path(CGRect(x: 0, y: 0, width: w - u, height: u)), with: .color(light))
            context.fill(Path(CGRect(x: 0, y: 0, width: u, height: h - u)), with: .color(light))
            context.fill(Path(CGRect(x: u, y: h - u, width: w - u, height: u)), with: .color(dark))
            context.fill(Path(CGRect(x: w - u, y: u, width: u, height: h - u)), with: .color(dark))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Button

/// A Platinum push button: a rounded, outlined, bevelled face that sinks and darkens while pressed. A
/// `.classicDefault()` button also gets the thick black ring of the button Return presses.
public struct ClassicButtonStyle: ButtonStyle {
    @Environment(\.classicTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.classicDefaultButton) private var isDefault

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let p = theme.palette, s = theme.scale
        let pressed = configuration.isPressed
        if theme.isAqua {
            // A capsule of white gel, or the default button's blue; no ring.
            return AnyView(configuration.label
                .foregroundStyle(Color(isEnabled ? p.text : p.disabledText))
                .padding(.horizontal, 14 * s)
                .frame(minWidth: 58 * s, minHeight: 20 * s)
                .background(AquaGel(shape: Capsule(), color: isDefault ? Color(p.thumb) : aquaWhite, pressed: pressed)
                    .opacity(isEnabled ? 1 : 0.6))
                .contentShape(Rectangle()))
        }
        let shape = RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
        return AnyView(configuration.label
            .foregroundStyle(Color(isEnabled ? p.text : p.disabledText))
            .padding(.horizontal, 14 * s)
            .frame(minWidth: 58 * s, minHeight: 20 * s)
            .background(shape.fill(Color(pressed ? p.well : p.background)))
            .overlay(
                shape.inset(by: 1.5 * s).stroke(
                    LinearGradient(colors: pressed ? [Color(p.dark), Color(p.light)] : [Color(p.light), Color(p.dark)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: s))
            .overlay(shape.strokeBorder(Color(isEnabled ? p.border : p.disabledText), lineWidth: s))
            .padding(isDefault ? 4 * s : 0)
            .overlay {
                if isDefault {
                    RoundedRectangle(cornerRadius: 7 * s, style: .continuous)
                        .strokeBorder(Color(p.border), lineWidth: 3 * s)
                }
            }
            .contentShape(Rectangle()))
    }
}

public extension EnvironmentValues {
    @Entry var classicDefaultButton: Bool = false
}

public extension View {
    /// Marks a button as the default one: Return presses it, and it gets Platinum's thick ring.
    func classicDefault() -> some View {
        environment(\.classicDefaultButton, true).keyboardShortcut(.defaultAction)
    }
}

// MARK: - Checkbox

/// A Platinum checkbox: a small sunken white square with a check in it when on.
public struct ClassicCheckboxStyle: ToggleStyle {
    @Environment(\.classicTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let p = theme.palette, s = theme.scale
        return Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 6 * s) {
                ZStack {
                    if theme.isAqua {
                        // Aqua's: a rounded square of gel, blue when checked.
                        AquaGel(shape: RoundedRectangle(cornerRadius: 3 * s),
                                color: configuration.isOn ? Color(p.thumb) : aquaWhite)
                    } else {
                        Rectangle().fill(Color(p.light))
                        Rectangle().strokeBorder(Color(isEnabled ? p.border : p.disabledText), lineWidth: s)
                        Bevel(light: Color(p.dark), dark: Color(p.background), unit: s).padding(s)
                    }
                    if configuration.isOn {
                        CheckMark()
                            .stroke(Color(isEnabled ? p.border : p.disabledText),
                                    style: StrokeStyle(lineWidth: 2 * s, lineCap: .square, lineJoin: .miter))
                            .padding(3 * s)
                    }
                }
                .frame(width: 12 * s, height: 12 * s)
                configuration.label
                    .foregroundStyle(Color(isEnabled ? p.text : p.disabledText))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "on" : "off")
    }
}

struct CheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - Radio buttons

/// Platinum radio buttons for choosing one of a few values, in place of a Picker (which SwiftUI won't let be styled).
public struct ClassicRadioGroup<Value: Hashable>: View {
    @Environment(\.classicTheme) private var theme
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    public init(selection: Binding<Value>, options: [(value: Value, label: String)]) {
        _selection = selection
        self.options = options
    }

    public var body: some View {
        let p = theme.palette, s = theme.scale
        VStack(alignment: .leading, spacing: 6 * s) {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    HStack(spacing: 6 * s) {
                        ZStack {
                            if theme.isAqua {
                                // Aqua's: a bead of gel, blue when chosen, with a dark dot.
                                AquaGel(shape: Circle(), color: selection == option.value ? Color(p.thumb) : aquaWhite)
                            } else {
                                Circle().fill(Color(p.light))
                                Circle().strokeBorder(Color(p.border), lineWidth: s)
                                Circle().trim(from: 0.375, to: 0.875).stroke(Color(p.dark), lineWidth: s)
                                    .padding(1.5 * s)
                            }
                            if selection == option.value {
                                Circle().fill(Color(p.border)).padding(3.5 * s)
                            }
                        }
                        .frame(width: 12 * s, height: 12 * s)
                        Text(option.label)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
    }
}

// MARK: - Group box

/// A Platinum group box: an etched frame with its title set into the top edge.
public struct ClassicGroupBoxStyle: GroupBoxStyle {
    @Environment(\.classicTheme) private var theme

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let p = theme.palette, s = theme.scale
        if theme.isAqua {
            // Aqua's: a faintly darker rounded box, its title above it rather than in its edge.
            return AnyView(VStack(alignment: .leading, spacing: 4 * s) {
                configuration.label
                configuration.content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10 * s)
                    .background(RoundedRectangle(cornerRadius: 5 * s).fill(Color.black.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 5 * s).strokeBorder(Color.black.opacity(0.2), lineWidth: s))
            })
        }
        return AnyView(configuration.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12 * s)
            .padding(.top, 16 * s)
            .padding(.bottom, 12 * s)
            .overlay(
                ZStack {
                    Rectangle().inset(by: s).stroke(Color(p.light), lineWidth: s).offset(x: s, y: s)
                    Rectangle().inset(by: s / 2).stroke(Color(p.dark), lineWidth: s)
                }
                .padding(.top, 7 * s))
            .overlay(alignment: .topLeading) {
                configuration.label
                    .padding(.horizontal, 4 * s)
                    .background(Color(p.background))
                    .padding(.leading, 8 * s)
            })
    }
}

// MARK: - Text field

struct ClassicFieldModifier: ViewModifier {
    @Environment(\.classicTheme) private var theme

    func body(content: Content) -> some View {
        let p = theme.palette, s = theme.scale
        if theme.isAqua {
            // Aqua's: white, a thin grey edge, a shadow along the top inside it.
            return AnyView(content
                .font(Font(theme.font(size: 12 * s)))
                .foregroundStyle(Color(p.contentText))
                .padding(.horizontal, 4 * s)
                .padding(.vertical, 3 * s)
                .background(Color(p.content))
                .overlay(alignment: .top) { Rectangle().fill(Color.black.opacity(0.25)).frame(height: s) }
                .overlay(Rectangle().strokeBorder(Color(p.dark), lineWidth: s)))
        }
        return AnyView(content
            .font(Font(ClassicTheme.smallFont(size: 12 * s)))
            .foregroundStyle(Color(p.contentText))
            .padding(.horizontal, 4 * s)
            .padding(.vertical, 3 * s)
            .background(Color(p.content))
            .overlay(Rectangle().strokeBorder(Color(p.border), lineWidth: s))
            .overlay(Bevel(light: Color(p.dark), dark: Color(p.light), unit: s).padding(-s)))
    }
}
