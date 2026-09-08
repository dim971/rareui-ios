//
//  GravityHeightMap.swift
//  The pile GravityLetters' glyphs land on, ported from the `spanOf`, `restY`, `deposit`,
//  `windowTop`, `groundTilt` and `findRestX` functions in upstream's
//  `components/ui/gravity-letters.tsx`.
//
//  There is no physics engine here and there is not one upstream either. The pile is a
//  height map: the container is divided into eight point columns, each remembering how deep
//  the heap is at that point. A glyph looking for somewhere to land asks the columns it
//  covers how high they are, and a glyph that has landed raises them. That is the whole
//  model, and it is what makes hundreds of letters cost almost nothing.
//

import Foundation

/// How wide one column of the height map is, in points.
let gravityColumnWidth = 8.0
/// How much lower a neighbouring column has to be before a glyph slides on to it, as a
/// fraction of the glyph's own height.
let gravitySlope = 0.35
/// The steepest a glyph comes to rest at, in degrees.
let gravityMaxTilt = 26.0
/// How much of its speed a glyph keeps on its one bounce.
let gravityBounce = 0.22
/// The slide threshold while the device is tilted, which makes the pile keener to move.
let gravityEagerSlope = 0.45

/// A heap of glyphs, remembered as how deep it is at each column across the container.
struct GravityHeightMap {
    private(set) var heights: [Double]
    /// How tall the container is, which is what depths are measured up from.
    let height: Double

    /// Creates an empty heap.
    ///
    /// - Parameters:
    ///   - width: The container's width, in points.
    ///   - height: Its height, in points.
    init(width: Double, height: Double) {
        heights = Array(repeating: 0, count: max(1, Int(ceil(width / gravityColumnWidth))))
        self.height = height
    }

    /// Which columns a glyph of the given width covers.
    ///
    /// - Parameters:
    ///   - x: The glyph's left edge.
    ///   - width: Its width.
    /// - Returns: The first and last column it touches.
    func span(x: Double, width: Double) -> (from: Int, to: Int) {
        let from = max(0, Int(floor(x / gravityColumnWidth)))
        let to = min(heights.count - 1, max(from, Int(ceil((x + width) / gravityColumnWidth)) - 1))
        return (from, to)
    }

    /// The highest the heap reaches across a run of columns.
    ///
    /// Returns infinity when the run falls off either end, which is how a glyph at the
    /// edge of the container is stopped from sliding out of it: there is nothing lower
    /// beyond the wall, so it reads as infinitely high.
    ///
    /// - Parameters:
    ///   - from: The first column.
    ///   - to: The last.
    /// - Returns: The greatest depth in that run.
    func top(from: Int, to: Int) -> Double {
        guard from >= 0, to < heights.count else { return .infinity }
        var highest = 0.0
        for column in from ... max(from, to) {
            highest = max(highest, heights[column])
        }
        return highest
    }

    /// Where a glyph would come to rest, given how far it is leaning.
    ///
    /// A leaning glyph touches the heap on one corner rather than along its base, so the
    /// column under that corner is what stops it and the rest of its width hangs over
    /// whatever is beside it.
    ///
    /// - Parameters:
    ///   - x: The glyph's left edge.
    ///   - width: Its width once rotated.
    ///   - glyphHeight: Its height once rotated.
    ///   - rotation: How far it is leaning, in degrees.
    /// - Returns: The vertical position of its top edge at rest.
    func restY(x: Double, width: Double, glyphHeight: Double, rotation: Double) -> Double {
        let bounds = span(x: x, width: width)
        let tangent = tan(abs(rotation) * .pi / 180)
        var lowest = Double.infinity

        for column in bounds.from ... bounds.to {
            let centre = min(max((Double(column) + 0.5) * gravityColumnWidth - x, 0), width)
            let edge = min((rotation >= 0 ? width - centre : centre) * tangent, glyphHeight - 1)
            lowest = min(lowest, height - heights[column] - glyphHeight + edge)
        }
        return lowest
    }

    /// Raises the heap to account for a glyph that has landed.
    ///
    /// - Parameters:
    ///   - x: The glyph's left edge.
    ///   - width: Its width once rotated.
    ///   - glyphHeight: Its height once rotated.
    ///   - rotation: How far it is leaning, in degrees.
    ///   - y: Where its top edge came to rest.
    mutating func deposit(x: Double, width: Double, glyphHeight: Double, rotation: Double, y: Double) {
        let bounds = span(x: x, width: width)
        let tangent = tan(abs(rotation) * .pi / 180)

        for column in bounds.from ... bounds.to {
            let centre = min(max((Double(column) + 0.5) * gravityColumnWidth - x, 0), width)
            // The opposite corner to the one restY measured, so a leaning glyph raises the
            // heap under its high side as well as its low one.
            let edge = min((rotation >= 0 ? centre : width - centre) * tangent, glyphHeight - 1)
            heights[column] = max(heights[column], height - y - edge)
        }
    }

    /// How steeply the heap slopes under a glyph, in degrees.
    ///
    /// Comparing the left half of the span with the right half. A glyph landing on a slope
    /// leans to match it, which is what makes a pile of letters look like a pile rather
    /// than like a stack.
    ///
    /// - Parameters:
    ///   - x: The glyph's left edge.
    ///   - width: Its width.
    /// - Returns: The slope, in degrees, positive when the heap is higher on the left.
    func groundTilt(x: Double, width: Double) -> Double {
        let bounds = span(x: x, width: width)
        guard bounds.to > bounds.from else { return 0 }

        let middle = Int(ceil(Double(bounds.from + bounds.to) / 2))
        let left = top(from: bounds.from, to: middle - 1)
        let right = top(from: middle, to: bounds.to)
        guard left.isFinite, right.isFinite else { return 0 }

        let run = max(Double(bounds.to - bounds.from + 1) / 2 * gravityColumnWidth, 1)
        return atan2(left - right, run) * 180 / .pi
    }

    /// Walks a glyph sideways until it finds somewhere it will not slide off.
    ///
    /// Sixty-four steps is upstream's own cap and it is generous: a glyph reaches its
    /// resting place in a handful, and the cap only matters for a heap so uneven that a
    /// glyph would otherwise wander forever.
    ///
    /// - Parameters:
    ///   - x: Where the glyph is now.
    ///   - width: Its unrotated width.
    ///   - glyphHeight: Its unrotated height.
    ///   - maxX: The furthest right it may go.
    ///   - bias: Which way to break a tie, `-1` for left and `1` for right.
    ///   - eager: A factor on the slide threshold. Below one the pile slides more readily.
    /// - Returns: Where it settles.
    func restX(
        from x: Double,
        width: Double,
        glyphHeight: Double,
        maxX: Double,
        bias: Double,
        eager: Double = 1
    ) -> Double {
        var current = min(max(x, 0), max(0, maxX))
        let drop = glyphHeight * gravitySlope * eager
        let step = max(gravityColumnWidth, (width / 3).rounded())

        for _ in 0 ..< 64 {
            let bounds = span(x: current, width: width)
            let columns = bounds.to - bounds.from + 1
            let here = top(from: bounds.from, to: bounds.to)
            let toLeft = here - top(from: bounds.from - columns, to: bounds.from - 1)
            let toRight = here - top(from: bounds.to + 1, to: bounds.to + columns)

            var next = current
            if toLeft > drop, toRight > drop, abs(toLeft - toRight) <= 1 {
                // A ridge with equal drops either side, so the tie is broken by the bias:
                // whichever way the wind is blowing, or a coin toss when it is still.
                next = bias < 0 ? max(current - step, 0) : min(current + step, maxX)
            } else if toLeft > drop, toLeft >= toRight {
                next = max(current - step, 0)
            } else if toRight > drop {
                next = min(current + step, maxX)
            }

            if next == current { break }
            current = next
        }
        return current
    }
}
