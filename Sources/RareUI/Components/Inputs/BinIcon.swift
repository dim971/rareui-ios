//
//  BinIcon.swift
//  The bin on DeleteButton, ported from the animated path template and the lid group in
//  upstream's `components/ui/delete-button.tsx`.
//
//  The lid is a real rotation about the hinge at the back left corner. The walls are not:
//  they are redrawn shorter as the lid opens, so the bin appears to sink into itself while
//  the lid swings clear of it. Upstream does that by interpolating a number into the path's
//  `d` string; here the path is built from the same number, which comes to the same shape
//  without producing a new string sixty times a second.
//

import SwiftUI

/// The walls of the bin, drawn from a given height down.
///
/// Upstream's template is `M19 {top}v{20 - top}a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V{top}`: down
/// the right wall, round the bottom right corner, across the base, round the bottom left,
/// and back up the left wall.
struct BinWalls: Shape {
    /// Where the walls start, in the icon's own 24 point box. Six when the bin is shut,
    /// thirteen and a half when it is open.
    var top: Double

    /// The corner radius at the base, from the arcs in upstream's path.
    private static let corner = 2.0
    /// The icon's own box.
    private static let box = 24.0
    /// Where the base sits.
    private static let base = 22.0

    var animatableData: Double {
        get { top }
        set { top = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / Self.box
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }

        var path = Path()
        path.move(to: point(19, top))
        // Rounding each bottom corner between the two walls that meet there, which is what
        // the two quarter arcs in the original do.
        path.addArc(
            tangent1End: point(19, Self.base),
            tangent2End: point(5, Self.base),
            radius: Self.corner * scale
        )
        path.addArc(
            tangent1End: point(5, Self.base),
            tangent2End: point(5, top),
            radius: Self.corner * scale
        )
        path.addLine(to: point(5, top))
        return path
    }
}

/// The lid: the rim across the top and the handle above it.
struct BinLid: Shape {
    private static let box = CGSize(width: 24, height: 24)

    func path(in rect: CGRect) -> Path {
        var path = SVGShape("M3 6h18", viewBox: Self.box).path(in: rect)
        path.addPath(
            SVGShape("M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2", viewBox: Self.box).path(in: rect)
        )
        return path
    }

    /// The hinge the lid turns about, at the back left of the rim.
    ///
    /// Upstream writes it as a transform origin of `3px 6px` in the icon's own box, which
    /// is the left end of the rim rather than the middle of the icon.
    static var hinge: UnitPoint {
        UnitPoint(x: 3 / box.width, y: 6 / box.height)
    }
}

/// The tick that replaces the bin once something has been deleted.
struct BinTick: Shape {
    func path(in rect: CGRect) -> Path {
        SVGShape("M4 12.5 9.5 18 20 7", viewBox: CGSize(width: 24, height: 24)).path(in: rect)
    }
}

/// The cross on the cancel button.
struct BinCross: Shape {
    func path(in rect: CGRect) -> Path {
        SVGShape("M6 6 18 18M18 6 6 18", viewBox: CGSize(width: 24, height: 24)).path(in: rect)
    }
}
