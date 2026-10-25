import GershwinAppKit
import GershwinChrome
import SwiftUI

/// ClassicProgressBar for SwiftUI: a fraction from 0 to 1, or nil for the barber pole.
public struct ClassicProgressView: NSViewRepresentable {
    let value: Double?
    @Environment(\.classicTheme) private var theme

    public init(value: Double?) { self.value = value }

    public func makeNSView(context: Context) -> ClassicProgressBar { ClassicProgressBar(value: value, theme: theme) }

    public func updateNSView(_ bar: ClassicProgressBar, context: Context) {
        bar.theme = theme
        bar.value = value
    }
}

/// The strip along the bottom of a window: a line of text, and at its right a progress bar while `progress` is set
/// (`.indeterminate` is the barber pole).
public struct ClassicStatusBar: View {
    @Environment(\.classicTheme) private var theme
    let text: String
    let progress: ClassicProgress?

    public init(_ text: String, progress: ClassicProgress? = nil) {
        self.text = text
        self.progress = progress
    }

    public var body: some View {
        let s = theme.scale
        HStack(spacing: 8 * s) {
            Text(text).lineLimit(1)
            Spacer()
            if let progress {
                ClassicProgressView(value: progress.fraction).frame(width: 160 * s, height: 12 * s)
            }
        }
        .padding(.horizontal, 8 * s)
        .frame(height: 22 * s)
        .background(Color(theme.palette.background))
        .overlay(alignment: .top) { Rectangle().fill(Color(theme.palette.dark)).frame(height: 1) }
    }
}
