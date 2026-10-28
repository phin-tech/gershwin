/// One thing a command palette can do. Gershwin doesn't know what it is: the app makes entries (a menu item, a tab to
/// go to, a script to run) and says what choosing one does.
public struct PaletteEntry: Sendable {
    /// Stable between openings, so the palette can remember what was chosen.
    public var id: String
    public var title: String
    /// A second line the palette shows dimmed and also searches, such as a tab's running program.
    public var detail: String?
    /// What kind of thing it is ("Menu", "Tab"): shown at the right, and searched, so "tab 3" narrows to tabs.
    public var group: String
    /// A shortcut as the menus show it ("⇧⌘P"), for the palette to draw; nothing here makes it work.
    public var shortcut: String?
    public var perform: @MainActor @Sendable () -> Void
    /// For an entry that opens a list of its own (a workspace's agents, a folder's files) rather than doing something:
    /// choosing it shows these, and Esc comes back. Asked for when the entry is chosen, so they can be made then.
    public var children: (@MainActor @Sendable () -> [PaletteEntry])?

    public init(id: String, title: String, detail: String? = nil, group: String = "", shortcut: String? = nil,
                perform: @escaping @MainActor @Sendable () -> Void) {
        self.id = id
        self.title = title
        self.detail = detail
        self.group = group
        self.shortcut = shortcut
        self.perform = perform
    }

    /// An entry that opens a list of `children` when it's chosen.
    public init(id: String, title: String, detail: String? = nil, group: String = "", shortcut: String? = nil,
                opens children: @escaping @MainActor @Sendable () -> [PaletteEntry]) {
        self.init(id: id, title: title, detail: detail, group: group, shortcut: shortcut, perform: {})
        self.children = children
    }

    public var opensList: Bool { children != nil }
}

/// The ids of what was chosen lately, most recent first, so what a person reaches for floats up.
public struct PaletteHistory: Codable, Equatable, Sendable {
    public static let capacity = 50
    public private(set) var recent: [String] = []

    public init() {}

    public mutating func record(_ id: String) {
        recent.removeAll { $0 == id }
        recent.insert(id, at: 0)
        if recent.count > Self.capacity { recent.removeLast(recent.count - Self.capacity) }
    }

    /// A score to add: 3 for the last one chosen, falling evenly to 0 at the end of the list, and 0 if not in it.
    func boost(for id: String) -> Double {
        guard let rank = recent.firstIndex(of: id) else { return 0 }
        return 3 * Double(Self.capacity - rank) / Double(Self.capacity)
    }
}

/// An entry that matched a query.
public struct PaletteMatch: Sendable {
    public var entry: PaletteEntry
    public var score: Double
    /// Which characters of the title matched (offsets into `Array(entry.title)`, ascending), for the palette to
    /// emphasise. Empty when the query matched only the detail or group.
    public var titleMatches: [Int]
}

/// Fuzzy matching for a palette: each word of the query must appear, in order but not necessarily together, in the
/// title, or (counting for half) in the group and detail. A match at the start of a word scores higher, as does one
/// right after the last letter, and one at the very start of the title highest, so "spl" finds "Split Right" before
/// "Show Panes List".
public enum PaletteMatcher {
    /// `entries` that match `query`, best first; ties keep the order given. An empty query matches everything, with
    /// what was chosen lately first.
    public static func rank(_ query: String, _ entries: [PaletteEntry], history: PaletteHistory = PaletteHistory())
        -> [PaletteMatch] {
        let words = query.split(whereSeparator: \.isWhitespace).map { fold(Array($0)) }
        var matches: [(match: PaletteMatch, index: Int)] = []
        for (index, entry) in entries.enumerated() {
            guard let (score, positions) = score(words, entry) else { continue }
            matches.append((PaletteMatch(entry: entry, score: score + history.boost(for: entry.id),
                                         titleMatches: positions), index))
        }
        matches.sort { a, b in
            if a.match.score != b.match.score { return a.match.score > b.match.score }
            // Of equal scores the shorter title is the closer match; with nothing typed, none is, and the order given stands.
            if !words.isEmpty, a.match.entry.title.count != b.match.entry.title.count {
                return a.match.entry.title.count < b.match.entry.title.count
            }
            return a.index < b.index
        }
        return matches.map(\.match)
    }

    private static func score(_ words: [[Character]], _ entry: PaletteEntry) -> (Double, [Int])? {
        guard !words.isEmpty else { return (0, []) }
        let title = Array(entry.title)
        let foldedTitle = fold(title)
        let other = fold(Array([entry.group, entry.detail ?? ""].filter { !$0.isEmpty }.joined(separator: " ")))
        let otherOriginal = Array([entry.group, entry.detail ?? ""].filter { !$0.isEmpty }.joined(separator: " "))
        var total = 0.0
        var positions = Set<Int>()
        for word in words {
            let inTitle = fit(word, in: foldedTitle, original: title)
            let elsewhere = fit(word, in: other, original: otherOriginal).map { ($0.score / 2, [Int]()) }
            switch (inTitle, elsewhere) {
            case let (t?, e?) where e.0 > t.score:
                total += e.0
            case let (t?, _):
                total += t.score
                positions.formUnion(t.positions)
            case let (nil, e?):
                total += e.0
            case (nil, nil):
                return nil
            }
        }
        return (total, positions.sorted())
    }

    /// The best way for `word` to appear in `text` in order, as a score and where; nil if it can't.
    private static func fit(_ word: [Character], in text: [Character], original: [Character])
        -> (score: Double, positions: [Int])? {
        let m = word.count, n = text.count
        guard m > 0, m <= n else { return nil }
        let none = -Double.infinity
        func gain(_ j: Int) -> Double {
            1 + (j == 0 ? 5 : isBoundary(original, j) ? 3 : 0)
        }
        var previous = [Double](repeating: none, count: n)
        var parents = [[Int]](repeating: [Int](repeating: -1, count: n), count: m)
        for j in 0..<n where text[j] == word[0] { previous[j] = gain(j) }
        for i in 1..<max(m, 1) {
            var current = [Double](repeating: none, count: n)
            var bestBefore = none, bestBeforeIndex = -1
            for j in 0..<n {
                if j >= 2, previous[j - 2] > bestBefore { (bestBefore, bestBeforeIndex) = (previous[j - 2], j - 2) }
                guard text[j] == word[i] else { continue }
                var best = none, from = -1
                if j >= 1, previous[j - 1] > none { (best, from) = (previous[j - 1] + gain(j) + 5, j - 1) }
                if bestBefore > none, bestBefore + gain(j) > best { (best, from) = (bestBefore + gain(j), bestBeforeIndex) }
                if from >= 0 { current[j] = best; parents[i][j] = from }
            }
            previous = current
        }
        guard let end = previous.indices.max(by: { previous[$0] < previous[$1] }), previous[end] > none else { return nil }
        var positions = [Int](repeating: 0, count: m)
        var j = end
        for i in stride(from: m - 1, through: 0, by: -1) {
            positions[i] = j
            if i > 0 { j = parents[i][j] }
        }
        return (previous[end], positions)
    }

    /// Where a word starts: after anything that isn't a letter or digit ("Panes ▸ Split", "Theme: BeOS"), or at a
    /// capital after a lower-case letter ("BeOS").
    private static func isBoundary(_ text: [Character], _ j: Int) -> Bool {
        guard j > 0 else { return true }
        let before = text[j - 1]
        return !(before.isLetter || before.isNumber) || (before.isLowercase && text[j].isUppercase)
    }

    /// Lower-case, one character for each, so offsets stay the title's own.
    private static func fold(_ text: [Character]) -> [Character] {
        text.map { $0.lowercased().first ?? $0 }
    }
}
