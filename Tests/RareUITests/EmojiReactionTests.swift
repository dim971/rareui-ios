//
//  EmojiReactionTests.swift
//  The burst is six values animating at once on different schedules, which is exactly the
//  kind of thing that is wrong by a frame and stays wrong. Checked against
//  `components/ui/emoji-reaction.tsx`.
//

import CoreGraphics
@testable import RareUI
import Testing

@Suite("Keyframe tracks")
struct EmojiKeyframeTests {
    private let linear = CubicBezier(0, 0, 1, 1)

    @Test("a track starts on its first value and finishes on its last")
    func endpoints() {
        let values = [0.0, 1, 1, 0]
        let times = [0.0, 0.03, 0.7, 1]
        #expect(emojiKeyframe(values, times: times, at: 0, ease: linear) == 0)
        #expect(emojiKeyframe(values, times: times, at: 1, ease: linear) == 0)
    }

    @Test("it holds the value between two keyframes that share it")
    func plateau() {
        // The opacity track is nothing, then fully on, then held, then nothing. The held
        // stretch is most of the flight and has to stay solid throughout.
        let opacity = [0.0, 1, 1, 0]
        let times = [0.0, 0.03, 0.7, 1]
        for step in stride(from: 0.05, through: 0.65, by: 0.05) {
            #expect(emojiKeyframe(opacity, times: times, at: step, ease: linear) == 1)
        }
    }

    @Test("the easing is applied between one keyframe and the next, not across the track")
    func easedPerSegment() {
        // Halfway between the first two keyframes of a two point track, an ease out is
        // already past the middle.
        let easeOut = CubicBezier(0, 0, 0.58, 1)
        let value = emojiKeyframe([0, 1], times: [0, 1], at: 0.5, ease: easeOut)
        #expect(value > 0.5)
    }

    @Test("progress outside the track's own times is held at the ends")
    func clamped() {
        // The blur track does not start until twelve percent of the way through.
        let blur = [0.0, 0, 8]
        let times = [0.0, 0.12, 1]
        #expect(emojiKeyframe(blur, times: times, at: 0.05, ease: linear) == 0)
        #expect(emojiKeyframe(blur, times: times, at: 2, ease: linear) == 8)
        #expect(emojiKeyframe(blur, times: times, at: -1, ease: linear) == 0)
    }

    @Test("two keyframes at the same moment are a step rather than a division by nothing")
    func stepChange() {
        // A zero length segment has no progress to divide by. The value steps across it
        // instead, and nothing downstream ever sees a NaN.
        let values = [0.0, 1, 2, 3]
        let times = [0.0, 0.5, 0.5, 1]
        for step in stride(from: 0.0, through: 1.0, by: 0.05) {
            let value = emojiKeyframe(values, times: times, at: step, ease: linear)
            #expect(value.isFinite, "the track went to nothing at \(step)")
        }
        #expect(emojiKeyframe(values, times: times, at: 0.4, ease: linear) < 1)
        #expect(emojiKeyframe(values, times: times, at: 0.6, ease: linear) > 2)
    }

    @Test("a track that does not make sense yields its first value rather than trapping")
    func mismatched() {
        #expect(emojiKeyframe([5], times: [0], at: 0.5, ease: linear) == 5)
        #expect(emojiKeyframe([1, 2], times: [0], at: 0.5, ease: linear) == 1)
        #expect(emojiKeyframe([], times: [], at: 0.5, ease: linear) == 0)
    }
}

@Suite("Emoji burst")
struct EmojiBurstTests {
    @Test("a burst is five copies leaving a quarter of a second apart")
    func shape() {
        var generator = SystemRandomNumberGenerator()
        let burst = EmojiParticle.burst(
            glyph: "\u{1F389}",
            seed: 0,
            origin: .zero,
            using: &generator
        )
        #expect(burst.count == emojiBurstCount)
        #expect(burst.map(\.delay) == [0, 0.25, 0.5, 0.75, 1])
        #expect(Set(burst.map(\.id)).count == burst.count, "each copy needs its own identity")
    }

    @Test("every copy stays inside the bounds upstream's ranges allow")
    func withinRanges() {
        var generator = SystemRandomNumberGenerator()
        for seed in stride(from: 0, to: 400, by: emojiBurstCount) {
            let burst = EmojiParticle.burst(
                glyph: "\u{1F525}",
                seed: seed,
                origin: CGPoint(x: 10, y: 20),
                using: &generator
            )
            for particle in burst {
                #expect(abs(particle.launch) <= emojiLaunchSpread)
                #expect(abs(particle.drift) <= emojiClimbSpread)
                #expect(abs(particle.tilt) >= 1 && abs(particle.tilt) <= 4)
                #expect(particle.travel >= emojiRise * 0.86 && particle.travel <= emojiRise)
                #expect(particle.scale >= 0.78 && particle.scale <= 1.05)
                #expect(particle.blurRatio >= 0.18 && particle.blurRatio <= 0.3)
                #expect(particle.fadeAt >= 0.55 && particle.fadeAt <= 0.88)
                #expect(particle.duration >= 1.4 && particle.duration <= 1.8)
            }
        }
    }

    @Test("a copy leans the same way it wanders, rather than fighting itself")
    func laneAgreement() {
        // One random number decides the side, so the sideways launch and the climb drift
        // always share a sign. Two independent draws would make copies that set off one
        // way and then come back across the bar.
        var generator = SystemRandomNumberGenerator()
        for seed in stride(from: 0, to: 200, by: emojiBurstCount) {
            for particle in EmojiParticle.burst(
                glyph: "\u{1F44B}", seed: seed, origin: .zero, using: &generator
            ) where particle.launch != 0 {
                #expect(particle.launch.sign == particle.drift.sign)
                #expect(particle.launch.sign == particle.tilt.sign)
            }
        }
    }

    @Test("the identifiers march forward, so a held reaction never reuses one")
    func identifiers() {
        var generator = SystemRandomNumberGenerator()
        let first = EmojiParticle.burst(glyph: "a", seed: 0, origin: .zero, using: &generator)
        let second = EmojiParticle.burst(
            glyph: "a", seed: emojiBurstCount, origin: .zero, using: &generator
        )
        #expect(Set(first.map(\.id)).isDisjoint(with: Set(second.map(\.id))))
    }
}
