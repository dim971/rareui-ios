//
//  SVGPath.swift
//  Reads an SVG path string into a SwiftUI `Path`.
//
//  Several of these components carry hand-drawn icons as inline SVG: a bell, a bin whose
//  walls redraw as its lid opens, a play triangle that turns into a pause bar. Rewriting
//  those as SwiftUI drawing commands would mean transcribing a few hundred coordinates by
//  hand, and every one of them is a chance to be wrong in a way nobody would ever notice.
//
//  Reading the original string instead means the icons are quotations rather than
//  translations, and a change upstream is a copy and paste.
//

import CoreGraphics
import Foundation
import SwiftUI

/// Reads an SVG path's `d` attribute.
public enum SVGPath {
    /// Paths already read, kept so a shape redrawn every frame is not re-parsed every frame.
    ///
    /// The strings are icon definitions written into the source, so there is a small fixed
    /// number of them and nothing to evict.
    @MainActor private static var cache: [String: Path] = [:]

    /// Builds a path from an SVG `d` string, reusing an earlier reading of the same string.
    ///
    /// - Parameter d: The path data, as it appears in the `d` attribute.
    /// - Returns: The path.
    @MainActor
    public static func cached(_ d: String) -> Path {
        if let known = cache[d] { return known }
        let parsed = path(d)
        cache[d] = parsed
        return parsed
    }

    // A parser's dispatch is one branch per command, and there are twenty of them. Cutting
    // it into pieces to satisfy a complexity count would spread a single flat table across
    // several functions and make it harder, not easier, to check against the specification.
    // swiftlint:disable cyclomatic_complexity function_body_length
    /// Builds a path from an SVG `d` string.
    ///
    /// Supports every command SVG defines: moves, lines, horizontal and vertical lines,
    /// cubic and quadratic curves with their smooth forms, elliptical arcs, and close.
    /// Both the absolute and relative spellings of each are understood.
    ///
    /// - Parameter d: The path data, as it appears in the `d` attribute.
    /// - Returns: The path. Malformed data yields as much of the path as could be read,
    ///   rather than nothing at all, so a typo shows up on screen as a shape that stops
    ///   early rather than as a blank space.
    public static func path(_ d: String) -> Path {
        var reader = Reader(d)
        var path = Path()
        var point = CGPoint.zero
        var subpathStart = CGPoint.zero
        // Where the last curve's second control point was, reflected for a smooth curve.
        var lastCubicControl: CGPoint?
        var lastQuadraticControl: CGPoint?
        var command: Character?

        while true {
            if let next = reader.command() {
                command = next
            } else if reader.isAtEnd {
                break
            } else if command == nil {
                // Data that does not begin with a command has nothing to be repeated.
                break
            }

            guard let current = command else { break }
            let relative = current.isLowercase

            func absolute(_ x: Double, _ y: Double) -> CGPoint {
                relative ? CGPoint(x: point.x + x, y: point.y + y) : CGPoint(x: x, y: y)
            }

            switch Character(current.lowercased()) {
            case "m":
                guard let x = reader.number(), let y = reader.number() else { return path }
                point = absolute(x, y)
                subpathStart = point
                path.move(to: point)
                // A move followed by more numbers means a line, per the specification.
                command = relative ? "l" : "L"
                lastCubicControl = nil
                lastQuadraticControl = nil

            case "l":
                guard let x = reader.number(), let y = reader.number() else { return path }
                point = absolute(x, y)
                path.addLine(to: point)
                lastCubicControl = nil
                lastQuadraticControl = nil

            case "h":
                guard let x = reader.number() else { return path }
                point = relative ? CGPoint(x: point.x + x, y: point.y) : CGPoint(x: x, y: point.y)
                path.addLine(to: point)
                lastCubicControl = nil
                lastQuadraticControl = nil

            case "v":
                guard let y = reader.number() else { return path }
                point = relative ? CGPoint(x: point.x, y: point.y + y) : CGPoint(x: point.x, y: y)
                path.addLine(to: point)
                lastCubicControl = nil
                lastQuadraticControl = nil

            case "c":
                guard
                    let x1 = reader.number(), let y1 = reader.number(),
                    let x2 = reader.number(), let y2 = reader.number(),
                    let x = reader.number(), let y = reader.number()
                else { return path }
                let control1 = absolute(x1, y1)
                let control2 = absolute(x2, y2)
                point = absolute(x, y)
                path.addCurve(to: point, control1: control1, control2: control2)
                lastCubicControl = control2
                lastQuadraticControl = nil

            case "s":
                guard
                    let x2 = reader.number(), let y2 = reader.number(),
                    let x = reader.number(), let y = reader.number()
                else { return path }
                // The first control point is the reflection of the last one, which is what
                // makes the join smooth. With no previous curve it sits on the point itself.
                let control1 = reflect(lastCubicControl, about: point)
                let control2 = absolute(x2, y2)
                point = absolute(x, y)
                path.addCurve(to: point, control1: control1, control2: control2)
                lastCubicControl = control2
                lastQuadraticControl = nil

            case "q":
                guard
                    let x1 = reader.number(), let y1 = reader.number(),
                    let x = reader.number(), let y = reader.number()
                else { return path }
                let control = absolute(x1, y1)
                point = absolute(x, y)
                path.addQuadCurve(to: point, control: control)
                lastQuadraticControl = control
                lastCubicControl = nil

            case "t":
                guard let x = reader.number(), let y = reader.number() else { return path }
                let control = reflect(lastQuadraticControl, about: point)
                point = absolute(x, y)
                path.addQuadCurve(to: point, control: control)
                lastQuadraticControl = control
                lastCubicControl = nil

            case "a":
                guard
                    let rx = reader.number(), let ry = reader.number(),
                    let rotation = reader.number(),
                    let largeArc = reader.flag(), let sweep = reader.flag(),
                    let x = reader.number(), let y = reader.number()
                else { return path }
                let end = absolute(x, y)
                let arc = Arc(rx: rx, ry: ry, rotation: rotation, largeArc: largeArc, sweep: sweep)
                addArc(arc, to: &path, from: point, to: end)
                point = end
                lastCubicControl = nil
                lastQuadraticControl = nil

            case "z":
                path.closeSubpath()
                point = subpathStart
                lastCubicControl = nil
                lastQuadraticControl = nil

            default:
                return path
            }

            if reader.isAtEnd { break }
        }

        return path
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    /// The reflection of a curve's last control point, which is what a smooth curve's
    /// first control point is defined to be.
    private static func reflect(_ control: CGPoint?, about point: CGPoint) -> CGPoint {
        guard let control else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    /// An arc as SVG states one: by its shape and by where it ends, rather than by where
    /// its centre is.
    struct Arc {
        /// The ellipse's horizontal radius.
        let rx: Double
        /// Its vertical radius.
        let ry: Double
        /// How far the ellipse itself is turned, in degrees.
        let rotation: Double
        /// Whether to take the longer of the two arcs that fit.
        let largeArc: Bool
        /// Whether to sweep in the direction of increasing angle.
        let sweep: Bool
    }

    /// Adds an elliptical arc, converted to cubic curves.
    ///
    /// Since SVG says where the arc ends rather than where its centre is, the centre has
    /// to be recovered first. This follows the conversion in the specification's
    /// implementation notes, appendix F.6.
    private static func addArc(_ arc: Arc, to path: inout Path, from start: CGPoint, to end: CGPoint) {
        // A zero radius is defined to mean a straight line, and so is going nowhere.
        guard arc.rx != 0, arc.ry != 0, start != end else {
            path.addLine(to: end)
            return
        }

        let angle = arc.rotation * .pi / 180
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1 = cosAngle * dx + sinAngle * dy
        let y1 = -sinAngle * dx + cosAngle * dy

        // Radii too small to reach are scaled up until they just can, as the specification
        // requires, rather than leaving the arc undefined.
        var rx = abs(arc.rx)
        var ry = abs(arc.ry)
        let overshoot = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if overshoot > 1 {
            let scale = overshoot.squareRoot()
            rx *= scale
            ry *= scale
        }

        let numerator = max(0, rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1)
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let factor = (denominator == 0 ? 0 : (numerator / denominator).squareRoot())
            * (arc.largeArc == arc.sweep ? -1 : 1)

        let cx1 = factor * rx * y1 / ry
        let cy1 = -factor * ry * x1 / rx
        let centre = CGPoint(
            x: cosAngle * cx1 - sinAngle * cy1 + (start.x + end.x) / 2,
            y: sinAngle * cx1 + cosAngle * cy1 + (start.y + end.y) / 2
        )

        let startAngle = atan2((y1 - cy1) / ry, (x1 - cx1) / rx)
        var sweepAngle = atan2((-y1 - cy1) / ry, (-x1 - cx1) / rx) - startAngle
        if !arc.sweep, sweepAngle > 0 { sweepAngle -= 2 * .pi }
        if arc.sweep, sweepAngle < 0 { sweepAngle += 2 * .pi }

        sweep(
            &path,
            around: Ellipse(centre: centre, rx: rx, ry: ry, cosAngle: cosAngle, sinAngle: sinAngle),
            from: startAngle,
            through: sweepAngle
        )
    }

    /// An ellipse, once its centre has been recovered from the arc's endpoints.
    private struct Ellipse {
        let centre: CGPoint
        let rx: Double
        let ry: Double
        let cosAngle: Double
        let sinAngle: Double

        /// A point on the ellipse at the given angle.
        func point(at theta: Double) -> CGPoint {
            let x = rx * cos(theta)
            let y = ry * sin(theta)
            return CGPoint(
                x: centre.x + cosAngle * x - sinAngle * y,
                y: centre.y + sinAngle * x + cosAngle * y
            )
        }

        /// The direction of travel at that angle, which the curve's handles follow.
        func slope(at theta: Double) -> CGPoint {
            let dx = -rx * sin(theta)
            let dy = ry * cos(theta)
            return CGPoint(x: cosAngle * dx - sinAngle * dy, y: sinAngle * dx + cosAngle * dy)
        }
    }

    /// Walks the arc in cubic segments of at most a quarter turn, which is as far as one
    /// cubic curve can follow an ellipse without visibly leaving it.
    private static func sweep(
        _ path: inout Path,
        around ellipse: Ellipse,
        from startAngle: Double,
        through sweepAngle: Double
    ) {
        let segments = max(1, Int(ceil(abs(sweepAngle) / (.pi / 2))))
        let step = sweepAngle / Double(segments)
        // The factor that makes a cubic curve match a circular arc of this angle.
        let handle = 4.0 / 3 * tan(step / 4)

        var theta = startAngle
        for _ in 0 ..< segments {
            let next = theta + step
            let from = ellipse.point(at: theta)
            let to = ellipse.point(at: next)
            let fromSlope = ellipse.slope(at: theta)
            let toSlope = ellipse.slope(at: next)

            path.addCurve(
                to: to,
                control1: CGPoint(x: from.x + handle * fromSlope.x, y: from.y + handle * fromSlope.y),
                control2: CGPoint(x: to.x - handle * toSlope.x, y: to.y - handle * toSlope.y)
            )
            theta = next
        }
    }
}

private extension SVGPath {
    /// Walks an SVG path string, handing out commands and numbers.
    ///
    /// SVG path data is deliberately terse: separators are optional wherever the meaning
    /// is unambiguous, so `M0 0L10 10` and `M 0,0 L 10,10` are the same path, and a minus
    /// sign is its own separator. The reader has to allow all of it.
    struct Reader {
        private let characters: [Character]
        private var index = 0

        init(_ text: String) {
            characters = Array(text)
        }

        var isAtEnd: Bool {
            var probe = index
            while probe < characters.count, characters[probe].isSVGWhitespace || characters[probe] == "," {
                probe += 1
            }
            return probe >= characters.count
        }

        mutating func command() -> Character? {
            skipSeparators()
            guard index < characters.count, characters[index].isSVGCommand else { return nil }
            defer { index += 1 }
            return characters[index]
        }

        mutating func number() -> Double? {
            skipSeparators()
            let start = index

            if index < characters.count, characters[index] == "+" || characters[index] == "-" {
                index += 1
            }
            consumeDigits()
            if index < characters.count, characters[index] == "." {
                index += 1
                consumeDigits()
            }
            if index < characters.count, characters[index] == "e" || characters[index] == "E" {
                let exponent = index
                index += 1
                if index < characters.count, characters[index] == "+" || characters[index] == "-" {
                    index += 1
                }
                // An `e` with no digits after it belongs to the next command, not this number.
                if index < characters.count,
                   characters[index].isNumber { consumeDigits() } else { index = exponent }
            }

            guard index > start else { return nil }
            return Double(String(characters[start ..< index]))
        }

        /// An arc's two flags are single digits with no separator required, so `0 1` and
        /// `01` both parse, and reading them as ordinary numbers would swallow both.
        mutating func flag() -> Bool? {
            skipSeparators()
            guard index < characters.count, characters[index] == "0" || characters[index] == "1" else {
                return nil
            }
            defer { index += 1 }
            return characters[index] == "1"
        }

        private mutating func consumeDigits() {
            while index < characters.count, characters[index].isNumber, characters[index].isASCII {
                index += 1
            }
        }

        private mutating func skipSeparators() {
            while index < characters.count, characters[index].isSVGWhitespace || characters[index] == "," {
                index += 1
            }
        }
    }
}

private extension Character {
    var isSVGWhitespace: Bool {
        self == " " || self == "\t" || self == "\n" || self == "\r"
    }

    var isSVGCommand: Bool {
        "MmLlHhVvCcSsQqTtAaZz".contains(self)
    }
}

/// An SVG path drawn to fill a view, scaled from the box it was drawn in.
///
/// The `d` string is quoted from upstream unchanged, which is the point: the icon is the
/// same drawing rather than a transcription of it.
public struct SVGShape: Shape {
    /// The path data, as it appears in the `d` attribute.
    public let d: String
    /// The box the path was drawn in, from the SVG's `viewBox`.
    public let viewBox: CGSize
    /// Whether to keep the drawing's proportions, letterboxing it if the view is a
    /// different shape. SVG calls the alternative `preserveAspectRatio="none"`.
    public let preservesAspectRatio: Bool

    /// Creates a shape from SVG path data.
    ///
    /// - Parameters:
    ///   - d: The path data.
    ///   - viewBox: The box the path was drawn in.
    ///   - preservesAspectRatio: Whether to keep the drawing's proportions. Defaults to `true`.
    public init(_ d: String, viewBox: CGSize, preservesAspectRatio: Bool = true) {
        self.d = d
        self.viewBox = viewBox
        self.preservesAspectRatio = preservesAspectRatio
    }

    public func path(in rect: CGRect) -> Path {
        guard viewBox.width > 0, viewBox.height > 0 else { return Path() }
        let drawing = MainActor.assumeIsolated { SVGPath.cached(d) }

        var scaleX = rect.width / viewBox.width
        var scaleY = rect.height / viewBox.height
        if preservesAspectRatio {
            let fit = min(scaleX, scaleY)
            scaleX = fit
            scaleY = fit
        }

        let width = viewBox.width * scaleX
        let height = viewBox.height * scaleY
        return drawing
            .applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
            .offsetBy(dx: rect.minX + (rect.width - width) / 2, dy: rect.minY + (rect.height - height) / 2)
    }

    /// Where a point in the drawing's own box falls in the view, as a unit point.
    ///
    /// Rotating an icon about a part of itself needs this: upstream turns the bell's
    /// clapper about the top middle of the clapper, not of the bell.
    ///
    /// - Parameter point: The point, in the drawing's coordinates.
    /// - Returns: The matching unit point.
    public func unitPoint(_ point: CGPoint) -> UnitPoint {
        UnitPoint(x: point.x / viewBox.width, y: point.y / viewBox.height)
    }
}
