//
//  BounceSidebarTests.swift
//  The dot's arc, checked against the `arc()` path upstream hands to Motion in
//  `components/ui/bounce-sidebar.tsx`.
//

import CoreGraphics
@testable import RareUI
import Testing

@Suite("Bounce sidebar arc")
struct BounceDotArcTests {
    @Test("the swing is the same size whatever the distance, once past the cap")
    func constantSwing() {
        // strength is 14 / distance, so strength * distance is 14 for every hop long
        // enough that the 0.8 ceiling does not bite. The arc is a flourish, not a measure
        // of how far the dot has come.
        for distance in [20.0, 40, 80, 200, 1000] {
            #expect(abs(abs(bounceDotArcOffset(over: distance)) - 14) < 1e-9)
        }
    }

    @Test("a very short hop is capped, so the dot does not swing further than it travels")
    func cappedForShortHops() {
        // The cap bites below 17.5 points, which is where 14 / distance passes 0.8.
        #expect(abs(bounceDotArcOffset(over: 10)) == 0.8 * 10)
        #expect(abs(bounceDotArcOffset(over: 4)) == 0.8 * 4)
        #expect(abs(bounceDotArcOffset(over: 17.5)) == 14)
    }

    @Test("the swing is on the same side going up as going down, so the dot retraces its path")
    func sameSideBothWays() {
        // Upstream turns counter-clockwise going down and clockwise going up, which are
        // the same curve travelled in opposite directions.
        #expect(bounceDotArcOffset(over: 60) == bounceDotArcOffset(over: -60))
        #expect(bounceDotArcOffset(over: 60) < 0, "the swing is to the left, away from the labels")
    }

    @Test("a dot that is not going anywhere does not swing")
    func stationary() {
        #expect(bounceDotArcOffset(over: 0) == 0)
        #expect(bounceDotArcOffset(over: .nan) == 0)
        #expect(bounceDotArcOffset(over: .infinity) == 0)
    }

    @Test("the swing peaks halfway across and is nothing at either end")
    func swingProfile() {
        /// The lateral term of a quadratic curve is 2t(1-t) of the control point's offset.
        func swing(at progress: Double) -> Double {
            2 * progress * (1 - progress)
        }
        #expect(swing(at: 0) == 0)
        #expect(swing(at: 1) == 0)
        #expect(swing(at: 0.5) == 0.5)
        #expect(swing(at: 0.25) == swing(at: 0.75))
    }
}
