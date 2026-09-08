//
//  GooeyNavTests.swift
//  The seam is the component, so the seam's geometry is what is tested: where it is
//  drawn, when it thins away, and which seams open at all. Checked against
//  `components/ui/gooey-nav.tsx`.
//

import CoreGraphics
@testable import RareUI
import Testing

@Suite("Gooey seam waist")
struct GooeyNeckWaistTests {
    @Test("touching tiles have a seam at full height, so they read as one block")
    func closed() {
        #expect(gooeyNeckWaist(gap: 0, span: 20) == gooeyNeckHeight)
    }

    @Test("the seam has thinned to nothing at 22% of the separation")
    func breaks() {
        let span = 20.0
        #expect(abs(gooeyNeckWaist(gap: span * gooeyNeckBreak, span: span)) < 1e-9)
    }

    @Test("the waist only ever narrows as the gap opens")
    func monotonic() {
        var previous = Double.infinity
        for step in 0 ... 100 {
            let waist = gooeyNeckWaist(gap: Double(step) / 10, span: 20)
            #expect(waist < previous)
            previous = waist
        }
    }

    @Test("the break is a fraction of the separation, so a wider bar stretches further")
    func scalesWithSeparation() {
        // Both are at the point of breaking, at very different absolute distances.
        #expect(abs(gooeyNeckWaist(gap: 14 * gooeyNeckBreak, span: 14)) < 1e-9)
        #expect(abs(gooeyNeckWaist(gap: 44 * gooeyNeckBreak, span: 44)) < 1e-9)
        // At the same absolute gap, the wider bar still has a seam and the narrow one does not.
        #expect(gooeyNeckWaist(gap: 5, span: 14) < 0)
        #expect(gooeyNeckWaist(gap: 5, span: 44) > 0)
    }
}

@Suite("Gooey seam path")
struct GooeyNeckPathTests {
    private let box = CGRect(x: 0, y: 0, width: 20, height: 40)

    @Test("a closed seam draws nothing, because the tiles are touching instead")
    func closedDrawsNothing() {
        #expect(GooeyNeck(gap: 0, span: 20).path(in: box).isEmpty)
        #expect(GooeyNeck(gap: -1, span: 20).path(in: box).isEmpty)
    }

    @Test("a seam past its breaking point draws nothing")
    func brokenDrawsNothing() {
        // 22% of 20 is 4.4, so anything beyond that has parted.
        #expect(GooeyNeck(gap: 4.4, span: 20).path(in: box).isEmpty)
        #expect(GooeyNeck(gap: 12, span: 20).path(in: box).isEmpty)
    }

    @Test("a stretched seam is drawn, and only in the gap it belongs in")
    func drawnInTheGap() {
        let gap = 2.0
        let bounds = GooeyNeck(gap: gap, span: 20).path(in: box).boundingRect
        // The path lives in the rightmost `gap` points of its own box, which is where the
        // space between the two tiles is.
        #expect(abs(bounds.minX - (box.width - gap)) < 1e-9)
        #expect(abs(bounds.maxX - box.width) < 1e-9)
    }

    @Test("the seam spans the full height of the tile it is stretched between")
    func fullHeight() {
        let bounds = GooeyNeck(gap: 1, span: 20).path(in: box).boundingRect
        #expect(abs(bounds.minY - box.minY) < 1e-9)
        #expect(abs(bounds.maxY - box.maxY) < 1e-9)
    }

    @Test("nonsense input draws nothing rather than a path full of nonsense coordinates")
    func guarded() {
        #expect(GooeyNeck(gap: .nan, span: 20).path(in: box).isEmpty)
        #expect(GooeyNeck(gap: 2, span: .nan).path(in: box).isEmpty)
        #expect(GooeyNeck(gap: 2, span: 0).path(in: box).isEmpty)
    }

    @Test("the gap is the shape's animatable value, so the seam stretches rather than jumping")
    func animatable() {
        var neck = GooeyNeck(gap: 1, span: 20)
        #expect(neck.animatableData == 1)
        neck.animatableData = 3
        #expect(neck.gap == 3)
    }
}

@Suite("Gooey seams opening")
struct GooeySeamOpeningTests {
    @Test("the ends of the bar are always open, there being nothing beyond them")
    func ends() {
        #expect(gooeyIsSeamOpen(0, active: 1, count: 3))
        #expect(gooeyIsSeamOpen(3, active: 1, count: 3))
    }

    @Test("the two seams either side of the selected tile open, and no others")
    func aroundTheSelection() {
        // Five tiles, the middle one selected: seams 2 and 3 are its own.
        let open = (0 ... 5).filter { gooeyIsSeamOpen($0, active: 2, count: 5) }
        #expect(open == [0, 2, 3, 5])
    }

    @Test("selecting an end tile opens one inner seam, not two")
    func atTheEnds() {
        #expect((0 ... 3).filter { gooeyIsSeamOpen($0, active: 0, count: 3) } == [0, 1, 3])
        #expect((0 ... 3).filter { gooeyIsSeamOpen($0, active: 2, count: 3) } == [0, 2, 3])
    }

    @Test("a single tile is open on both sides and joined to nothing")
    func lonely() {
        #expect((0 ... 1).filter { gooeyIsSeamOpen($0, active: 0, count: 1) } == [0, 1])
    }
}
