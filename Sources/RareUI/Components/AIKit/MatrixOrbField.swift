//
//  MatrixOrbField.swift
//  The maths behind MatrixOrb, ported from the `envelope` and `intensityOf` functions
//  and the frame loop in upstream's `components/ui/matrix-orb.tsx`.
//
//  All of it is pure: given a state, a dot's position and a time, it says how bright that
//  dot should be. The view does nothing but paint the answers.
//

import Foundation

/// What the orb is doing.
public enum MatrixOrbState: String, Sendable, CaseIterable {
    /// Waiting. A slow breath travels out from the middle.
    case idle
    /// Taking something in. Rings ripple outward in time with the level.
    case listening
    /// Working on something. Three hot spots orbit under the dots.
    case thinking
}

/// The size the orb settles at in each state.
///
/// Idle sits back, listening comes forward, thinking is between the two. The change is
/// carried by a spring rather than a transition, so the orb overshoots slightly on its
/// way between them.
func matrixOrbScale(_ state: MatrixOrbState) -> Double {
    switch state {
    case .idle: 0.88
    case .listening: 1
    case .thinking: 0.92
    }
}

/// The spring that carries the orb between its resting sizes.
let matrixOrbStiffness = 180.0
/// The damping on that spring.
let matrixOrbDamping = 26.0
/// How fast the amplitude follows a level that is rising.
let matrixOrbAttack = 0.22
/// How fast it follows one that is falling. Slower than the attack, so the orb holds a
/// peak for a moment rather than snapping back the instant a sound stops.
let matrixOrbRelease = 0.08
/// How fast one state's influence gives way to another's, per sixtieth of a second.
let matrixOrbBlend = 0.16

/// One of the three hot spots that circle under the dots while the orb is thinking.
struct MatrixOrbOrbiter {
    /// How far from the middle it orbits, in normalised units where the edge is 1.
    let radius: Double
    /// How fast it goes round, in radians per second. A negative speed goes the other way.
    let speed: Double
    /// Where on its circle it starts.
    let phase: Double
    /// How wide its glow is.
    let spread: Double
}

/// The three orbiters, at radii, speeds and phases that do not share a common period.
///
/// That is the point of them: with one turning backward and none of the three in step,
/// the pattern never visibly repeats, so the orb reads as thinking rather than looping.
let matrixOrbOrbiters = [
    MatrixOrbOrbiter(radius: 0.62, speed: 2.2, phase: 0, spread: 0.42),
    MatrixOrbOrbiter(radius: 0.4, speed: -1.7, phase: 2.1, spread: 0.36),
    MatrixOrbOrbiter(radius: 0.8, speed: 1.15, phase: 4, spread: 0.34)
]

/// A stand in for a microphone level, for when the caller has no real one to give.
///
/// Two sine waves of unrelated periods, multiplied. Upstream notes that taking the
/// absolute value of a single wave instead would put a corner at every trough, and a
/// corner reads as a snap rather than as breathing.
///
/// - Parameter time: Seconds since the orb started animating.
/// - Returns: A level in `0.22...1`.
func matrixOrbEnvelope(_ time: Double) -> Double {
    let slow = 0.5 + 0.5 * sin(time * 0.62 + 0.4)
    let fast = 0.5 + 0.5 * sin(time * 1.9 + 1.1)
    return 0.22 + 0.78 * (0.45 + 0.55 * slow) * fast
}

/// How bright one dot should be, for one state, at one moment.
///
/// - Parameters:
///   - state: The state being asked about, which is not necessarily the orb's current
///     one: while it changes, every state that still has weight is asked and the answers
///     are mixed.
///   - distance: The dot's distance from the middle, where the edge of the circle is 1.
///   - normalisedX: The dot's x position, in `-1...1`.
///   - normalisedY: The dot's y position, in `-1...1`.
///   - time: Seconds since the orb started animating.
///   - amplitude: The smoothed level, in `0...1`.
/// - Returns: A brightness, before it is confined to `0...1`.
func matrixOrbIntensity(
    _ state: MatrixOrbState,
    distance: Double,
    normalisedX: Double,
    normalisedY: Double,
    time: Double,
    amplitude: Double
) -> Double {
    switch state {
    case .listening:
        // A ring travelling outward: the phase depends on distance, so the whole field
        // does not pulse at once.
        let ripple = 0.5 + 0.5 * sin(distance * 4.2 - time * 3)
        return 0.32 + amplitude * (0.34 + 0.38 * ripple)

    case .thinking:
        var heat = 0.0
        for orbiter in matrixOrbOrbiters {
            let angle = time * orbiter.speed + orbiter.phase
            let dx = normalisedX - cos(angle) * orbiter.radius
            let dy = normalisedY - sin(angle) * orbiter.radius
            heat += exp(-(dx * dx + dy * dy) / (orbiter.spread * orbiter.spread))
        }
        return 0.26 + 0.8 * min(1, heat)

    case .idle:
        // A slow breath, travelling inward rather than outward.
        return 0.62 + 0.12 * sin(time * 1.05 - distance * 2.4)
    }
}

/// How much of each state is currently showing.
///
/// The orb does not switch states, it crossfades between them, so interrupting a change
/// halfway blends from whatever is on screen rather than from where the change started.
struct MatrixOrbWeights: Equatable {
    var idle: Double
    var listening: Double
    var thinking: Double

    init(showing state: MatrixOrbState) {
        idle = state == .idle ? 1 : 0
        listening = state == .listening ? 1 : 0
        thinking = state == .thinking ? 1 : 0
    }

    subscript(state: MatrixOrbState) -> Double {
        get {
            switch state {
            case .idle: idle
            case .listening: listening
            case .thinking: thinking
            }
        }
        set {
            switch state {
            case .idle: idle = newValue
            case .listening: listening = newValue
            case .thinking: thinking = newValue
            }
        }
    }

    /// Moves each weight a step toward showing only `state`.
    ///
    /// - Parameters:
    ///   - state: The state being moved toward.
    ///   - step: How far to move, in `0...1`.
    mutating func blend(toward state: MatrixOrbState, step: Double) {
        for candidate in MatrixOrbState.allCases {
            self[candidate] += ((candidate == state ? 1 : 0) - self[candidate]) * step
        }
    }
}

/// Everything the painter needs for one frame.
struct MatrixOrbFrame: Equatable {
    let time: Double
    let amplitude: Double
    let scale: Double
    let weights: MatrixOrbWeights
}
