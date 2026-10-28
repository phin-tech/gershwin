import GershwinAppKit
import GershwinChrome
import SwiftUI

/// Mac OS 8's date field: month, day and year in a sunken box, one of them chosen by a click, and the little arrows
/// beside it stepping the chosen one. ↑ and ↓ step it too, ← and → choose another.
public struct ClassicDatePicker: View {
    @Environment(\.classicTheme) private var theme
    @FocusState private var isFocused: Bool
    @Binding var date: Date
    let calendar: Calendar
    @State private var part = Part.month

    enum Part: CaseIterable { case month, day, year }

    public init(date: Binding<Date>, calendar: Calendar = .current) {
        _date = date
        self.calendar = calendar
    }

    /// `date` moved by `delta` of one of its parts; a day past the month's end carries into the next, as the
    /// calendar has it.
    static func adding(_ delta: Int, to part: Part, of date: Date, calendar: Calendar) -> Date {
        let component: Calendar.Component = switch part {
        case .month: .month
        case .day: .day
        case .year: .year
        }
        return calendar.date(byAdding: component, value: delta, to: date) ?? date
    }

    private func text(_ part: Part) -> String {
        let c = calendar.dateComponents([.month, .day, .year], from: date)
        return switch part {
        case .month: String(c.month ?? 1)
        case .day: String(c.day ?? 1)
        case .year: String(c.year ?? 1)
        }
    }

    private func step(_ delta: Int) { date = Self.adding(delta, to: part, of: date, calendar: calendar) }

    public var body: some View {
        let p = theme.palette, s = theme.scale
        // The arrows read as always at 0, so each press arrives as a step of ±1 however often it repeats.
        let stepper = Binding<Double>(get: { 0 }, set: { step(Int($0)) })
        HStack(spacing: 4 * s) {
            HStack(spacing: 0) {
                ForEach(Array(Part.allCases.enumerated()), id: \.offset) { index, each in
                    if index > 0 { Text("/") }
                    Text(text(each)).monospacedDigit()
                        .padding(.horizontal, 2 * s)
                        .foregroundStyle(Color(part == each && isFocused ? p.selectedText : p.contentText))
                        .background(part == each && isFocused ? Color(p.highlight) : .clear)
                        .onTapGesture {
                            part = each
                            isFocused = true
                        }
                }
            }
            .padding(.horizontal, 5 * s).frame(height: 18 * s)
            .background(Color(p.content))
            .overlay(Bevel(light: Color(p.dark), dark: Color(p.light), unit: s))
            .overlay(Rectangle().strokeBorder(Color(p.border), lineWidth: s).padding(s))
            ClassicLittleArrows(value: stepper, in: -1...1)
        }
        .fixedSize()
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(phases: [.down, .repeat]) { press in
            switch press.key {
            case .upArrow: step(1)
            case .downArrow: step(-1)
            case .leftArrow: part = Part.allCases[(Part.allCases.firstIndex(of: part)! + 2) % 3]
            case .rightArrow: part = Part.allCases[(Part.allCases.firstIndex(of: part)! + 1) % 3]
            default: return .ignored
            }
            return .handled
        }
        .accessibilityElement()
        .accessibilityLabel("Date")
        .accessibilityValue(date.formatted(date: .long, time: .omitted))
        .accessibilityAdjustableAction { direction in step(direction == .increment ? 1 : -1) }
    }
}
