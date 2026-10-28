import GershwinAppKit
import GershwinChrome
import SwiftUI

/// A row of joined buttons of which exactly one is chosen: bevel buttons side by side with the chosen one sunken
/// (Mac OS 8 and BeOS toolbars), or Aqua's capsule of gel with the chosen segment in blue.
public struct ClassicSegmentedControl<Value: Hashable>: View {
    @Environment(\.classicTheme) private var theme
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    public init(selection: Binding<Value>, options: [(value: Value, label: String)]) {
        _selection = selection
        self.options = options
    }

    public var body: some View {
        let p = theme.palette, s = theme.scale
        Group {
            if theme.isAqua {
                HStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        if index > 0 { Rectangle().fill(Color(p.border)).frame(width: s) }
                        Button { selection = option.value } label: {
                            Text(option.label).lineLimit(1).fixedSize().padding(.horizontal, 12 * s).frame(minHeight: 20 * s)
                                .frame(maxWidth: .infinity)
                                .background(AquaGel(shape: Rectangle(),
                                                    color: option.value == selection ? Color(p.thumb) : aquaWhite))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .modifier(SegmentAccessibility(isSelected: option.value == selection))
                    }
                }
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(p.border), lineWidth: s))
            } else {
                // One pixel of overlap, so neighbouring segments share their outline.
                HStack(spacing: -s) {
                    ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                        Button { selection = option.value } label: {
                            Text(option.label).lineLimit(1).fixedSize().frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClassicBevelButtonStyle(isOn: option.value == selection))
                        .modifier(SegmentAccessibility(isSelected: option.value == selection))
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }
}

private struct SegmentAccessibility: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content.accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
