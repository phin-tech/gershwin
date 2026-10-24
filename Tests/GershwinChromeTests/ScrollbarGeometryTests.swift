import CoreGraphics
import Testing
@testable import GershwinChrome

// A 16-wide bar 216 tall: 16-point arrows at each end and a 184-point track between them.
private let bar = ScrollbarGeometry(bounds: CGRect(x: 0, y: 0, width: 16, height: 216))

@Test func arrowsAndTrackTileTheBar() {
    #expect(bar.upArrow == CGRect(x: 0, y: 0, width: 16, height: 16))
    #expect(bar.downArrow == CGRect(x: 0, y: 200, width: 16, height: 16))
    #expect(bar.track == CGRect(x: 0, y: 16, width: 16, height: 184))
}

@Test func noThumbWhenEverythingFitsOnScreen() {
    let position = ScrollPosition(total: 24, offset: 0, visible: 24)
    #expect(bar.thumb(for: position) == nil)
    #expect(bar.part(at: CGPoint(x: 8, y: 100), position: position) == nil)
}

@Test(arguments: [
    // total, offset, visible, expected thumb top, expected length
    (UInt64(48), UInt64(0), UInt64(24), CGFloat(16), CGFloat(92)),    // top: half the rows on screen
    (48, 24, 24, 108, 92),                                            // bottom
    (10_000, 0, 24, 16, 16),                                          // long scrollback: no shorter than an arrow
    (10_000, 9_976, 24, 184, 16),
])
func thumbIsProportionalAndFollowsTheOffset(total: UInt64, offset: UInt64, visible: UInt64,
                                            top: CGFloat, length: CGFloat) throws {
    let thumb = try #require(bar.thumb(for: ScrollPosition(total: total, offset: offset, visible: visible)))
    #expect(thumb.minY == top)
    #expect(thumb.height == length)
    #expect(bar.track.contains(thumb))
}

@Test func draggingTheThumbRoundTripsToTheOffset() throws {
    let position = ScrollPosition(total: 1_000, offset: 500, visible: 40)
    let thumb = try #require(bar.thumb(for: position))
    let offset = bar.offset(forThumbTop: thumb.minY, position: position)
    #expect(abs(Int(offset) - 500) <= 6)   // within a point's worth of rows
}

@Test func draggingPastEitherEndClamps() {
    let position = ScrollPosition(total: 1_000, offset: 0, visible: 40)
    #expect(bar.offset(forThumbTop: -500, position: position) == 0)
    #expect(bar.offset(forThumbTop: 5_000, position: position) == position.maxOffset)
}

@Test func clicksAreArrowsPagesOrTheThumb() throws {
    let position = ScrollPosition(total: 48, offset: 12, visible: 24)
    let thumb = try #require(bar.thumb(for: position))
    #expect(bar.part(at: CGPoint(x: 8, y: 4), position: position) == .lineUp)
    #expect(bar.part(at: CGPoint(x: 8, y: 210), position: position) == .lineDown)
    #expect(bar.part(at: CGPoint(x: 8, y: thumb.minY - 1), position: position) == .pageUp)
    #expect(bar.part(at: CGPoint(x: 8, y: thumb.maxY + 1), position: position) == .pageDown)
    #expect(bar.part(at: CGPoint(x: 8, y: thumb.midY), position: position) == .thumb)
    #expect(bar.part(at: CGPoint(x: 30, y: 100), position: position) == nil)
}

@Test func shortBarSplitsItsHeightBetweenTheArrows() {
    let tiny = ScrollbarGeometry(bounds: CGRect(x: 0, y: 0, width: 16, height: 20))
    #expect(tiny.upArrow.height == 10)
    #expect(tiny.track.height == 0)
    #expect(tiny.thumb(for: ScrollPosition(total: 100, offset: 0, visible: 10)) == nil)
}
