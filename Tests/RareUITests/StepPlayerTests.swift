//
//  StepPlayerTests.swift
//  The proportions and the morph, checked against `components/ui/step-player.tsx`.
//

import CoreGraphics
@testable import RareUI
import Testing

@Suite("Step player proportions")
struct StepPlayerMetricsTests {
    @Test("everything is derived from the one size the caller gives")
    func derived() {
        let metrics = StepPlayerMetrics(size: 48)
        #expect(metrics.track == 48)
        #expect(metrics.dot == 6)
        #expect(metrics.bar == 49)
        #expect(metrics.gap == 9)
        #expect(metrics.pad == 21)
        #expect(metrics.icon == 31)
    }

    @Test("the proportions hold at any size")
    func scales() {
        for size in [16.0, 24, 32, 48, 64, 120] {
            let metrics = StepPlayerMetrics(size: size)
            #expect(metrics.bar > metrics.dot, "the active step must be longer than a dot")
            #expect(metrics.icon < metrics.track, "the glyph has to fit in its button")
            #expect(metrics.dot <= metrics.track)
            // The padding is the same inset the dot leaves above and below it, so the row
            // sits in the middle of the track.
            #expect(abs(metrics.pad * 2 + metrics.dot - metrics.track) <= 1)
        }
    }

    @Test("a track too small to draw is grown to something that can be")
    func floors() {
        let tiny = StepPlayerMetrics(size: 1)
        #expect(tiny.track == 12)
        #expect(tiny.dot >= 2)
        #expect(tiny.gap >= 2)
    }
}

@Suite("Transport morph")
struct TransportShapeTests {
    private let box = CGRect(x: 0, y: 0, width: 24, height: 24)

    @Test("at nothing it is the pause bars, at everything it is the play triangle")
    func endpoints() {
        let pause = TransportShape(morph: 0).path(in: box).boundingRect
        let play = TransportShape(morph: 1).path(in: box).boundingRect

        // The pause bars run from 8.4 to 15.6 and are taller than they are wide together.
        #expect(abs(pause.minX - 8.4) < 1e-6)
        #expect(abs(pause.maxX - 15.6) < 1e-6)
        #expect(abs(pause.minY - 5.9) < 1e-6)
        #expect(abs(pause.maxY - 18.1) < 1e-6)

        // The triangle runs from 9.8 out to its point at 17.7.
        #expect(abs(play.minX - 9.8) < 1e-6)
        #expect(abs(play.maxX - 17.7) < 1e-6)
        #expect(abs(play.minY - 7) < 1e-6)
        #expect(abs(play.maxY - 17) < 1e-6)
    }

    @Test("the shape stays inside its own box the whole way across")
    func staysInside() {
        for step in stride(from: 0.0, through: 1.0, by: 0.05) {
            let bounds = TransportShape(morph: step).path(in: box).boundingRect
            #expect(bounds.minX >= 8.4 - 1e-6)
            #expect(bounds.maxX <= 17.7 + 1e-6)
            #expect(bounds.minY >= 5.9 - 1e-6)
            #expect(bounds.maxY <= 18.1 + 1e-6)
        }
    }

    @Test("the morph moves the whole way rather than jumping at one end")
    func continuous() {
        // Each corner travels at a constant rate, so the width changes smoothly rather
        // than sitting still and then snapping.
        var previous = TransportShape(morph: 0).path(in: box).boundingRect
        for step in stride(from: 0.05, through: 1.0, by: 0.05) {
            let bounds = TransportShape(morph: step).path(in: box).boundingRect
            #expect(abs(bounds.maxX - previous.maxX) < 0.5, "the point moved too far in one step")
            previous = bounds
        }
    }

    @Test("progress outside the range is held at the ends rather than extrapolated")
    func clamped() {
        let under = TransportShape(morph: -1).path(in: box).boundingRect
        let over = TransportShape(morph: 2).path(in: box).boundingRect
        #expect(abs(under.minX - 8.4) < 1e-6)
        #expect(abs(over.maxX - 17.7) < 1e-6)
    }

    @Test("the morph is the shape's animatable value")
    func animatable() {
        var shape = TransportShape(morph: 0)
        #expect(shape.animatableData == 0)
        shape.animatableData = 0.5
        #expect(shape.morph == 0.5)
    }
}
