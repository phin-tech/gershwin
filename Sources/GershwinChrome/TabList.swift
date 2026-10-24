import CoreGraphics

/// A window's tabs, in order, and which one is in front. Only identities: what a tab holds is the app's business.
public struct TabList<ID: Hashable & Sendable>: Equatable, Sendable {
    public private(set) var ids: [ID] = []
    public private(set) var selected: ID?

    public init() {}

    public var count: Int { ids.count }
    public var selectedIndex: Int? { selected.flatMap { ids.firstIndex(of: $0) } }

    /// Adds a tab just after the one in front (or at the end, if none is), and brings it to the front.
    public mutating func add(_ id: ID) {
        guard !ids.contains(id) else { return select(id) }
        ids.insert(id, at: selectedIndex.map { $0 + 1 } ?? ids.count)
        selected = id
    }

    /// Removes a tab. If it was in front, the one that took its place comes forward: the tab to its right, or, if it
    /// was the last, the one to its left.
    public mutating func close(_ id: ID) {
        guard let index = ids.firstIndex(of: id) else { return }
        ids.remove(at: index)
        guard selected == id else { return }
        selected = ids.isEmpty ? nil : ids[min(index, ids.count - 1)]
    }

    public mutating func select(_ id: ID) {
        if ids.contains(id) { selected = id }
    }

    /// ⌘1 to ⌘9: the tab at `index`; out of range does nothing.
    public mutating func select(index: Int) {
        if ids.indices.contains(index) { selected = ids[index] }
    }

    /// The next tab to the right (`by` 1) or left (-1), wrapping around at the ends.
    public mutating func selectAdjacent(by offset: Int) {
        guard let index = selectedIndex, !ids.isEmpty else { return }
        let n = ids.count
        selected = ids[((index + offset) % n + n) % n]
    }
}

/// How an appearance draws its tabs.
public enum TabStyle: Sendable {
    /// Mac OS 8 and 9's Appearance Manager tab control: bevelled tabs with rounded tops, the front one lighter.
    case appearanceManager
    /// Before Mac OS 8 there was no tab control; apps drew file-folder tabs: flat, outlined, with slanted sides.
    case folder
}

/// Where each tab goes in a tab bar: as wide as its title wants, within limits, and all of them narrowed evenly when
/// they don't fit. Flipped coordinates.
public enum TabStripLayout {
    public static let inset: CGFloat = 6
    public static let padding: CGFloat = 14
    public static let minimumWidth: CGFloat = 72
    public static let maximumWidth: CGFloat = 220
    /// Narrower than this and a tab is all truncation; they then run off the right rather than shrink further.
    public static let smallestWidth: CGFloat = 36

    public static func tabs(in bar: CGRect, titleWidths: [CGFloat]) -> [CGRect] {
        guard !titleWidths.isEmpty else { return [] }
        var widths = titleWidths.map { min(maximumWidth, max(minimumWidth, ($0 + padding * 2).rounded(.up))) }
        let available = max(0, bar.width - inset * 2)
        if widths.reduce(0, +) > available {
            let even = max(smallestWidth, (available / CGFloat(widths.count)).rounded(.down))
            widths = widths.map { min($0, even) }
        }
        var x = bar.minX + inset
        return widths.map { width in
            defer { x += width }
            return CGRect(x: x, y: bar.minY, width: width, height: bar.height)
        }
    }

    /// The tab under `point`, if any.
    public static func index(at point: CGPoint, in tabs: [CGRect]) -> Int? {
        tabs.firstIndex { $0.contains(point) }
    }
}
