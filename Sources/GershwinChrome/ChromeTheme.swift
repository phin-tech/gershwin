/// A colour as eight bits a channel, the way Mac OS 9's palettes were written down.
public struct RGB: Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(_ hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    /// "#RRGGBB".
    public var hex: String {
        "#" + [red, green, blue].map { String($0, radix: 16, uppercase: true).leftPadded(to: 2) }.joined()
    }
}

private extension String {
    func leftPadded(to width: Int) -> String {
        String(repeating: "0", count: max(0, width - count)) + self
    }
}

/// A look: the shape of the windows, how tabs are drawn, and the colours everything is drawn from. Eight are built
/// in; an app can make its own (often from one of these, with a few colours changed).
public struct ChromeTheme: Hashable, Sendable, Identifiable, Codable {
    /// Stable across versions, for saving which one was chosen.
    public var id: String
    public var name: String
    public var family: ChromeFamily
    public var tabStyle: TabStyle
    /// Whether macOS's own pieces (sheets, the font panel) should be drawn dark beside it.
    public var isDark: Bool
    public var palette: Palette
    /// The colours of the text its windows show: a terminal's, a code view's.
    public var textColors: TextColors
    /// The id of its pair in the other mode (Platinum's is Hi-Tech, BeOS's BeOS Dark), for following macOS.
    public var partner: String?

    public init(id: String, name: String, family: ChromeFamily = .macintosh, tabStyle: TabStyle = .appearanceManager,
                isDark: Bool = false, palette: Palette, textColors: TextColors? = nil, partner: String? = nil) {
        self.id = id
        self.name = name
        self.family = family
        self.tabStyle = tabStyle
        self.isDark = isDark
        self.palette = palette
        self.textColors = textColors ?? TextColors(for: palette, isDark: isDark)
        self.partner = partner
    }

    /// A built-in theme by its id.
    public static func named(_ id: String, among themes: [ChromeTheme] = builtIn) -> ChromeTheme? {
        themes.first { $0.id == id }
    }

    /// Its pair in dark mode: itself if it's dark; its partner; or Hi-Tech, Platinum's.
    public func darkCounterpart(among themes: [ChromeTheme] = builtIn) -> ChromeTheme {
        if isDark { return self }
        return partner.flatMap { Self.named($0, among: themes) }.flatMap { $0.isDark ? $0 : nil } ?? .hiTech
    }

    /// Its pair in light mode: itself if it's light; its partner; or Platinum, Hi-Tech's.
    public func lightCounterpart(among themes: [ChromeTheme] = builtIn) -> ChromeTheme {
        if !isDark { return self }
        return partner.flatMap { Self.named($0, among: themes) }.flatMap { $0.isDark ? nil : $0 } ?? .platinum
    }

    /// Saved as its id, so a settings file says "beos"; read back among the built-in themes.
    public init(from decoder: Decoder) throws {
        let id = try decoder.singleValueContainer().decode(String.self)
        guard let theme = Self.named(id) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "no theme is called \(id)"))
        }
        self = theme
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }

    /// Mac OS 8 and 9.
    public static let platinum = ChromeTheme(id: "platinum", name: "Platinum", palette: .platinum,
                                             textColors: .platinum, partner: "hiTech")
    /// Copland's dark, metal theme, which Mac OS 8 was to ship as Hi-Tech.
    public static let hiTech = ChromeTheme(id: "hiTech", name: "Hi-Tech", isDark: true, palette: .hiTech,
                                           textColors: .hiTech, partner: "platinum")
    /// Copland's toy-like theme, in the Mac OS 8 betas: mustard plastic and teal.
    public static let gizmo = ChromeTheme(id: "gizmo", name: "Gizmo", palette: .gizmo, textColors: .gizmo)
    /// Copland's sketchbook theme, in the Mac OS 8 betas: paper and pencil.
    public static let drawingBoard = ChromeTheme(id: "drawingBoard", name: "Drawing Board", palette: .drawingBoard,
                                                 textColors: .drawingBoard)
    /// System 7, in colour: flat greys, black highlights, file-folder tabs.
    public static let system7 = ChromeTheme(id: "system7", name: "System 7", tabStyle: .folder, palette: .system7,
                                            textColors: .platinum)
    /// The 1984 Macintosh: one bit, black on white.
    public static let system1 = ChromeTheme(id: "system1", name: "System 1", tabStyle: .folder, palette: .system1,
                                            textColors: .system1)
    /// BeOS R5: yellow title tabs on grey windows.
    public static let beos = ChromeTheme(id: "beos", name: "BeOS", family: .beos, palette: .beos, textColors: .beos,
                                         partner: "beosDark")
    /// BeOS, dark, as Haiku can be: charcoal windows, their tabs a fall orange.
    public static let beosDark = ChromeTheme(id: "beosDark", name: "BeOS Dark", family: .beos, isDark: true,
                                             palette: .beosDark, textColors: .beosDark, partner: "beos")

    /// OS/2 Warp 4: light grey frames under a blue title bar, the text an Enhanced Editor's, black on white.
    public static let os2 = ChromeTheme(id: "os2", name: "OS/2 Warp", family: .os2, palette: .os2, textColors: .os2,
                                        partner: "os2Dark")
    /// OS/2 Warp in dark greys (which it never had), the text an OS/2 window's: grey on black, in CGA's colours.
    public static let os2Dark = ChromeTheme(id: "os2Dark", name: "OS/2 Warp Dark", family: .os2, isDark: true,
                                            palette: .os2Dark, textColors: .os2Dark, partner: "os2")

    public static let builtIn: [ChromeTheme] = [
        .platinum, .hiTech, .gizmo, .drawingBoard, .system7, .system1, .beos, .beosDark, .os2, .os2Dark,
    ]
}

/// The colour tokens everything is drawn from, like NeoBrutalism's `NBTheme`: a window's frame and a push button
/// read the same `light` and `dark`, so they can't drift apart. The values for Platinum are the ones Sam's SketchyBar
/// menus use (chezmoi's `helpers/shared/Platinum.swift`).
public struct Palette: Hashable, Sendable {
    /// Window frames, title bars, scroll bar tracks and dialog backgrounds.
    public var background: RGB
    /// The bevel's highlight, on the top and left of anything raised.
    public var light: RGB
    /// The bevel's shade, on the bottom and right.
    public var dark: RGB
    /// The one-pixel outline around windows and controls.
    public var border: RGB
    /// Sunken areas: a pressed button, a scroll bar's track.
    public var well: RGB
    /// Selected rows and menu items, and the default button's ring.
    public var highlight: RGB
    public var text: RGB
    public var selectedText: RGB
    public var disabledText: RGB
    /// The title bar's horizontal stripes on the frontmost window.
    public var pinstripe: RGB
    /// A scroll bar's thumb, and the face of the window's boxes.
    public var thumb: RGB
    /// A document's own background and text: what a window's content shows, the front tab that opens onto it, and
    /// a text field.
    public var content: RGB
    public var contentText: RGB
    /// Sunken areas are a 50% checkerboard of `border` and `background`, as on a one-bit screen, rather than `well`.
    public var dithersWells = false
    /// The title tab's colours, for a theme whose windows have one (BeOS).
    public var titleTab: TitleTabColors? = nil

    /// A palette of an app's own, for a theme of its own (ChromeTheme's init).
    public init(background: RGB, light: RGB, dark: RGB, border: RGB, well: RGB, highlight: RGB, text: RGB,
                selectedText: RGB, disabledText: RGB, pinstripe: RGB, thumb: RGB, content: RGB, contentText: RGB,
                dithersWells: Bool = false, titleTab: TitleTabColors? = nil) {
        self.background = background
        self.light = light
        self.dark = dark
        self.border = border
        self.well = well
        self.highlight = highlight
        self.text = text
        self.selectedText = selectedText
        self.disabledText = disabledText
        self.pinstripe = pinstripe
        self.thumb = thumb
        self.content = content
        self.contentText = contentText
        self.dithersWells = dithersWells
        self.titleTab = titleTab
    }

    public static let platinum = Palette(
        background: RGB(0xDDDDDD), light: RGB(0xFFFFFF), dark: RGB(0x888888), border: RGB(0x000000),
        well: RGB(0xBBBBBB), highlight: RGB(0x333399), text: RGB(0x000000), selectedText: RGB(0xFFFFFF),
        disabledText: RGB(0x888888), pinstripe: RGB(0x999999), thumb: RGB(0xCCCCFF),
        content: RGB(0xFFFFFF), contentText: RGB(0x000000))

    public static let hiTech = Palette(
        background: RGB(0x4A4A4E), light: RGB(0x77777D), dark: RGB(0x26262A), border: RGB(0x000000),
        well: RGB(0x333337), highlight: RGB(0x3D8FA8), text: RGB(0xE6E6E6), selectedText: RGB(0xFFFFFF),
        disabledText: RGB(0x8A8A8E), pinstripe: RGB(0x5C5C62), thumb: RGB(0x6FA9BB),
        content: RGB(0x18181B), contentText: RGB(0xD8D8D8))

    public static let gizmo = Palette(
        background: RGB(0xE8C66A), light: RGB(0xFFF1B8), dark: RGB(0xA27D22), border: RGB(0x3B2A06),
        well: RGB(0xC9A445), highlight: RGB(0x1F8A86), text: RGB(0x2A1E04), selectedText: RGB(0xFFFFFF),
        disabledText: RGB(0x9C7F3A), pinstripe: RGB(0xCFA748), thumb: RGB(0x5CC5BC),
        content: RGB(0xFFF8E1), contentText: RGB(0x2A1E04))

    public static let drawingBoard = Palette(
        background: RGB(0xEFE8D6), light: RGB(0xFFFDF6), dark: RGB(0xA59C86), border: RGB(0x34322D),
        well: RGB(0xD9D0BA), highlight: RGB(0xA8382C), text: RGB(0x2B2925), selectedText: RGB(0xFFFFFF),
        disabledText: RGB(0x9F9784), pinstripe: RGB(0xCDC4AC), thumb: RGB(0xE4D29A),
        content: RGB(0xFBF7EC), contentText: RGB(0x2B2925))

    public static let system7 = Palette(
        background: RGB(0xEEEEEE), light: RGB(0xFFFFFF), dark: RGB(0xAAAAAA), border: RGB(0x000000),
        well: RGB(0xCCCCCC), highlight: RGB(0x000000), text: RGB(0x000000), selectedText: RGB(0xFFFFFF),
        disabledText: RGB(0x999999), pinstripe: RGB(0x777777), thumb: RGB(0xDDDDFF),
        content: RGB(0xFFFFFF), contentText: RGB(0x000000))

    /// No greys at all: the bevels vanish into white, the title bar's stripes are black, and the scroll bar's track
    /// is dithered.
    public static let system1 = Palette(
        background: RGB(0xFFFFFF), light: RGB(0xFFFFFF), dark: RGB(0xFFFFFF), border: RGB(0x000000),
        well: RGB(0xFFFFFF), highlight: RGB(0x000000), text: RGB(0x000000), selectedText: RGB(0xFFFFFF),
        disabledText: RGB(0x808080), pinstripe: RGB(0x000000), thumb: RGB(0xFFFFFF),
        content: RGB(0xFFFFFF), contentText: RGB(0x000000), dithersWells: true)

    public static let beos = Palette(
        background: RGB(0xD8D8D8), light: RGB(0xFFFFFF), dark: RGB(0x989898), border: RGB(0x606060),
        well: RGB(0xC4C4C4), highlight: RGB(0x3366CC), text: RGB(0x000000), selectedText: RGB(0xFFFFFF),
        disabledText: RGB(0x8C8C8C), pinstripe: RGB(0xD8D8D8), thumb: RGB(0xE0E0E0),
        content: RGB(0xFFFFFF), contentText: RGB(0x000000),
        titleTab: TitleTabColors(face: RGB(0xFFCB00), light: RGB(0xFFEC94), dark: RGB(0xC89A00),
                                 inactiveFace: RGB(0xE8E8E8)))

    /// Warp 4's greys and its blue title bar. From memory of Warp 4's defaults: check against a running Warp 4 or
    /// ArcaOS before treating them as exact.
    public static let os2 = Palette(
        background: RGB(0xCCCCCC), light: RGB(0xFFFFFF), dark: RGB(0x808080), border: RGB(0x404040),
        well: RGB(0xB4B4B4), highlight: RGB(0x1D4F9A), text: RGB(0x000000), selectedText: RGB(0xFFFFFF),
        disabledText: RGB(0x808080), pinstripe: RGB(0xCCCCCC), thumb: RGB(0xCCCCCC),
        content: RGB(0xFFFFFF), contentText: RGB(0x000000),
        titleTab: TitleTabColors(face: RGB(0x1D4F9A), light: RGB(0x5A86C8), dark: RGB(0x0E2C5C),
                                 inactiveFace: RGB(0xB4B4B4), text: RGB(0xFFFFFF)))

    /// Warp's shapes in charcoal, the title bar the same blue.
    public static let os2Dark = Palette(
        background: RGB(0x3C3C40), light: RGB(0x5E5E64), dark: RGB(0x1E1E22), border: RGB(0x000000),
        well: RGB(0x2C2C30), highlight: RGB(0x2A5CA8), text: RGB(0xE0E0E0), selectedText: RGB(0xFFFFFF),
        disabledText: RGB(0x8A8A90), pinstripe: RGB(0x3C3C40), thumb: RGB(0x5E5E64),
        content: RGB(0x000000), contentText: RGB(0xAAAAAA),
        titleTab: TitleTabColors(face: RGB(0x2A5CA8), light: RGB(0x5A86C8), dark: RGB(0x123366),
                                 inactiveFace: RGB(0x4A4A50), text: RGB(0xFFFFFF)))

    public static let beosDark = Palette(
        background: RGB(0x3A3A3C), light: RGB(0x58585B), dark: RGB(0x1E1E20), border: RGB(0x0C0C0C),
        well: RGB(0x2C2C2E), highlight: RGB(0x5C8DE0), text: RGB(0xE6E6E6), selectedText: RGB(0xFFFFFF),
        disabledText: RGB(0x8A8A8E), pinstripe: RGB(0x3A3A3C), thumb: RGB(0x4E4E52),
        content: RGB(0x1C1C1E), contentText: RGB(0xE0E0E0),
        // A fall orange in place of the yellow, with a dark brown title on it.
        titleTab: TitleTabColors(face: RGB(0xD9661F), light: RGB(0xF09A55), dark: RGB(0x9C4512),
                                 inactiveFace: RGB(0x4A4A4D), text: RGB(0x241005)))
}

/// A BeOS title tab: yellow on the frontmost window (with a highlight and a shade for its bevel), grey otherwise and
/// on the tabs behind the front one.
public struct TitleTabColors: Hashable, Sendable {
    public var face: RGB
    public var light: RGB
    public var dark: RGB
    public var inactiveFace: RGB
    /// The title on the coloured face: black, even when the rest of the theme writes in light grey.
    public var text: RGB

    public init(face: RGB, light: RGB, dark: RGB, inactiveFace: RGB, text: RGB = RGB(0x000000)) {
        self.face = face
        self.light = light
        self.dark = dark
        self.inactiveFace = inactiveFace
        self.text = text
    }
}
