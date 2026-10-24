// The smaller classic controls, for SwiftUI: disclosure triangles (restyling SwiftUI's own DisclosureGroup, applied by
// `.gershwin()`), the Mac OS 8 slider with its pointed thumb, the "little arrows" stepper, and the bevel button. Each
// draws in its theme's family: Platinum's greys and bevels, System 7's black and white, BeOS's flat greys and blue.
// Sizes are Mac OS 9 pixels times the theme's scale.

import GershwinAppKit
import GershwinChrome
import SwiftUI

private enum Family {
    case platinum, classic, beos

    init(_ chrome: ChromeTheme) {
        switch (chrome.family, chrome.tabStyle) {
        case (.beos, _): self = .beos
        case (_, .folder): self = .classic
        default: self = .platinum
        }
    }
}

/// BeOS's blue, for the parts of its controls that show a value.
private let beosBlue = Color(.sRGB, red: 0.31, green: 0.5, blue: 0.85)

// MARK: - Disclosure triangle

/// A DisclosureGroup as a disclosure triangle: pointing right when closed, down when open, its label beside it.
public struct ClassicDisclosureGroupStyle: DisclosureGroupStyle {
    @Environment(\.classicTheme) private var theme

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let s = theme.scale
        return VStack(alignment: .leading, spacing: 6 * s) {
            Button {
                withAnimation(nil) { configuration.isExpanded.toggle() }
            } label: {
                HStack(spacing: 6 * s) {
                    DisclosureTriangle(isExpanded: configuration.isExpanded)
                        .frame(width: 10 * s, height: 10 * s)
                    configuration.label
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "expanded" : "collapsed")
            if configuration.isExpanded {
                configuration.content.padding(.leading, 16 * s)
            }
        }
    }
}

struct DisclosureTriangle: View {
    @Environment(\.classicTheme) private var theme
    var isExpanded: Bool

    var body: some View {
        let p = theme.palette, s = theme.scale
        let family = Family(theme.chrome)
        Canvas { context, size in
            var path = Path()
            if isExpanded {
                path.move(to: CGPoint(x: 0, y: size.height * 0.2))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.2))
                path.addLine(to: CGPoint(x: size.width / 2, y: size.height * 0.95))
            } else {
                path.move(to: CGPoint(x: size.width * 0.2, y: 0))
                path.addLine(to: CGPoint(x: size.width * 0.95, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width * 0.2, y: size.height))
            }
            path.closeSubpath()
            switch family {
            case .platinum:
                // Mac OS 8: a grey triangle outlined in black.
                context.fill(path, with: .color(Color(p.dark)))
                context.stroke(path, with: .color(Color(p.border)), lineWidth: s)
            case .classic:
                context.fill(path, with: .color(Color(p.border)))
            case .beos:
                context.stroke(path, with: .color(Color(p.text)), lineWidth: s)
            }
        }
    }
}

// MARK: - Slider

/// A horizontal slider: a groove and a thumb that points down at it (Mac OS 8 and 9), a plain one (System 7), or a
/// blue-filled track with a triangle (BeOS). Click or drag anywhere on it.
public struct ClassicSlider: View {
    @Environment(\.classicTheme) private var theme
    @Binding var value: Double
    let range: ClosedRange<Double>

    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...1) {
        _value = value
        self.range = range
    }

    public var body: some View {
        let s = theme.scale
        GeometryReader { geometry in
            let thumbWidth = 11 * s
            let travel = max(1, geometry.size.width - thumbWidth)
            let fraction = (value - range.lowerBound) / max(range.upperBound - range.lowerBound, .ulpOfOne)
            ZStack(alignment: .leading) {
                SliderTrack(fraction: fraction, thumbWidth: thumbWidth)
                SliderThumb()
                    .frame(width: thumbWidth, height: 16 * s)
                    .offset(x: travel * fraction)
            }
            .frame(height: 16 * s)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let f = min(max((drag.location.x - thumbWidth / 2) / travel, 0), 1)
                value = range.lowerBound + f * (range.upperBound - range.lowerBound)
            })
        }
        .frame(height: 16 * s)
        .accessibilityElement()
        .accessibilityValue("\(Int(value.rounded()))")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 10
            value = min(max(value + (direction == .increment ? step : -step), range.lowerBound), range.upperBound)
        }
    }
}

private struct SliderTrack: View {
    @Environment(\.classicTheme) private var theme
    let fraction: Double
    let thumbWidth: CGFloat

    var body: some View {
        let p = theme.palette, s = theme.scale
        let family = Family(theme.chrome)
        GeometryReader { geometry in
            let groove = CGRect(x: thumbWidth / 2, y: 6 * s, width: geometry.size.width - thumbWidth, height: 4 * s)
            ZStack(alignment: .topLeading) {
                switch family {
                case .platinum:
                    Rectangle().fill(Color(p.well)).frame(width: groove.width, height: groove.height)
                        .overlay(Bevel(light: Color(p.dark), dark: Color(p.light), unit: s))
                        .offset(x: groove.minX, y: groove.minY)
                case .classic:
                    Rectangle().strokeBorder(Color(p.border), lineWidth: s)
                        .frame(width: groove.width, height: groove.height).offset(x: groove.minX, y: groove.minY)
                case .beos:
                    Rectangle().fill(Color(p.well)).frame(width: groove.width, height: groove.height)
                        .offset(x: groove.minX, y: groove.minY)
                    Rectangle().fill(beosBlue).frame(width: groove.width * fraction, height: groove.height)
                        .offset(x: groove.minX, y: groove.minY)
                }
            }
        }
    }
}

private struct SliderThumb: View {
    @Environment(\.classicTheme) private var theme

    var body: some View {
        let p = theme.palette, s = theme.scale
        let family = Family(theme.chrome)
        Canvas { context, size in
            var path = Path()
            switch family {
            case .platinum, .beos:
                // A pentagon pointing down (Mac OS 8), or BeOS's triangle.
                if family == .platinum {
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: size.width, y: 0))
                    path.addLine(to: CGPoint(x: size.width, y: size.height * 0.6))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height * 0.6))
                } else {
                    path.move(to: CGPoint(x: size.width / 2, y: size.height * 0.35))
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                }
                path.closeSubpath()
                context.fill(path, with: .color(Color(family == .platinum ? p.thumb : p.background)))
                context.stroke(path, with: .color(Color(p.border)), lineWidth: s)
            case .classic:
                path.addRect(CGRect(origin: .zero, size: size).insetBy(dx: s / 2, dy: s / 2))
                context.fill(path, with: .color(Color(p.light)))
                context.stroke(path, with: .color(Color(p.border)), lineWidth: s)
            }
        }
    }
}

// MARK: - Little arrows

/// The "little arrows": a small up-and-down pair that steps a number, beside the field that shows it.
public struct ClassicLittleArrows: View {
    @Environment(\.classicTheme) private var theme
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    public init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 1) {
        _value = value
        self.range = range
        self.step = step
    }

    public var body: some View {
        let p = theme.palette, s = theme.scale
        VStack(spacing: 0) {
            arrow(up: true) { value = min(value + step, range.upperBound) }
            Rectangle().fill(Color(p.border)).frame(height: s)
            arrow(up: false) { value = max(value - step, range.lowerBound) }
        }
        .frame(width: 13 * s, height: 23 * s)
        .overlay(Rectangle().strokeBorder(Color(p.border), lineWidth: s))
        .accessibilityElement()
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            value = direction == .increment ? min(value + step, range.upperBound) : max(value - step, range.lowerBound)
        }
    }

    private func arrow(up: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LittleArrow(up: up).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(LittleArrowStyle())
    }
}

private struct LittleArrow: View {
    @Environment(\.classicTheme) private var theme
    let up: Bool

    var body: some View {
        let s = theme.scale
        Canvas { context, size in
            var path = Path()
            let w = 5 * s, h = 3 * s
            let x = (size.width - w) / 2, y = (size.height - h) / 2
            if up {
                path.move(to: CGPoint(x: x, y: y + h))
                path.addLine(to: CGPoint(x: x + w / 2, y: y))
                path.addLine(to: CGPoint(x: x + w, y: y + h))
            } else {
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + w / 2, y: y + h))
                path.addLine(to: CGPoint(x: x + w, y: y))
            }
            path.closeSubpath()
            context.fill(path, with: .foreground)
        }
    }
}

private struct LittleArrowStyle: ButtonStyle {
    @Environment(\.classicTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        let p = theme.palette
        let family = Family(theme.chrome)
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(Color(pressed && family == .classic ? p.light : p.text))
            .background(Color(pressed ? (family == .classic ? p.border : p.well) : p.background))
            .overlay {
                if family != .classic {
                    Bevel(light: Color(pressed ? p.dark : p.light), dark: Color(pressed ? p.light : p.dark),
                          unit: theme.scale).padding(theme.scale)
                }
            }
    }
}

// MARK: - Bevel button

/// Mac OS 8's bevel button: square-cornered, a deeper bevel than a push button, for tool-like choices; sunken while
/// pressed, and while `isOn` for one that stays down.
public struct ClassicBevelButtonStyle: ButtonStyle {
    @Environment(\.classicTheme) private var theme
    var isOn: Bool

    public init(isOn: Bool = false) {
        self.isOn = isOn
    }

    public func makeBody(configuration: Configuration) -> some View {
        let p = theme.palette, s = theme.scale
        let family = Family(theme.chrome)
        let down = configuration.isPressed || isOn
        return configuration.label
            .foregroundStyle(Color(down && family == .classic ? p.light : p.text))
            .padding(.horizontal, 10 * s)
            .frame(minWidth: 24 * s, minHeight: 24 * s)
            .background(Color(down ? (family == .classic ? p.border : p.well) : p.background))
            .overlay {
                if family != .classic {
                    ZStack {
                        Bevel(light: Color(down ? p.dark : p.light), dark: Color(down ? p.light : p.dark), unit: s)
                            .padding(s)
                        Bevel(light: Color(down ? p.dark : p.light), dark: Color(down ? p.light : p.dark), unit: s)
                            .padding(2 * s)
                    }
                }
            }
            .overlay(Rectangle().strokeBorder(Color(p.border), lineWidth: s))
            .contentShape(Rectangle())
    }
}
