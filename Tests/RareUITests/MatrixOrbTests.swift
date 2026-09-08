//
//  MatrixOrbTests.swift
//  The orb is a field function painted once per frame, so the field is what is worth
//  testing: its range, its continuity, and the fact that a state change crossfades rather
//  than cutting. Checked against `components/ui/matrix-orb.tsx`.
//

import Foundation
@testable import RareUI
import Testing

@Suite("Matrix orb envelope")
struct MatrixOrbEnvelopeTests {
    @Test("the synthesised level stays inside the range upstream's constants allow")
    func range() {
        for step in 0 ... 4000 {
            let level = matrixOrbEnvelope(Double(step) / 100)
            #expect(level >= 0.22 - 1e-12, "fell below the floor at \(step)")
            #expect(level <= 1 + 1e-12, "went above one at \(step)")
        }
    }

    @Test("it never has a corner, which is why it reads as breathing rather than snapping")
    func smooth() {
        // Upstream chose two multiplied sines over the absolute value of one precisely to
        // avoid a corner at each trough. A corner would show up as a step change in the
        // slope, so the slope is sampled and its own change is bounded.
        var previousSlope: Double?
        let step = 0.001
        for index in 0 ..< 20000 {
            let time = Double(index) * step
            let slope = (matrixOrbEnvelope(time + step) - matrixOrbEnvelope(time)) / step
            if let previousSlope {
                #expect(abs(slope - previousSlope) < 0.01, "the slope jumped at t = \(time)")
            }
            previousSlope = slope
        }
    }

    @Test("the two waves do not share a period, so the breath does not visibly repeat")
    func aperiodic() {
        // 0.62 and 1.9 radians per second: their ratio is not a simple fraction, so the
        // pattern takes a very long time to come back round.
        #expect(matrixOrbEnvelope(0) != matrixOrbEnvelope(2 * .pi / 0.62))
    }
}

@Suite("Matrix orb intensity")
struct MatrixOrbIntensityTests {
    @Test("idle breathes around a constant, within the amount upstream allows")
    func idle() {
        for step in 0 ... 2000 {
            let value = matrixOrbIntensity(
                .idle,
                distance: 0.5,
                normalisedX: 0.5,
                normalisedY: 0,
                time: Double(step) / 50,
                amplitude: 1
            )
            #expect(abs(value - 0.62) <= 0.12 + 1e-12)
        }
    }

    @Test("idle ignores the level, because there is nothing to listen to")
    func idleIgnoresLevel() {
        let quiet = matrixOrbIntensity(
            .idle, distance: 0.3, normalisedX: 0.3, normalisedY: 0, time: 1, amplitude: 0
        )
        let loud = matrixOrbIntensity(
            .idle, distance: 0.3, normalisedX: 0.3, normalisedY: 0, time: 1, amplitude: 1
        )
        #expect(quiet == loud)
    }

    @Test("listening sits at its floor in silence and rises with the level")
    func listening() {
        let silent = matrixOrbIntensity(
            .listening, distance: 0.4, normalisedX: 0.4, normalisedY: 0, time: 2, amplitude: 0
        )
        #expect(abs(silent - 0.32) < 1e-12)

        let loud = matrixOrbIntensity(
            .listening, distance: 0.4, normalisedX: 0.4, normalisedY: 0, time: 2, amplitude: 1
        )
        #expect(loud > silent)
        // 0.32 plus at most 0.34 + 0.38.
        #expect(loud <= 1.04 + 1e-12)
    }

    @Test("listening ripples outward rather than pulsing all at once")
    func ripple() {
        // The phase depends on distance, so two dots at different radii are not in step.
        let near = matrixOrbIntensity(
            .listening, distance: 0.2, normalisedX: 0.2, normalisedY: 0, time: 1, amplitude: 1
        )
        let far = matrixOrbIntensity(
            .listening, distance: 0.9, normalisedX: 0.9, normalisedY: 0, time: 1, amplitude: 1
        )
        #expect(near != far)
    }

    @Test("thinking is brightest where an orbiter is and dimmest far from all three")
    func thinking() {
        // At t = 0 the first orbiter sits at (0.62, 0), being at phase 0 and radius 0.62.
        let onTop = matrixOrbIntensity(
            .thinking, distance: 0.62, normalisedX: 0.62, normalisedY: 0, time: 0, amplitude: 1
        )
        let away = matrixOrbIntensity(
            .thinking, distance: 1, normalisedX: -0.7, normalisedY: -0.7, time: 0, amplitude: 1
        )
        #expect(onTop > away)
        #expect(away >= 0.26)
        // 0.26 plus 0.8 of a heat that is itself capped at one.
        #expect(onTop <= 1.06 + 1e-12)
    }
}

@Suite("Matrix orb state blending")
struct MatrixOrbWeightsTests {
    @Test("a fresh set of weights shows exactly one state")
    func fresh() {
        let weights = MatrixOrbWeights(showing: .listening)
        #expect(weights.listening == 1)
        #expect(weights.idle == 0)
        #expect(weights.thinking == 0)
    }

    @Test("blending converges on the state it is aimed at")
    func converges() {
        var weights = MatrixOrbWeights(showing: .idle)
        // A second of sixtieths, at upstream's blend rate.
        for _ in 0 ..< 60 {
            weights.blend(toward: .thinking, step: matrixOrbBlend)
        }
        #expect(weights.thinking > 0.99)
        #expect(weights.idle < 0.01)
    }

    @Test("an interrupted change carries on from where it is, not from where it started")
    func interrupted() {
        var weights = MatrixOrbWeights(showing: .idle)
        for _ in 0 ..< 5 {
            weights.blend(toward: .listening, step: matrixOrbBlend)
        }
        let partway = weights.listening
        #expect(partway > 0 && partway < 1, "the change should be mid flight")

        // Changing course now: listening still has weight, and it decays from where it is
        // rather than being cut to zero.
        weights.blend(toward: .thinking, step: matrixOrbBlend)
        #expect(weights.listening < partway)
        #expect(weights.listening > 0)
        #expect(weights.thinking > 0)
    }

    @Test("the weights always sum to one, so brightness does not dip during a change")
    func conserved() {
        var weights = MatrixOrbWeights(showing: .idle)
        for step in 0 ..< 120 {
            weights.blend(toward: step < 60 ? .listening : .thinking, step: matrixOrbBlend)
            let total = weights.idle + weights.listening + weights.thinking
            #expect(abs(total - 1) < 1e-9, "the weights summed to \(total)")
        }
    }
}

@Suite("Matrix orb resting sizes")
struct MatrixOrbScaleTests {
    @Test("each state has its own resting size, and listening is the largest")
    func scales() {
        #expect(matrixOrbScale(.idle) == 0.88)
        #expect(matrixOrbScale(.listening) == 1)
        #expect(matrixOrbScale(.thinking) == 0.92)
        #expect(matrixOrbScale(.listening) > matrixOrbScale(.thinking))
        #expect(matrixOrbScale(.thinking) > matrixOrbScale(.idle))
    }

    @Test("the spring is underdamped, so the orb overshoots on its way between sizes")
    func underdamped() {
        // Critical damping for this spring would be 2 * sqrt(stiffness * mass), with mass
        // one: about 26.8. Upstream's 26 is just below that, which is what gives the size
        // change its slight overshoot rather than a dead stop.
        let critical = 2 * matrixOrbStiffness.squareRoot()
        #expect(matrixOrbDamping < critical)
        #expect(matrixOrbDamping > critical * 0.9, "it should be only just underdamped")
    }

    @Test("the amplitude rises faster than it falls")
    func attackAndRelease() {
        #expect(matrixOrbAttack > matrixOrbRelease)
    }
}
