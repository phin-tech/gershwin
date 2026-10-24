import Foundation

extension TextColors {
    /// The colours of a Ghostty theme file: `key = value` lines, `#` comments, with `background`, `foreground`,
    /// `cursor-color`, `selection-background`, `selection-foreground`, and `palette = N=#rrggbb` for the sixteen (the
    /// format the iTerm2-Color-Schemes project publishes its schemes in, for Ghostty). What the file doesn't give comes
    /// from `base`; other keys (fonts, a 256-colour palette's upper entries) are ignored.
    public init(ghosttyTheme text: String, over base: TextColors) throws(GhosttyThemeError) {
        self = base
        for (index, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let number = index + 1
            guard let equals = line.firstIndex(of: "=") else {
                throw GhosttyThemeError(line: number, problem: "it isn't “key = value”")
            }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            func color(_ text: String) throws(GhosttyThemeError) -> RGB {
                guard let rgb = RGB(hex: text) else {
                    throw GhosttyThemeError(line: number, problem: "“\(text)” isn't a colour like #282a36")
                }
                return rgb
            }
            switch key {
            case "background": background = try color(value)
            case "foreground": foreground = try color(value)
            case "cursor-color": cursor = try color(value)
            case "selection-background": selectionBackground = try color(value)
            case "selection-foreground": selectionForeground = try color(value)
            case "palette":
                guard let split = value.firstIndex(of: "="), let slot = Int(value[..<split].trimmingCharacters(in: .whitespaces))
                else { throw GhosttyThemeError(line: number, problem: "a palette entry is “N=#rrggbb”") }
                let rgb = try color(value[value.index(after: split)...].trimmingCharacters(in: .whitespaces))
                if ansi.indices.contains(slot) { ansi[slot] = rgb }   // 16–255 aren't kept
            default:
                continue
            }
        }
    }
}

/// Why a Ghostty theme file couldn't be read, and where.
public struct GhosttyThemeError: Error, Equatable, CustomStringConvertible {
    public let line: Int
    public let problem: String

    public var description: String { "Line \(line): \(problem)." }
}

extension RGB {
    /// `#rrggbb`, `rrggbb`, or `#rgb`.
    public init?(hex text: String) {
        var digits = text.hasPrefix("#") ? String(text.dropFirst()) : text
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(value)
    }
}
