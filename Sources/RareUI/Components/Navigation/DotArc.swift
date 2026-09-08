//
//  DotArc.swift
//  The path BounceSidebar's dot takes, ported from the `arc()` path upstream hands to
//  Motion in `components/ui/bounce-sidebar.tsx`.
//

import SwiftUI

/// How far sideways the dot swings on its way across a given distance.
///
/// Upstream asks Motion for `arc({ strength: min(0.8, 14 / distance) })`. The cap only
/// bites on very short hops; everywhere else the strength is inversely proportional to
/// the distance, so `strength * distance` is a constant 14 and the swing is the same size
/// whether the dot is moving one row or ten. That is the point of it: the arc is a
/// flourish, not a measure of how far the dot has come.
///
/// - Parameter span: The signed distance the dot is travelling, positive downward.
/// - Returns: The control point's sideways offset. Half of it is the widest the swing gets.
func bounceDotArcOffset(over span: Double) -> Double {
    let distance = abs(span)
    guard distance > 0, distance.isFinite else { return 0 }
    let strength = min(0.8, 14 / distance)

    // Upstream turns counter-clockwise going down and clockwise going up, which are the
    // same curve travelled in opposite directions: the dot retraces its own path rather
    // than swinging out on the other side coming back. Both put the swing on the left,
    // away from the labels.
    return -strength * distance
}

/// Moves the dot along that arc.
///
/// The vertical position is the animated value and the sideways offset is derived from
/// it. That works because the arc is a quadratic curve whose control point sits level
/// with the middle of the journey: the vertical component is then exactly linear in the
/// curve's own parameter, so the parameter can be recovered from the height alone.
struct DotArc: ViewModifier, Animatable {
    var y: Double
    let start: Double
    let end: Double
    let live: RareUILiveValue

    /// `ViewModifier` is main actor isolated and `Animatable` is not, so without this the
    /// conformance is rejected as crossing between the two.
    nonisolated var animatableData: Double {
        get { y }
        set { y = newValue }
    }

    func body(content: Content) -> some View {
        live.value = y

        let span = end - start
        // Clamped because an interruption can leave the dot momentarily outside the arc it
        // is being measured against, and an unclamped parameter would throw the swing the
        // wrong way for a frame.
        let progress = abs(span) < 1e-9 ? 1 : min(1, max(0, (y - start) / span))
        let sideways = 2 * progress * (1 - progress) * bounceDotArcOffset(over: span)

        return content.offset(x: sideways, y: y)
    }
}
