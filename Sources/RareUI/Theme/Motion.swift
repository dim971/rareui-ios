//
//  Motion.swift
//  The bridge between Motion for React, which every upstream component animates with,
//  and SwiftUI. The mapping is close enough to be exact in both directions, which is
//  the reason this port can claim to move the way the original does.
//
//    Motion `{ stiffness, damping, mass }`  ->  `.interpolatingSpring(mass:stiffness:damping:)`
//    Motion `{ duration, bounce }`          ->  `.spring(duration:bounce:)`
//    Motion `ease: [a, b, c, d]`            ->  `.timingCurve(a, b, c, d)`
//
//  Component specific constants do not live here. They live next to the component that
//  uses them, with a comment naming the upstream file they came from, so the number can
//  be checked against the original in one place. What lives here is the handful of
//  curves upstream reaches for again and again.
//

import SwiftUI

/// The animation vocabulary shared across the library.
public enum RareUIMotion {
    /// A spring stated the way Motion for React states one.
    ///
    /// - Parameters:
    ///   - stiffness: The spring constant. Motion's default is 100.
    ///   - damping: The damping coefficient. Motion's default is 10.
    ///   - mass: The mass of the animated body. Motion's default is 1.
    /// - Returns: The equivalent SwiftUI animation.
    public static func spring(stiffness: Double, damping: Double, mass: Double = 1) -> Animation {
        .interpolatingSpring(mass: mass, stiffness: stiffness, damping: damping)
    }

    /// An animation, or none at all when the reader has asked for less movement.
    ///
    /// Upstream degrades to `{ duration: 0 }` under `useReducedMotion()`, which lands the
    /// view on its final value immediately rather than leaving it where it was. Returning
    /// `nil` here does the same thing in SwiftUI: the state change still happens, it just
    /// is not interpolated.
    ///
    /// - Parameters:
    ///   - animation: The animation to use when movement is welcome.
    ///   - reduceMotion: Whether the reader has asked for reduced motion.
    /// - Returns: The animation, or `nil`.
    public static func settling(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    /// `cubic-bezier(0.22, 1, 0.36, 1)`, upstream's most used ease out.
    ///
    /// It leaves fast and arrives slowly. Used by the contribution grid's cells, the
    /// counter's exit, and the scroll indicator's label crossfade.
    public static let easeOutQuint = CubicBezier(0.22, 1, 0.36, 1)

    /// `cubic-bezier(0.32, 0.72, 0, 1)`, the long settle.
    ///
    /// Used where something changes size rather than position: the step player's
    /// crossfade and the delete button's width.
    public static let easeOutSettle = CubicBezier(0.32, 0.72, 0, 1)

    /// `cubic-bezier(0.34, 1.1, 0.64, 1)`, an ease out that overshoots.
    ///
    /// The second control point sits above 1 on purpose. This is what throws the bin
    /// lid past its open angle before it comes back.
    public static let easeOutOvershoot = CubicBezier(0.34, 1.1, 0.64, 1)

    /// `cubic-bezier(0.215, 0.61, 0.355, 1)`, the landing squash.
    ///
    /// Used by the falling glyphs when they hit the pile.
    public static let easeOutLanding = CubicBezier(0.215, 0.61, 0.355, 1)

    /// `cubic-bezier(0.65, 0, 0.35, 1)`, a symmetric ease in and out.
    public static let easeInOut = CubicBezier(0.65, 0, 0.35, 1)

    /// `cubic-bezier(0.45, 0, 0.55, 1)`, the shimmer's gentler ease in and out.
    public static let easeInOutShimmer = CubicBezier(0.45, 0, 0.55, 1)

    /// `cubic-bezier(0.4, 0.3, 0.5, 1)`, the emoji particles' rise.
    public static let easeParticle = CubicBezier(0.4, 0.3, 0.5, 1)
}

public extension Animation {
    /// A spring stated the way Motion for React states one.
    ///
    /// - Parameters:
    ///   - stiffness: The spring constant.
    ///   - damping: The damping coefficient.
    ///   - mass: The mass of the animated body. Defaults to Motion's own default of 1.
    /// - Returns: The equivalent SwiftUI animation.
    static func rareUISpring(stiffness: Double, damping: Double, mass: Double = 1) -> Animation {
        RareUIMotion.spring(stiffness: stiffness, damping: damping, mass: mass)
    }

    /// A CSS style cubic bezier, stated as `timingCurve` over a duration.
    ///
    /// - Parameters:
    ///   - curve: The easing curve.
    ///   - duration: The duration, in seconds.
    /// - Returns: The equivalent SwiftUI animation.
    static func rareUICurve(_ curve: CubicBezier, duration: Double) -> Animation {
        .timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: duration)
    }
}
