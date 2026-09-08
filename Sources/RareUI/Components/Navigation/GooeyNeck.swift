//
//  GooeyNeck.swift
//  The seam between two tiles of GooeyNav, ported from the `neckPath` function in
//  upstream's `components/ui/gooey-nav.tsx`.
//
//  Despite the component's name there is no blur and no colour matrix filter anywhere in
//  this. The seam is an explicitly drawn pair of concave quadratics pinching toward a
//  waist, which is both cheaper than a filter and exactly reproducible.
//

import SwiftUI

/// The nominal height the seam is drawn against before it is stretched to the tile.
///
/// Upstream draws into an SVG viewBox of this height with `preserveAspectRatio="none"`,
/// so the number itself never reaches the screen. It is kept because the waist is
/// expressed as a fraction of it.
let gooeyNeckHeight = 100.0

/// How far the gap can open before the seam has thinned to nothing.
///
/// A fraction of the separation, so a wider nav stretches its seams further before they
/// break rather than snapping at the same absolute distance.
let gooeyNeckBreak = 0.22

/// The waist of the seam at a given gap, in the nominal height's units.
///
/// It starts at the full height when the tiles are touching, and reaches zero at
/// ``gooeyNeckBreak`` of the separation, which is where the seam parts.
///
/// - Parameters:
///   - gap: How far apart the two tiles are, in points.
///   - span: The separation the nav is configured with, in points.
/// - Returns: The waist, or a value at or below zero once the seam has broken.
func gooeyNeckWaist(gap: Double, span: Double) -> Double {
    gooeyNeckHeight * (1 - gap / (span * gooeyNeckBreak))
}

/// The seam drawn in the gap a tile leaves to its left.
///
/// The shape is two concave quadratic curves, one along the top and one along the
/// bottom, whose control points move toward each other as the gap opens. At rest they
/// sit at the edges and the seam is a solid block joining the tiles; fully open they
/// have met in the middle and there is nothing left to draw.
struct GooeyNeck: Shape {
    /// How far apart the two tiles are, in points.
    var gap: Double
    /// The separation the nav is configured with, which is also this shape's width.
    let span: Double

    var animatableData: Double {
        get { gap }
        set { gap = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // A gap that is not a positive number would otherwise emit a path full of
        // nonsense coordinates. Closed seams pull the tiles together instead, so there is
        // nothing to draw here at all.
        guard gap.isFinite, span.isFinite, gap > 0, span > 0 else { return Path() }

        let waist = gooeyNeckWaist(gap: gap, span: span)
        guard waist > 0 else { return Path() }

        // The viewBox is stretched to the tile's height, so the waist scales with it.
        let scale = rect.height / gooeyNeckHeight
        let top = rect.minY
        let bottom = rect.minY + rect.height

        let start = rect.minX + span - gap
        let end = rect.minX + span
        let middle = start + gap / 2

        var path = Path()
        path.move(to: CGPoint(x: start, y: top))
        path.addQuadCurve(
            to: CGPoint(x: end, y: top),
            control: CGPoint(x: middle, y: top + (gooeyNeckHeight - waist) * scale)
        )
        path.addLine(to: CGPoint(x: end, y: bottom))
        path.addQuadCurve(
            to: CGPoint(x: start, y: bottom),
            control: CGPoint(x: middle, y: top + waist * scale)
        )
        path.closeSubpath()
        return path
    }
}

/// A rectangle whose four corner radii are set and animated one by one.
///
/// `UnevenRoundedRectangle` would do for the drawing, but the corners here are animated
/// individually as the seams open and close, so the radii are carried as this shape's
/// own animatable data rather than left to whatever the container animates.
struct GooeyTile: Shape {
    var topLeading: Double
    var bottomLeading: Double
    var topTrailing: Double
    var bottomTrailing: Double

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get {
            AnimatablePair(
                AnimatablePair(topLeading, bottomLeading),
                AnimatablePair(topTrailing, bottomTrailing)
            )
        }
        set {
            topLeading = newValue.first.first
            bottomLeading = newValue.first.second
            topTrailing = newValue.second.first
            bottomTrailing = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: clamped(topLeading, in: rect),
            bottomLeadingRadius: clamped(bottomLeading, in: rect),
            bottomTrailingRadius: clamped(bottomTrailing, in: rect),
            topTrailingRadius: clamped(topTrailing, in: rect)
        )
        .path(in: rect)
    }

    /// A radius larger than half the tile would fold the corner back on itself, and a
    /// negative one is what an overshooting spring produces on its way to zero.
    private func clamped(_ radius: Double, in rect: CGRect) -> Double {
        min(max(0, radius), min(rect.width, rect.height) / 2)
    }
}

/// Whether the seam before tile `seam` is open.
///
/// The two ends of the bar are always open, since there is nothing beyond them to join
/// to, and so are the two seams either side of the selected tile. Everything else stays
/// closed, which is what makes the unselected tiles read as one continuous block.
///
/// - Parameters:
///   - seam: The seam's index. Seam `n` sits immediately before tile `n`, so a bar of
///     three tiles has four seams, `0` through `3`.
///   - active: The index of the selected tile.
///   - count: How many tiles there are.
/// - Returns: Whether the seam is open.
func gooeyIsSeamOpen(_ seam: Int, active: Int, count: Int) -> Bool {
    seam == 0 || seam == count || seam - 1 == active || seam == active
}
