//
//  EmojiBurst.swift
//  The copies that fly off when an emoji is picked, ported from `makeParticles` and
//  `BurstEmoji` in upstream's `components/ui/emoji-reaction.tsx`.
//
//  Upstream animates six values at once with different keyframe times and different
//  easings on each, all sharing one clock. That is reproduced here by animating a single
//  progress from nothing to everything and reading each value out of it, which is what
//  Motion is doing underneath anyway.
//

import SwiftUI

/// Reads a value out of a keyframe track.
///
/// Motion states a track as a list of values and a list of times to reach them at, with
/// an easing applied between each pair rather than across the whole track. This is that.
///
/// - Parameters:
///   - values: The values, in order.
///   - times: When each is reached, in `0...1`. Must be the same length as `values`.
///   - progress: How far through the animation is, in `0...1`.
///   - ease: The easing applied between one keyframe and the next.
/// - Returns: The value at that point.
func emojiKeyframe(
    _ values: [Double],
    times: [Double],
    at progress: Double,
    ease: CubicBezier
) -> Double {
    guard values.count > 1, values.count == times.count else { return values.first ?? 0 }
    if progress <= times[0] { return values[0] }
    if progress >= times[times.count - 1] { return values[values.count - 1] }

    for index in 0 ..< values.count - 1 where progress <= times[index + 1] {
        let span = times[index + 1] - times[index]
        // Two keyframes at the same time are a step change, not a division by nothing.
        guard span > 0 else { return values[index + 1] }
        let eased = ease((progress - times[index]) / span)
        return values[index] + (values[index + 1] - values[index]) * eased
    }
    return values[values.count - 1]
}

/// One emoji on its way up.
struct EmojiParticle: Identifiable, Equatable {
    let id: Int
    /// The emoji itself.
    let glyph: String
    /// Where in the bar it was launched from.
    let origin: CGPoint
    /// How far to one side it starts, in points.
    let launch: Double
    /// How far it wanders sideways on the way up.
    let drift: Double
    /// How far it turns, in degrees.
    let tilt: Double
    /// How far it rises, in points.
    let travel: Double
    /// The size it settles at, as a multiple of the emoji's own.
    let scale: Double
    /// How blurred it is by the end, as a fraction of its size.
    let blurRatio: Double
    /// When it starts fading out.
    let fadeAt: Double
    /// How long the whole flight takes, in seconds.
    let duration: Double
    /// How long after the burst this one leaves.
    let delay: Double

    /// Makes one burst, five copies leaving a quarter of a second apart.
    ///
    /// - Parameters:
    ///   - glyph: The emoji picked.
    ///   - seed: The first identifier to use.
    ///   - origin: Where in the bar the emoji sits.
    ///   - generator: The source of the randomness, so a test can pin it.
    /// - Returns: The particles.
    static func burst(
        glyph: String,
        seed: Int,
        origin: CGPoint,
        using generator: inout some RandomNumberGenerator
    ) -> [EmojiParticle] {
        (0 ..< emojiBurstCount).map { index in
            // One number decides which side of the bar this copy leans to and how far it
            // wanders, so its launch and its climb agree rather than fighting each other.
            let lane = Double.random(in: -1 ... 1, using: &generator)
            let direction: Double = lane < 0 ? -1 : 1

            return EmojiParticle(
                id: seed + index,
                glyph: glyph,
                origin: origin,
                launch: lane * emojiLaunchSpread,
                drift: lane * emojiClimbSpread,
                tilt: Double.random(in: 1 ... 4, using: &generator) * direction,
                travel: emojiRise * Double.random(in: 0.86 ... 1, using: &generator),
                scale: Double.random(in: 0.78 ... 1.05, using: &generator),
                blurRatio: Double.random(in: 0.18 ... 0.3, using: &generator),
                fadeAt: Double.random(in: 0.55 ... 0.88, using: &generator),
                duration: Double.random(in: 1.4 ... 1.8, using: &generator),
                delay: Double(index) * 0.25
            )
        }
    }
}

/// How many copies leave on each react.
let emojiBurstCount = 5
/// How far up they go, in points.
let emojiRise = 450.0
/// How far to either side they start.
let emojiLaunchSpread = 6.0
/// How far they wander on the way up.
let emojiClimbSpread = 78.0
/// The most that may be in the air at once, so holding a reaction down cannot fill the screen.
let emojiMaxParticles = 60
/// How often a held reaction repeats, in seconds.
let emojiHoldInterval = 0.55

/// Flies one emoji, reading every value out of a single progress.
struct EmojiFlight: ViewModifier, Animatable {
    var progress: Double
    let particle: EmojiParticle
    let size: Double

    /// `ViewModifier` is main actor isolated and `Animatable` is not, so without this the
    /// conformance is rejected as crossing between the two.
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// The rise's own curve, from upstream's `EASE`. A soft ease out that is about two
    /// thirds of the way up by the halfway point, so the emoji is still moving at the end.
    private static let rise = RareUIMotion.easeParticle

    func body(content: Content) -> some View {
        // The climb shares this curve with the rise. Giving it one of its own bends the
        // path sideways, which is what upstream's note about overriding it means.
        let climb = Self.rise(progress)

        return content
            .scaleEffect(
                emojiKeyframe(
                    [0.6, particle.scale * 1.15, particle.scale, particle.scale * 0.75],
                    times: [0, 0.1, 0.22, 1],
                    at: progress,
                    ease: CubicBezier(0, 0, 0.58, 1)
                )
            )
            .rotationEffect(.degrees(emojiKeyframe(
                [0, particle.tilt, -particle.tilt * 0.65, particle.tilt * 0.35],
                times: [0, 0.3, 0.65, 1],
                at: progress,
                ease: CubicBezier(0.42, 0, 0.58, 1)
            )))
            .blur(radius: emojiKeyframe(
                [0, 0, particle.blurRatio * size],
                times: [0, 0.12, 1],
                at: progress,
                ease: Self.rise
            ))
            .opacity(emojiKeyframe(
                [0, 1, 1, 0],
                times: [0, 0.03, particle.fadeAt, 1],
                at: progress,
                ease: CubicBezier(0, 0, 1, 1)
            ))
            .offset(
                x: particle.launch + particle.drift * climb,
                y: -particle.travel * climb
            )
    }
}
