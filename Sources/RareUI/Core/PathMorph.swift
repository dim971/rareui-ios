//
//  PathMorph.swift
//  Turning one outline into another.
//
//  Upstream reaches for flubber in two places: a pen becoming a tick, and a play triangle
//  becoming a pause bar. The second is two shapes whose corners correspond, and it is
//  written out by hand where it is used. The first is not: a pen and a tick have nothing in
//  common, and the only honest way to move between them is the way flubber does it, by
//  walking both outlines, taking the same number of points along each, and sliding every
//  point to its opposite number.
//
//  Two things make that look like a morph rather than a scramble. The points have to be
//  evenly spaced along the outline rather than at its corners, and the two rings have to be
//  turned until they line up, or the shape twists inside out on its way across.
//

import SwiftUI

/// A morph between two outlines, sampled once and interpolated thereafter.
struct PathMorph {
    private let start: [CGPoint]
    private let end: [CGPoint]

    /// How many points each outline is reduced to.
    ///
    /// Ninety-six is far more than an icon needs to look smooth and few enough that lining
    /// the two rings up is instant.
    static let samples = 96

    /// Samples two outlines and lines them up.
    ///
    /// - Parameters:
    ///   - from: The outline to start at.
    ///   - to: The outline to finish at.
    init(from: Path, to: Path) {
        let first = Self.ring(of: from)
        let second = Self.ring(of: to)
        start = first
        end = Self.aligned(second, to: first)
    }

    /// The outline partway between the two.
    ///
    /// - Parameters:
    ///   - progress: How far across, in `0...1`.
    ///   - rect: The box to draw into.
    ///   - viewBox: The box the two outlines were drawn in.
    /// - Returns: The interpolated path.
    func path(at progress: Double, in rect: CGRect, viewBox: CGSize) -> Path {
        guard !start.isEmpty, start.count == end.count else { return Path() }
        let t = min(1, max(0, progress))
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let offsetX = rect.minX + (rect.width - viewBox.width * scale) / 2
        let offsetY = rect.minY + (rect.height - viewBox.height * scale) / 2

        var path = Path()
        for index in start.indices {
            let point = CGPoint(
                x: offsetX + (start[index].x + (end[index].x - start[index].x) * t) * scale,
                y: offsetY + (start[index].y + (end[index].y - start[index].y) * t) * scale
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// Reduces an outline to evenly spaced points along its length.
    private static func ring(of path: Path) -> [CGPoint] {
        guard !path.isEmpty else { return [] }
        return (0 ..< samples).compactMap { index in
            let along = Double(index) / Double(samples)
            // Trimming to a fraction and asking where the pen ended up is the cheapest way
            // to walk a path at even intervals without flattening it by hand.
            return path.trimmedPath(from: 0, to: along).currentPoint ?? path.currentPoint
        }
    }

    /// Turns one ring until it lines up with the other.
    ///
    /// Without this the two outlines are joined at whatever point each happens to start
    /// from, and the shape twists through itself on the way across.
    private static func aligned(_ ring: [CGPoint], to reference: [CGPoint]) -> [CGPoint] {
        guard ring.count == reference.count, !ring.isEmpty else { return ring }

        var bestOffset = 0
        var bestCost = Double.infinity
        for offset in ring.indices {
            var cost = 0.0
            for index in ring.indices {
                let candidate = ring[(index + offset) % ring.count]
                let dx = candidate.x - reference[index].x
                let dy = candidate.y - reference[index].y
                cost += dx * dx + dy * dy
                // Nothing to learn from finishing a rotation that is already worse.
                if cost >= bestCost { break }
            }
            if cost < bestCost {
                bestCost = cost
                bestOffset = offset
            }
        }

        return ring.indices.map { ring[($0 + bestOffset) % ring.count] }
    }
}
