import CoreGraphics
import Testing
@testable import GershwinChrome

private let bar = ScrollbarGeometry(bounds: CGRect(x: 0, y: 0, width: 16, height: 200), arrows: .elevator)

@Test func theElevatorRidesTheCableBetweenItsAnchors() {
    let top = ScrollPosition(total: 100, offset: 0, visible: 20)
    let bottom = ScrollPosition(total: 100, offset: 80, visible: 20)
    #expect(bar.elevator(for: top).minY == bar.track.minY)
    #expect(bar.elevator(for: bottom).maxY == bar.track.maxY)
    #expect(bar.elevator(for: top).height == ElevatorMetrics.part * 3)   // fixed, not proportional
    // The window's share shown on the cable instead.
    #expect(bar.proportion(for: top)?.height == (bar.track.height * 0.2).rounded())
}

@Test func theElevatorsPartsAndTheCableAndAnchorsDoWhatTheyShould() {
    let middle = ScrollPosition(total: 100, offset: 40, visible: 20)
    let e = bar.elevator(for: middle)
    #expect(bar.part(at: CGPoint(x: 8, y: e.minY + 3), position: middle) == .lineUp)
    #expect(bar.part(at: CGPoint(x: 8, y: e.midY), position: middle) == .thumb)
    #expect(bar.part(at: CGPoint(x: 8, y: e.maxY - 3), position: middle) == .lineDown)
    #expect(bar.part(at: CGPoint(x: 8, y: e.minY - 5), position: middle) == .pageUp)
    #expect(bar.part(at: CGPoint(x: 8, y: e.maxY + 5), position: middle) == .pageDown)
    #expect(bar.part(at: CGPoint(x: 8, y: 2), position: middle) == .toStart)
    #expect(bar.part(at: CGPoint(x: 8, y: 198), position: middle) == .toEnd)
}

@Test func draggingTheElevatorsMiddleScrolls() throws {
    let start = ScrollPosition(total: 100, offset: 0, visible: 20)
    let thumb = try #require(bar.thumb(for: start))
    #expect(bar.offset(forThumbTop: thumb.minY, position: start) == 0)
    let travel = bar.track.height - ElevatorMetrics.part * 3
    #expect(bar.offset(forThumbTop: thumb.minY + travel, position: start) == 80)
}

@Test func anOpenLookWindowHasItsButtonAndFourCorners() {
    let w = OpenLookChromeLayout(bounds: CGRect(x: 0, y: 0, width: 400, height: 300), style: .document)
    #expect(w.corners.count == 4 && !w.hasPushpin)
    #expect(w.corner(at: CGPoint(x: 2, y: 2)) == 0 && w.corner(at: CGPoint(x: 398, y: 298)) == 3)
    #expect(w.corner(at: CGPoint(x: 200, y: 150)) == nil)
    #expect(w.button.minX == w.header.minX + 4)
    let title = w.titleRect(textWidth: 60, textHeight: 12)
    #expect(title.midX == w.header.midX)
    let popup = OpenLookChromeLayout(bounds: CGRect(x: 0, y: 0, width: 300, height: 200), style: .panel)
    #expect(popup.hasPushpin && popup.corners.isEmpty && popup.scrollBar == nil)
}
