import GershwinAppKit
import GershwinChrome
import SwiftUI

/// A swatch of the chosen colour that, clicked, opens the Mac's sixteen-colour palette beneath it. Esc closes it.
public struct ClassicColorWell: View {
    @Environment(\.classicTheme) private var theme
    @Binding var selection: RGB
    @State private var isOpen = false

    /// The classic Mac's 16 colours, in the order of its System palette.
    public static let palette: [RGB] = [
        RGB(0xFFFFFF), RGB(0xFCF305), RGB(0xFF6402), RGB(0xDD0806),
        RGB(0xF20884), RGB(0x4600A5), RGB(0x0000D4), RGB(0x00ABEA),
        RGB(0x1FB714), RGB(0x006411), RGB(0x562C05), RGB(0x90713A),
        RGB(0xC0C0C0), RGB(0x808080), RGB(0x404040), RGB(0x000000),
    ]

    public init(selection: Binding<RGB>) { _selection = selection }

    public var body: some View {
        let p = theme.palette, s = theme.scale
        Button { isOpen.toggle() } label: {
            Color(selection).frame(width: 28 * s, height: 16 * s)
                .overlay(Rectangle().strokeBorder(Color(p.border), lineWidth: s))
                .padding(2 * s)
        }
        .buttonStyle(ClassicBevelButtonStyle(isOn: isOpen))
        .accessibilityLabel("Colour")
        .classicPopover(isPresented: $isOpen) {
            Grid(horizontalSpacing: s, verticalSpacing: s) {
                ForEach(0..<4, id: \.self) { row in
                    GridRow {
                        ForEach(0..<4, id: \.self) { column in
                            let color = Self.palette[row * 4 + column]
                            Button {
                                selection = color
                                isOpen = false
                            } label: {
                                Color(color).frame(width: 18 * s, height: 18 * s)
                                    .overlay(Rectangle().strokeBorder(
                                        Color(p.border), lineWidth: color == selection ? 2 * s : s))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
