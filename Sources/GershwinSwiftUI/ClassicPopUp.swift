import AppKit
import GershwinAppKit
import SwiftUI

/// A pop-up menu for choosing one of a few values, drawn in the theme's style (ClassicPopUpButton): the SwiftUI
/// Picker can't be restyled, and on a Mac OS 9 screen this is what a Picker was.
public struct ClassicPopUp<Value: Hashable>: NSViewRepresentable {
    @Environment(\.classicTheme) private var theme
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    public init(selection: Binding<Value>, options: [(value: Value, label: String)]) {
        _selection = selection
        self.options = options
    }

    public func makeNSView(context: Context) -> ClassicPopUpButton {
        let button = ClassicPopUpButton(titles: options.map(\.label), selectedIndex: index, theme: theme)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .vertical)
        return button
    }

    public func updateNSView(_ button: ClassicPopUpButton, context: Context) {
        if button.theme != theme { button.theme = theme }
        let titles = options.map(\.label)
        if button.titles != titles { button.titles = titles }
        if button.selectedIndex != index { button.selectedIndex = index }
        let options = options
        let binding = $selection
        button.onChange = { chosen in
            if options.indices.contains(chosen) { binding.wrappedValue = options[chosen].value }
        }
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView button: ClassicPopUpButton, context: Context)
        -> CGSize? {
        button.intrinsicContentSize
    }

    private var index: Int { options.firstIndex { $0.value == selection } ?? 0 }
}
