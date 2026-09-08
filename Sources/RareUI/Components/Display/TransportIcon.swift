//
//  TransportIcon.swift
//  The play, pause and replay glyphs on StepPlayer, ported from the `TransportIcon`
//  component in upstream's `components/ui/step-player.tsx`.
//
//  Upstream morphs play into pause with flubber, which matches the vertices of two
//  arbitrary paths and interpolates between them. There is no such thing on this platform
//  and there does not need to be: these two shapes are a triangle and a pair of bars, and
//  splitting the triangle down its middle gives two quadrilaterals that correspond to the
//  two bars corner for corner. Interpolating those is exact rather than approximate, and it
//  is what flubber would have arrived at anyway.
//
//  Replay is left out of it, exactly as upstream leaves it out: there is no sensible vertex
//  match between an arrow curled into a circle and either of the others, so it crossfades.
//

import SwiftUI

/// The play triangle and the pause bars, and everything between them.
///
/// At zero it is the pause bars and at one it is the play triangle, both quoted from
/// upstream's own path data.
struct TransportShape: Shape {
    /// How far along the morph is: `0` is pause, `1` is play.
    var morph: Double

    /// The icon's own box, from upstream's `viewBox="0 0 24 24"`.
    private static let box = 24.0

    /// The left bar of the pause icon, `M8.4 5.9 L10.4 5.9 L10.4 18.1 L8.4 18.1 Z`.
    private static let pauseLeft = [
        CGPoint(x: 8.4, y: 5.9), CGPoint(x: 10.4, y: 5.9),
        CGPoint(x: 10.4, y: 18.1), CGPoint(x: 8.4, y: 18.1)
    ]

    /// The right bar, `M13.6 5.9 L15.6 5.9 L15.6 18.1 L13.6 18.1 Z`.
    private static let pauseRight = [
        CGPoint(x: 13.6, y: 5.9), CGPoint(x: 15.6, y: 5.9),
        CGPoint(x: 15.6, y: 18.1), CGPoint(x: 13.6, y: 18.1)
    ]

    /// The left half of the play triangle `M9.8 7 L17.7 12 L9.8 17 Z`, cut down its middle.
    private static let playLeft = [
        CGPoint(x: 9.8, y: 7), CGPoint(x: 13.75, y: 9.5),
        CGPoint(x: 13.75, y: 14.5), CGPoint(x: 9.8, y: 17)
    ]

    /// The right half, which is the tip. Two of its corners meet at the point, which is how
    /// a four cornered shape becomes a three cornered one without a seam.
    private static let playRight = [
        CGPoint(x: 13.75, y: 9.5), CGPoint(x: 17.7, y: 12),
        CGPoint(x: 17.7, y: 12), CGPoint(x: 13.75, y: 14.5)
    ]

    var animatableData: Double {
        get { morph }
        set { morph = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / Self.box
        let t = min(1, max(0, morph))

        var path = Path()
        path.addLines(quad(Self.pauseLeft, Self.playLeft, at: t, scale: scale, in: rect))
        path.closeSubpath()
        path.addLines(quad(Self.pauseRight, Self.playRight, at: t, scale: scale, in: rect))
        path.closeSubpath()
        return path
    }

    private func quad(
        _ from: [CGPoint],
        _ to: [CGPoint],
        at t: Double,
        scale: Double,
        in rect: CGRect
    ) -> [CGPoint] {
        zip(from, to).map { start, end in
            CGPoint(
                x: rect.minX + (start.x + (end.x - start.x) * t) * scale,
                y: rect.minY + (start.y + (end.y - start.y) * t) * scale
            )
        }
    }
}

/// The replay arrow, quoted from upstream's `REPLAY_PATH`: an arc most of the way round a
/// circle with an arrowhead turning back into it.
struct ReplayShape: Shape {
    func path(in rect: CGRect) -> Path {
        SVGShape(
            """
            M17.44 6.56 A7.7 7.7 0 1 1 10.66 4.42 L10.32 2.45 L14.86 4.59 L11.32 8.16 \
            L10.91 5.8 A6.3 6.3 0 1 0 16.45 7.55 Z
            """,
            viewBox: CGSize(width: 24, height: 24)
        )
        .path(in: rect)
    }
}
