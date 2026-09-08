//
//  PathMorphTests.swift
//  The stand-in for flubber. It has to end up exactly on both outlines and stay a sensible
//  shape everywhere in between, or a pen turning into a tick turns inside out on the way.
//

import CoreGraphics
@testable import RareUI
import SwiftUI
import Testing

@Suite("Path morph")
struct PathMorphTests {
    private let box = CGSize(width: 24, height: 24)
    private let rect = CGRect(x: 0, y: 0, width: 24, height: 24)

    private var square: Path {
        SVGPath.path("M4 4H20V20H4Z")
    }

    private var tall: Path {
        SVGPath.path("M10 2H14V22H10Z")
    }

    @Test("at either end it is the outline it started or finished on")
    func endpoints() {
        let morph = PathMorph(from: square, to: tall)

        let start = morph.path(at: 0, in: rect, viewBox: box).boundingRect
        #expect(abs(start.minX - 4) < 0.5)
        #expect(abs(start.maxX - 20) < 0.5)

        let end = morph.path(at: 1, in: rect, viewBox: box).boundingRect
        #expect(abs(end.minX - 10) < 0.5)
        #expect(abs(end.maxX - 14) < 0.5)
    }

    @Test("halfway across it is halfway between the two")
    func middle() {
        let morph = PathMorph(from: square, to: tall)
        let middle = morph.path(at: 0.5, in: rect, viewBox: box).boundingRect
        // The square is sixteen wide and the bar is four, so halfway is about ten.
        #expect(abs(middle.width - 10) < 1.5)
    }

    @Test("it never leaves the ground the two outlines cover between them")
    func staysWithin() {
        let morph = PathMorph(from: square, to: tall)
        for step in stride(from: 0.0, through: 1.0, by: 0.05) {
            let bounds = morph.path(at: step, in: rect, viewBox: box).boundingRect
            #expect(bounds.minX >= 4 - 0.5)
            #expect(bounds.maxX <= 20 + 0.5)
            #expect(bounds.minY >= 2 - 0.5)
            #expect(bounds.maxY <= 22 + 0.5)
        }
    }

    @Test("the outline keeps its area rather than collapsing partway across")
    func doesNotCollapse() {
        // A morph whose two rings are not lined up pinches through itself in the middle and
        // the shape all but disappears. Watching the bounding box is a cheap way to catch it.
        let morph = PathMorph(from: square, to: tall)
        for step in stride(from: 0.05, through: 0.95, by: 0.05) {
            let bounds = morph.path(at: step, in: rect, viewBox: box).boundingRect
            #expect(bounds.width > 3, "it went flat at \(step)")
            #expect(bounds.height > 3, "it went flat at \(step)")
        }
    }

    @Test("progress outside the range is held at the ends")
    func clamped() {
        let morph = PathMorph(from: square, to: tall)
        let under = morph.path(at: -1, in: rect, viewBox: box).boundingRect
        let over = morph.path(at: 2, in: rect, viewBox: box).boundingRect
        #expect(abs(under.width - 16) < 0.5)
        #expect(abs(over.width - 4) < 0.5)
    }

    @Test("an empty outline yields an empty path rather than a crash")
    func empty() {
        #expect(PathMorph(from: Path(), to: tall).path(at: 0.5, in: rect, viewBox: box).isEmpty)
        #expect(PathMorph(from: square, to: Path()).path(at: 0.5, in: rect, viewBox: box).isEmpty)
    }

    @Test("the pen and the tick morph without going flat")
    func penToTick() {
        // The two outlines this was written for. The pen is long and thin on a diagonal and
        // the tick is a different long thin diagonal, which is exactly the case where two
        // rings that are not lined up produce a mess.
        let pen = SVGPath.path(
            """
            M3.78181 16.3092L3 21L7.69086 20.2182C8.50544 20.0825 9.25725 19.6956 9.84119 \
            19.1116L20.4198 8.53288C21.1934 7.75922 21.1934 6.5049 20.4197 5.73126L18.2687 \
            3.58024C17.495 2.80658 16.2406 2.80659 15.4669 3.58027L4.88841 14.159C4.30447 \
            14.7429 3.91757 15.4947 3.78181 16.3092Z
            """
        )
        let tick = SVGPath.path(
            "M7.959 20.513L1.592 12.872L3.128 11.592L8.041 17.487L20.947 3.587L22.413 4.948L7.959 20.513Z"
        )
        let morph = PathMorph(from: pen, to: tick)

        for step in stride(from: 0.0, through: 1.0, by: 0.1) {
            let bounds = morph.path(at: step, in: rect, viewBox: box).boundingRect
            #expect(bounds.width > 8, "the mark went flat at \(step)")
            #expect(bounds.height > 8, "the mark went flat at \(step)")
        }
    }
}

@Suite("Duration fields")
struct DurationClampTests {
    @Test("a number inside the range is left alone")
    func withinRange() {
        #expect(durationClamp(3, max: 24) == 3)
        #expect(durationClamp(0, max: 24) == 0)
        #expect(durationClamp(24, max: 24) == 24)
    }

    @Test("a number outside it is brought back in")
    func outsideRange() {
        #expect(durationClamp(99, max: 24) == 24)
        #expect(durationClamp(-5, max: 24) == 0)
    }

    @Test("the two fields have their own limits")
    func separateLimits() {
        #expect(durationClamp(45, max: 24) == 24)
        #expect(durationClamp(45, max: 60) == 45)
    }
}
