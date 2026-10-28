import GershwinAppKit
import GershwinChrome
import SwiftUI

/// A row of cells in a sunken well, the first `value` of `maximum` lit: a capacity or rating meter, where
/// ClassicProgressView is a bar for something under way.
public struct ClassicLevelIndicator: View {
    @Environment(\.classicTheme) private var theme
    let value: Int
    let maximum: Int

    public init(value: Int, maximum: Int = 10) {
        self.value = min(max(value, 0), max(maximum, 1))
        self.maximum = max(maximum, 1)
    }

    public var body: some View {
        let p = theme.palette, s = theme.scale
        let lit: Color = Family(theme.chrome) == .beos ? beosBlue : Color(theme.isAqua ? p.thumb : p.border)
        HStack(spacing: s) {
            ForEach(0..<maximum, id: \.self) { index in
                Rectangle().fill(index < value ? lit : Color(p.content))
            }
        }
        .padding(2 * s)
        .frame(height: 14 * s)
        .background(Color(p.content))
        .overlay(Bevel(light: Color(p.dark), dark: Color(p.light), unit: s))
        .overlay(Rectangle().strokeBorder(Color(p.border), lineWidth: s).padding(s))
        .accessibilityElement()
        .accessibilityValue("\(value) of \(maximum)")
    }
}
