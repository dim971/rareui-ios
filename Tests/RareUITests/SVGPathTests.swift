//
//  SVGPathTests.swift
//  The parser is what lets the icons in this library be quotations of upstream's SVG
//  rather than translations of it, so it had better read the same shapes.
//

import CoreGraphics
@testable import RareUI
import SwiftUI
import Testing

@Suite("SVG path reading")
struct SVGPathTests {
    private func bounds(_ d: String) -> CGRect {
        SVGPath.path(d).boundingRect
    }

    @Test("a move and a line make a line")
    func line() {
        let box = bounds("M0 0L10 20")
        #expect(box.minX == 0 && box.minY == 0)
        #expect(box.maxX == 10 && box.maxY == 20)
    }

    @Test("separators are optional wherever the meaning is clear")
    func separators() {
        // These are the same path written four ways, which is normal in generated SVG.
        let forms = ["M0 0L10 10", "M 0 0 L 10 10", "M0,0L10,10", "M0 0 L10 10"]
        let shapes = forms.map { SVGPath.path($0).description }
        #expect(Set(shapes).count == 1, "the four spellings should read as one path")
    }

    @Test("a minus sign is its own separator")
    func negativeNumbers() {
        let box = bounds("M0 0L-10-20")
        #expect(box.minX == -10)
        #expect(box.minY == -20)
    }

    @Test("relative commands carry on from where the last one left off")
    func relative() {
        // Three relative steps of ten each end up at thirty.
        #expect(bounds("M0 0l10 0l10 0l10 0").maxX == 30)
        // The absolute spelling of the same walk.
        #expect(bounds("M0 0L10 0L20 0L30 0").maxX == 30)
    }

    @Test("horizontal and vertical lines take one number")
    func horizontalAndVertical() {
        let box = bounds("M0 0H10V20H0Z")
        #expect(box.width == 10)
        #expect(box.height == 20)
    }

    @Test("a move with extra numbers continues as lines, as the specification says")
    func impliedLines() {
        // The second and third pairs after an M are an L, not three separate moves.
        #expect(bounds("M0 0 10 0 10 10").maxX == 10)
        #expect(bounds("M0 0 10 0 10 10").maxY == 10)
    }

    @Test("a closed subpath returns to where it started")
    func close() {
        // After Z the pen is back at the subpath's start, so the relative line that
        // follows goes right from the origin rather than from the last corner.
        let box = bounds("M0 0H10V10H0Zl5 0")
        #expect(box.maxX == 10)
        #expect(box.minX == 0)
    }

    @Test("cubic curves stay inside the box their control points describe")
    func cubic() {
        let box = bounds("M0 0C0 10 10 10 10 0")
        #expect(box.minY >= 0)
        #expect(box.maxY <= 10)
        #expect(box.maxX == 10)
    }

    @Test("an arc bulges out to its radius")
    func arc() {
        // A half circle of radius five, from the origin across to ten.
        let box = bounds("M0 0A5 5 0 0 1 10 0")
        #expect(abs(box.width - 10) < 1e-6)
        #expect(abs(box.height - 5) < 1e-6)
    }

    @Test("the arc's two flags parse without a separator between them")
    func arcFlags() {
        // `0 1` and `01` are the same thing, and reading them as ordinary numbers would
        // swallow both at once and shift every coordinate after them.
        let spaced = SVGPath.path("M0 0A5 5 0 0 1 10 0").boundingRect
        let packed = SVGPath.path("M0 0A5 5 0 01 10 0").boundingRect
        #expect(abs(spaced.width - packed.width) < 1e-9)
        #expect(abs(spaced.height - packed.height) < 1e-9)
    }

    @Test("an arc with a radius too small to reach is grown until it can")
    func arcTooSmall() {
        // The specification says to scale the radii up rather than leave the arc undefined.
        #expect(!SVGPath.path("M0 0A1 1 0 0 1 10 0").isEmpty)
    }

    @Test("a zero radius is a straight line")
    func degenerateArc() {
        #expect(abs(bounds("M0 0A0 0 0 0 1 10 0").height) < 1e-9)
    }

    @Test("the bell upstream draws reads at the size it was drawn for")
    func theBell() {
        // Both halves of the bell, quoted from `notification-bell.tsx`, in its 18 by 18 box.
        let body = SVGPath.path(
            """
            M3.5 6.5C3.5 3.46279 5.96279 1 9 1C12.0372 1 14.5 3.46279 14.5 6.5V10.75C14.5 \
            11.4408 15.0592 12 15.75 12C16.1642 12 16.5 12.3358 16.5 12.75C16.5 13.1642 \
            16.1642 13.5 15.75 13.5H2.25C1.83579 13.5 1.5 13.1642 1.5 12.75C1.5 12.3358 \
            1.83579 12 2.25 12C2.94079 12 3.5 11.4408 3.5 10.75V6.5Z
            """
        )
        let box = body.boundingRect
        #expect(box.minX >= 0 && box.maxX <= 18)
        #expect(box.minY >= 0 && box.maxY <= 18)
        #expect(box.width > 14, "the bell should fill most of its box")
    }

    @Test("data that stops early yields the part that was readable")
    func truncated() {
        // A shape that stops short is visible on screen; a blank space is not, and a typo
        // that produces nothing at all is much harder to find.
        #expect(!SVGPath.path("M0 0L10 10L20").isEmpty)
        #expect(SVGPath.path("").isEmpty)
        #expect(SVGPath.path("nonsense").isEmpty)
    }
}
