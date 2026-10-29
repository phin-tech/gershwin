import AppKit
import GershwinChrome
import Observation

/// What an app's chrome is saved as: a ThemeChoice (one theme, or one each for light and dark while following macOS)
/// and the scale of the chrome's pixels.
public struct ClassicThemeSettings: Codable, Equatable, Sendable {
    public var themeChoice: ThemeChoice
    /// The scales that keep every chrome pixel on whole Retina pixels (two, three or four of them).
    public static let scales: [Double] = [1, 1.5, 2]
    public var interfaceScale: Double

    public init(themeChoice: ThemeChoice = ThemeChoice(), interfaceScale: Double = 1) {
        self.themeChoice = themeChoice
        self.interfaceScale = interfaceScale
    }

    // Field by field, so a key left out (or an old file) is the default.
    private enum CodingKeys: String, CodingKey { case themeChoice, interfaceScale }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        themeChoice = (try? c.decodeIfPresent(ThemeChoice.self, forKey: .themeChoice)) ?? ThemeChoice()
        let scale = (try? c.decodeIfPresent(Double.self, forKey: .interfaceScale)) ?? 1
        interfaceScale = Self.scales.contains(scale) ? scale : 1
    }
}

/// The theme an app draws with: the user's ThemeChoice and scale, kept in a JSON file (so dotfile tools can carry it
/// between Macs; written through a symlink to where it points), and the mode macOS is in, watched so a choice that
/// follows macOS changes with it. Read `theme` from a SwiftUI body and it updates the view; set `onChange` to restyle
/// AppKit windows (`ClassicWindow.theme`).
///
///     let themes = ClassicThemeStore(fileURL: ...)   // ~/.config/<app>/settings.json
///     themes.onChange = { for window in windows { window.theme = themes.theme } }
@MainActor
@Observable
public final class ClassicThemeStore {
    public var settings: ClassicThemeSettings {
        didSet {
            guard settings != oldValue else { return }
            save()
            onChange?()
        }
    }

    /// Whether macOS is in dark mode now.
    public private(set) var systemIsDark: Bool {
        didSet { if systemIsDark != oldValue { onChange?() } }
    }

    /// Called after a change to what is drawn: the choice, the scale, or macOS's mode.
    @ObservationIgnored public var onChange: (() -> Void)?

    /// What every window draws with: the theme showing, at the chosen scale.
    public var theme: ClassicTheme {
        ClassicTheme(settings.themeChoice.theme(systemIsDark: systemIsDark), scale: settings.interfaceScale)
    }

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var observation: NSKeyValueObservation?

    /// `systemIsDark` is for tests; an app leaves it nil and follows macOS.
    public init(fileURL: URL, systemIsDark: Bool? = nil) {
        self.fileURL = fileURL
        settings = (try? JSONDecoder().decode(ClassicThemeSettings.self, from: Data(contentsOf: fileURL)))
            ?? ClassicThemeSettings()
        self.systemIsDark = systemIsDark ?? Self.isDark(NSApplication.shared.effectiveAppearance)
        guard systemIsDark == nil else { return }
        // A ClassicWindow sets its own appearance, not the app's, so the app's keeps following macOS.
        observation = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in self?.systemIsDark = Self.isDark(NSApplication.shared.effectiveAppearance) }
        }
    }

    /// `~/.config/<app>/settings.json`.
    public nonisolated static func defaultURL(app: String) -> URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/\(app)/settings.json")
    }

    /// Whether an appearance is a dark one (what an app that watches `effectiveAppearance` itself asks).
    public nonisolated static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let target = fileURL.resolvingSymlinksInPath()
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(settings).write(to: target, options: .atomic)
        } catch {
            NSLog("Gershwin: couldn't write %@: %@", fileURL.path, "\(error)")
        }
    }
}
