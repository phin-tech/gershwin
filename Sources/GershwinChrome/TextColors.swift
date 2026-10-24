import Foundation

/// The colours of text a theme's windows show: foreground, background, cursor, selection, and sixteen more, ANSI's
/// order (a terminal's colours, and enough for code or logs). Each built-in theme has its own (`ChromeTheme`'s
/// `textColors`), drawn from its era: Platinum's are the Mac's own 16-colour system palette.
public struct TextColors: Hashable, Sendable {
    public var foreground: RGB
    public var background: RGB
    public var cursor: RGB
    public var selectionBackground: RGB
    public var selectionForeground: RGB
    /// ANSI 0–15: black, red, green, yellow, blue, magenta, cyan, white, then their bright forms.
    public var ansi: [RGB]

    public init(foreground: RGB, background: RGB, cursor: RGB, selectionBackground: RGB, selectionForeground: RGB,
                ansi: [RGB]) {
        precondition(ansi.count == 16, "TextColors has sixteen ANSI colours")
        self.foreground = foreground
        self.background = background
        self.cursor = cursor
        self.selectionBackground = selectionBackground
        self.selectionForeground = selectionForeground
        self.ansi = ansi
    }

    /// For a theme of an app's own that doesn't give its own: its content's colours, the highlight for the selection,
    /// and xterm's sixteen, made to read on a light or a dark background.
    public init(for palette: Palette, isDark: Bool) {
        let xterm = isDark ? Self.beosDark : Self.beos
        self.init(foreground: palette.contentText, background: palette.content, cursor: palette.contentText,
                  selectionBackground: palette.highlight, selectionForeground: palette.selectedText, ansi: xterm.ansi)
    }

    /// Black on white, as SimpleText showed it, with the ANSI colours taken from the Mac's own 16-colour system
    /// palette. Yellow and white become tan and grey, which can be read on white.
    public static let platinum = TextColors(
        foreground: RGB(0x000000), background: RGB(0xFFFFFF), cursor: RGB(0x000000),
        selectionBackground: RGB(0xCCCCFF), selectionForeground: RGB(0x000000),
        ansi: [
            RGB(0x000000), RGB(0xDD0907), RGB(0x006412), RGB(0x90713A),
            RGB(0x0000D3), RGB(0xF20884), RGB(0x02ABEA), RGB(0xC0C0C0),
            RGB(0x404040), RGB(0xFF6403), RGB(0x1FB714), RGB(0xC0A000),
            RGB(0x4700A5), RGB(0xFF5CB0), RGB(0x2CC9F5), RGB(0x808080),
        ])

    /// Light grey on near-black, with the same system palette brightened to read on it.
    public static let hiTech = TextColors(
        foreground: RGB(0xD8D8D8), background: RGB(0x18181B), cursor: RGB(0x6FA9BB),
        selectionBackground: RGB(0x3D5F6B), selectionForeground: RGB(0xFFFFFF),
        ansi: [
            RGB(0x26262A), RGB(0xFF4B48), RGB(0x1FB714), RGB(0xFBF305),
            RGB(0x5A6BFF), RGB(0xF20884), RGB(0x02ABEA), RGB(0xC0C0C0),
            RGB(0x606066), RGB(0xFF6403), RGB(0x6BE05F), RGB(0xFFF85C),
            RGB(0x8E9BFF), RGB(0xFF5CB0), RGB(0x6FD5F7), RGB(0xFFFFFF),
        ])

    /// Dark brown on cream, with the system palette warmed to match.
    public static let gizmo = TextColors(
        foreground: RGB(0x2A1E04), background: RGB(0xFFF8E1), cursor: RGB(0x1F8A86),
        selectionBackground: RGB(0xBDE6E2), selectionForeground: RGB(0x2A1E04),
        ansi: [
            RGB(0x2A1E04), RGB(0xC8321E), RGB(0x2F7D1E), RGB(0x9A6A00),
            RGB(0x24508F), RGB(0xA33A8A), RGB(0x1F8A86), RGB(0xBFAF8A),
            RGB(0x6E5A2E), RGB(0xE8572F), RGB(0x4FA33A), RGB(0xC79400),
            RGB(0x3D74C4), RGB(0xD05CB5), RGB(0x3FB5AD), RGB(0x8F7F5A),
        ])

    /// Graphite on paper, in coloured pencil.
    public static let drawingBoard = TextColors(
        foreground: RGB(0x2B2925), background: RGB(0xFBF7EC), cursor: RGB(0xA8382C),
        selectionBackground: RGB(0xF0DFA6), selectionForeground: RGB(0x2B2925),
        ansi: [
            RGB(0x2B2925), RGB(0xA8382C), RGB(0x4E7A3A), RGB(0x9A7420),
            RGB(0x3B5D8C), RGB(0x8A4C7E), RGB(0x3E8580), RGB(0xBDB59F),
            RGB(0x6D675A), RGB(0xC85A45), RGB(0x6E9C55), RGB(0xBF9634),
            RGB(0x5B80B3), RGB(0xAB6C9E), RGB(0x5BA39D), RGB(0x8E8775),
        ])

    /// BeOS's Terminal: black on white, with xterm's colours.
    public static let beos = TextColors(
        foreground: RGB(0x000000), background: RGB(0xFFFFFF), cursor: RGB(0x000000),
        selectionBackground: RGB(0x99B4E6), selectionForeground: RGB(0x000000),
        ansi: [
            RGB(0x000000), RGB(0xCD0000), RGB(0x00A000), RGB(0xB09000),
            RGB(0x0000EE), RGB(0xCD00CD), RGB(0x00A0B0), RGB(0xA0A0A0),
            RGB(0x606060), RGB(0xFF3030), RGB(0x30C030), RGB(0xD0B000),
            RGB(0x5C5CFF), RGB(0xE040E0), RGB(0x20C0D0), RGB(0x808080),
        ])

    /// Light grey on charcoal, the cursor the tabs' orange.
    public static let beosDark = TextColors(
        foreground: RGB(0xE0E0E0), background: RGB(0x1C1C1E), cursor: RGB(0xE8772A),
        selectionBackground: RGB(0x4A5F8A), selectionForeground: RGB(0xFFFFFF),
        ansi: [
            RGB(0x2A2A2C), RGB(0xFF5A52), RGB(0x4FD05A), RGB(0xFFCB00),
            RGB(0x6E8BFF), RGB(0xE070E0), RGB(0x40D0E0), RGB(0xC8C8C8),
            RGB(0x707074), RGB(0xFF8078), RGB(0x80E888), RGB(0xFFE27A),
            RGB(0x9CB0FF), RGB(0xF0A0F0), RGB(0x80E4F0), RGB(0xFFFFFF),
        ])

    /// One bit: every colour is black, as it was in 1984, except white, which is grey enough to read.
    public static let system1 = TextColors(
        foreground: RGB(0x000000), background: RGB(0xFFFFFF), cursor: RGB(0x000000),
        selectionBackground: RGB(0x000000), selectionForeground: RGB(0xFFFFFF),
        ansi: Array(repeating: RGB(0x000000), count: 7) + [RGB(0x808080)]
            + Array(repeating: RGB(0x000000), count: 7) + [RGB(0x808080)])
}
