import CoreGraphics

/// How a split lays its two sides out: side by side (a divider running down between them), or one above the other.
public enum SplitAxis: String, Codable, Sendable {
    case sideBySide
    case stacked
}

/// A direction to move between panes in.
public enum SplitDirection: Sendable {
    case left, right, up, down
}

/// A window's panes, split and split again: a tree whose leaves are the apps' panes, by id, and whose branches each
/// divide their space in two at a fraction. Plain geometry: it lays the panes out in a rectangle, and splits, closes
/// and resizes them, but knows nothing of views (ClassicSplitView draws and drags it). Codable, to keep a window's
/// layout.
public struct SplitTree<ID: Hashable & Sendable & Codable>: Equatable, Sendable, Codable {
    public indirect enum Node: Equatable, Sendable, Codable {
        case pane(ID)
        /// `fraction` of the space goes to `first` (the left or top side).
        case split(SplitAxis, first: Node, second: Node, fraction: Double)
    }

    public private(set) var root: Node

    public init(pane: ID) {
        root = .pane(pane)
    }

    /// Every pane, left to right and top to bottom.
    public var panes: [ID] { Self.panes(in: root) }

    public func contains(_ pane: ID) -> Bool { panes.contains(pane) }

    private static func panes(in node: Node) -> [ID] {
        switch node {
        case .pane(let id): [id]
        case .split(_, let first, let second, _): panes(in: first) + panes(in: second)
        }
    }

    // MARK: Changing it

    /// Splits `pane` in two along `axis`: it keeps the first side (left or top), `new` gets the second.
    public mutating func split(_ pane: ID, along axis: SplitAxis, adding new: ID, fraction: Double = 0.5) {
        root = Self.replacing(pane, in: root) {
            .split(axis, first: .pane(pane), second: .pane(new), fraction: min(max(fraction, 0.05), 0.95))
        }
    }

    /// Takes `pane` out; the other side of its split takes its space. The last pane can't be closed: false.
    @discardableResult
    public mutating func close(_ pane: ID) -> Bool {
        guard case .split = root, let next = Self.removing(pane, from: root) else { return false }
        root = next
        return true
    }

    /// The pane that takes `pane`'s space when it closes: the first of the other side of its split. Nil for the last.
    public func heir(of pane: ID) -> ID? {
        Self.heir(of: pane, in: root)
    }

    private static func heir(of pane: ID, in node: Node) -> ID? {
        guard case .split(_, let first, let second, _) = node else { return nil }
        if first == .pane(pane) { return panes(in: second).first }
        if second == .pane(pane) { return panes(in: first).last }
        return heir(of: pane, in: first) ?? heir(of: pane, in: second)
    }

    private static func replacing(_ pane: ID, in node: Node, with make: () -> Node) -> Node {
        switch node {
        case .pane(let id): id == pane ? make() : node
        case .split(let axis, let first, let second, let fraction):
            .split(axis, first: replacing(pane, in: first, with: make), second: replacing(pane, in: second, with: make),
                   fraction: fraction)
        }
    }

    /// The node without `pane`, or nil if it was only that pane.
    private static func removing(_ pane: ID, from node: Node) -> Node? {
        switch node {
        case .pane(let id): return id == pane ? nil : node
        case .split(let axis, let first, let second, let fraction):
            guard let keptFirst = removing(pane, from: first) else { return second }
            guard let keptSecond = removing(pane, from: second) else { return first }
            return .split(axis, first: keptFirst, second: keptSecond, fraction: fraction)
        }
    }

    // MARK: Laying it out

    /// Where everything goes in `rect`: each pane's frame, and each divider's (`thickness` wide), in the same
    /// coordinates (flipped: y grows down). Dividers fall on whole units.
    public func layout(in rect: CGRect, divider thickness: CGFloat) -> SplitGeometry<ID> {
        var geometry = SplitGeometry<ID>(frames: [:], dividers: [])
        Self.lay(root, in: rect, thickness: thickness, path: [], into: &geometry)
        return geometry
    }

    private static func lay(_ node: Node, in rect: CGRect, thickness: CGFloat, path: [Bool],
                            into geometry: inout SplitGeometry<ID>) {
        switch node {
        case .pane(let id):
            geometry.frames[id] = rect
        case .split(let axis, let first, let second, let fraction):
            let (a, divider, b) = divide(rect, axis: axis, fraction: fraction, thickness: thickness)
            geometry.dividers.append(SplitDivider(rect: divider, axis: axis, path: path, span: rect))
            lay(first, in: a, thickness: thickness, path: path + [false], into: &geometry)
            lay(second, in: b, thickness: thickness, path: path + [true], into: &geometry)
        }
    }

    private static func divide(_ rect: CGRect, axis: SplitAxis, fraction: Double, thickness: CGFloat)
        -> (CGRect, CGRect, CGRect) {
        switch axis {
        case .sideBySide:
            let usable = max(0, rect.width - thickness)
            let x = (rect.minX + usable * fraction).rounded()
            return (CGRect(x: rect.minX, y: rect.minY, width: x - rect.minX, height: rect.height),
                    CGRect(x: x, y: rect.minY, width: thickness, height: rect.height),
                    CGRect(x: x + thickness, y: rect.minY, width: max(0, rect.maxX - x - thickness),
                           height: rect.height))
        case .stacked:
            let usable = max(0, rect.height - thickness)
            let y = (rect.minY + usable * fraction).rounded()
            return (CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: y - rect.minY),
                    CGRect(x: rect.minX, y: y, width: rect.width, height: thickness),
                    CGRect(x: rect.minX, y: y + thickness, width: rect.width,
                           height: max(0, rect.maxY - y - thickness)))
        }
    }

    /// Moves `divider` (from `layout`) so it starts at `position` (an x for side by side, a y for stacked), keeping
    /// each side at least `minimum` long.
    public mutating func move(_ divider: SplitDivider, to position: CGFloat, thickness: CGFloat, minimum: CGFloat) {
        let span = divider.span
        let (start, length) = divider.axis == .sideBySide ? (span.minX, span.width) : (span.minY, span.height)
        let usable = length - thickness
        guard usable > 0 else { return }
        let lowest = min(minimum, usable / 2), highest = usable - lowest
        let fraction = Double((min(max(position - start, lowest), highest)) / usable)
        root = Self.setting(fraction, at: divider.path[...], in: root)
    }

    private static func setting(_ fraction: Double, at path: ArraySlice<Bool>, in node: Node) -> Node {
        guard case .split(let axis, let first, let second, let old) = node else { return node }
        guard let step = path.first else { return .split(axis, first: first, second: second, fraction: fraction) }
        let rest = path.dropFirst()
        return step ? .split(axis, first: first, second: setting(fraction, at: rest, in: second), fraction: old)
            : .split(axis, first: setting(fraction, at: rest, in: first), second: second, fraction: old)
    }

    // MARK: Moving between panes

    /// The pane next to `pane` in `direction`, in a layout: of those beyond its edge that overlap it, the nearest,
    /// and of those the one most beside it, and of those the first, left to right and top to bottom.
    public func neighbor(of pane: ID, _ direction: SplitDirection, in rect: CGRect, divider thickness: CGFloat) -> ID? {
        let frames = layout(in: rect, divider: thickness).frames
        guard let from = frames[pane] else { return nil }
        func overlap(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat { max(0, min(b, d) - max(a, c)) }
        // In the tree's order, so a tie always goes the same way (min keeps the first of equals).
        let candidates: [(ID, distance: CGFloat, shared: CGFloat)] = panes.compactMap { id in
            guard id != pane, let frame = frames[id] else { return nil }
            switch direction {
            case .left where frame.maxX <= from.minX:
                return (id, from.minX - frame.maxX, overlap(frame.minY, frame.maxY, from.minY, from.maxY))
            case .right where frame.minX >= from.maxX:
                return (id, frame.minX - from.maxX, overlap(frame.minY, frame.maxY, from.minY, from.maxY))
            case .up where frame.maxY <= from.minY:
                return (id, from.minY - frame.maxY, overlap(frame.minX, frame.maxX, from.minX, from.maxX))
            case .down where frame.minY >= from.maxY:
                return (id, frame.minY - from.maxY, overlap(frame.minX, frame.maxX, from.minX, from.maxX))
            default:
                return nil
            }
        }
        return candidates.filter { $0.shared > 0 }
            .min { ($0.distance, -$0.shared) < ($1.distance, -$1.shared) }?.0
    }
}

/// A SplitTree laid out: where each pane goes, and each divider.
public struct SplitGeometry<ID: Hashable & Sendable>: Equatable, Sendable {
    public var frames: [ID: CGRect]
    public var dividers: [SplitDivider]

    public init(frames: [ID: CGRect], dividers: [SplitDivider]) {
        self.frames = frames
        self.dividers = dividers
    }

    public func divider(at point: CGPoint) -> SplitDivider? {
        dividers.last { $0.rect.contains(point) }
    }
}

/// One divider of a laid-out SplitTree: where it is, which way it runs, and which split it is (for `move`).
public struct SplitDivider: Equatable, Sendable {
    public let rect: CGRect
    public let axis: SplitAxis
    /// The way down the tree to its split: false for the first side, true for the second.
    public let path: [Bool]
    /// The space the split divides.
    public let span: CGRect
}
