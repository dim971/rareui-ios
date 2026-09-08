//
//  CubicBezier.swift
//  Upstream states its easings as CSS cubic beziers. SwiftUI can take those directly as
//  `.timingCurve`, but the components that drive their own clock inside a `Canvas` have
//  to evaluate the curve themselves, so the solver lives here as plain maths.
//

import Foundation

/// A CSS style cubic bezier easing curve, evaluated at a point in time.
///
/// The two control points are the ones a `cubic-bezier(x1, y1, x2, y2)` declaration
/// carries. The first and last points are fixed at the origin and at `(1, 1)`, as they
/// are in CSS, so only the middle two are given here.
///
/// Control points outside `0...1` are allowed and are not a mistake: several upstream
/// curves overshoot deliberately, notably the bin lid's `cubic-bezier(0.34, 1.1, 0.64, 1)`.
public struct CubicBezier: Equatable, Sendable {
    /// The x coordinate of the first control point.
    public let x1: Double
    /// The y coordinate of the first control point.
    public let y1: Double
    /// The x coordinate of the second control point.
    public let x2: Double
    /// The y coordinate of the second control point.
    public let y2: Double

    /// Creates a curve from its two control points.
    ///
    /// - Parameters:
    ///   - x1: The x coordinate of the first control point. Clamped to `0...1`, as CSS does.
    ///   - y1: The y coordinate of the first control point.
    ///   - x2: The x coordinate of the second control point. Clamped to `0...1`, as CSS does.
    ///   - y2: The y coordinate of the second control point.
    public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        // x is clamped because a control point outside the unit interval on the time axis
        // would make the curve non-monotonic in t, which has no meaning for an easing.
        // y is left alone, since that is where the overshoot lives.
        self.x1 = min(1, max(0, x1))
        self.y1 = y1
        self.x2 = min(1, max(0, x2))
        self.y2 = y2
    }

    /// The eased progress at a point in time.
    ///
    /// - Parameter time: Linear progress, in `0...1`. Values outside are clamped.
    /// - Returns: The eased progress. May fall outside `0...1` when the curve overshoots.
    public func callAsFunction(_ time: Double) -> Double {
        let time = min(1, max(0, time))
        if time <= 0 || time >= 1 { return time }
        return curve(y1, y2, at: parameter(for: time))
    }

    /// Solves for the bezier parameter that puts the curve at `time` on the x axis.
    ///
    /// Newton's method converges in a handful of steps for every curve used here; the
    /// bisection fallback covers the flat stretches where the derivative is too small
    /// to step with, which is where Newton would otherwise wander off.
    private func parameter(for time: Double) -> Double {
        var t = time
        for _ in 0 ..< 8 {
            let error = curve(x1, x2, at: t) - time
            if abs(error) < 1e-7 { return t }
            let slope = derivative(x1, x2, at: t)
            if abs(slope) < 1e-7 { break }
            t -= error / slope
        }

        var low = 0.0
        var high = 1.0
        t = time
        while low < high {
            let value = curve(x1, x2, at: t)
            if abs(value - time) < 1e-7 { return t }
            if value < time { low = t } else { high = t }
            let next = (low + high) / 2
            if abs(next - t) < 1e-9 { break }
            t = next
        }
        return t
    }

    /// The cubic bezier polynomial for one axis, with endpoints pinned at 0 and 1.
    private func curve(_ a: Double, _ b: Double, at t: Double) -> Double {
        let inverse = 1 - t
        return 3 * inverse * inverse * t * a + 3 * inverse * t * t * b + t * t * t
    }

    /// The derivative of `curve(_:_:at:)` with respect to `t`.
    private func derivative(_ a: Double, _ b: Double, at t: Double) -> Double {
        let inverse = 1 - t
        return 3 * inverse * inverse * a
            + 6 * inverse * t * (b - a)
            + 3 * t * t * (1 - b)
    }
}
