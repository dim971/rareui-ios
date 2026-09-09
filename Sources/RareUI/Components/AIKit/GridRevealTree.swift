//
//  GridRevealTree.swift
//  The subdivision behind GridReveal, ported from the `buildTree`, `measureTree` and
//  `orderByDetail` functions in upstream's `components/ui/grid-reveal.tsx`.
//
//  The picture is not revealed by fading in. It is revealed by a rectangle splitting in
//  two, and each half splitting again, a hundred and eighty times, with the halves sliding
//  apart from wherever their parent was. The order the splits happen in is not arbitrary:
//  the parts of the picture with the most going on in them split first, so detail arrives
//  before flat colour does.
//

import CoreGraphics
import Foundation

/// How many cells the picture ends up divided into.
let gridRevealCells = 180
/// How many are already apart on the first frame, so the reveal does not start from a
/// single rectangle sitting still.
let gridRevealOpeningCells = 4
/// How long one cell takes to separate, in progress rather than in seconds.
let gridRevealMorph = 0.055
/// Where the last split happens, short of the end so the picture has somewhere to arrive.
let gridRevealLastSplit = 0.92
/// How far a self-paced reveal creeps toward. It never reaches it, so a load that outruns
/// its estimate keeps moving rather than stopping and waiting.
let gridRevealHold = 0.9
/// Where the grid stops splitting while it waits, leaving the arrival somewhere to go.
let gridRevealWaitCap = 0.72
/// How large a square the picture is sampled into for its average colours.
let gridRevealSample = 128

/// One rectangle of the subdivision.
///
/// A class rather than a value because the tree is walked by reference: a cell knows its
/// children and its parent, and the ordering pass rewrites split times in place.
final class GridRevealCell {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    /// The cell's average colour, once the picture has been sampled.
    var red = 0.0
    var green = 0.0
    var blue = 0.0

    /// A number of its own, used to vary the grey it shows before the colours arrive.
    let tone: Double
    /// How much the brightness varies inside it, which is what decides how early it splits.
    var detail = 0.0
    /// When it splits, in progress.
    var splitAt = 0.0

    weak var parent: GridRevealCell?
    var children: (GridRevealCell, GridRevealCell)?

    init(x: Double, y: Double, width: Double, height: Double, parent: GridRevealCell?) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.parent = parent
        tone = gridRevealHash(x + 3.1, y + 1.7, width * 31.7)
    }
}

/// A repeatable number from three others, so a cell's tone is stable across frames without
/// having to be stored anywhere.
func gridRevealHash(_ x: Double, _ y: Double, _ z: Double) -> Double {
    let n = sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453
    return n - floor(n)
}

/// Builds the subdivision.
///
/// The biggest cell is split each time, which keeps the cells roughly square and makes the
/// count rise one at a time rather than doubling. The jitter in the area only breaks ties
/// between cells of equal size, so the pattern is varied without being random.
///
/// - Parameter aspect: The picture's width over its height.
/// - Returns: The root cell and every cell that has children, in the order they split.
func gridRevealBuildTree(aspect: Double) -> (root: GridRevealCell, branches: [GridRevealCell]) {
    let root = GridRevealCell(x: 0, y: 0, width: 1, height: 1, parent: nil)
    var leaves = [root]
    var branches: [GridRevealCell] = []

    while leaves.count < gridRevealCells {
        var pick = 0
        var widest = -1.0
        for (index, cell) in leaves.enumerated() {
            let area = cell.width * aspect * cell.height
                * (1 + 0.12 * gridRevealHash(cell.x, cell.y, 7.3))
            if area > widest {
                widest = area
                pick = index
            }
        }

        let parent = leaves.remove(at: pick)
        // Split across the longer side, so halves stay close to square.
        let wide = parent.width * aspect >= parent.height
        let half = wide ? parent.width / 2 : parent.height / 2
        let first = wide
            ? GridRevealCell(x: parent.x, y: parent.y, width: half, height: parent.height, parent: parent)
            : GridRevealCell(x: parent.x, y: parent.y, width: parent.width, height: half, parent: parent)
        let second = wide
            ? GridRevealCell(
                x: parent.x + half,
                y: parent.y,
                width: half,
                height: parent.height,
                parent: parent
            )
            : GridRevealCell(
                x: parent.x,
                y: parent.y + half,
                width: parent.width,
                height: half,
                parent: parent
            )

        parent.children = (first, second)
        branches.append(parent)
        leaves.append(first)
        leaves.append(second)
    }

    let opening = gridRevealOpeningCells - 1
    let rest = max(1, branches.count - opening)
    for (index, cell) in branches.enumerated() {
        // The opening splits sit before zero, so those cells are already apart on frame one.
        cell.splitAt = index < opening
            ? -gridRevealMorph
            : gridRevealLastSplit * Double(index - opening + 1) / Double(rest)
    }

    return (root, branches)
}

/// Running totals for one cell and everything under it.
struct GridRevealSums {
    var count = 0.0
    var red = 0.0
    var green = 0.0
    var blue = 0.0
    var luminance = 0.0
    var luminanceSquared = 0.0

    static func + (lhs: GridRevealSums, rhs: GridRevealSums) -> GridRevealSums {
        GridRevealSums(
            count: lhs.count + rhs.count,
            red: lhs.red + rhs.red,
            green: lhs.green + rhs.green,
            blue: lhs.blue + rhs.blue,
            luminance: lhs.luminance + rhs.luminance,
            luminanceSquared: lhs.luminanceSquared + rhs.luminanceSquared
        )
    }
}

/// Gives every cell the average colour of the picture underneath it, and the spread of
/// brightness inside it.
///
/// The spread is the variance, and it is what tells the ordering pass which parts of the
/// picture are worth splitting early: a patch of sky varies hardly at all, a face varies a
/// great deal.
///
/// - Parameters:
///   - root: The tree's root.
///   - pixels: The picture, sampled into a square, four bytes a pixel.
///   - size: The square's side.
func gridRevealMeasure(root: GridRevealCell, pixels: [UInt8], size: Int) {
    @discardableResult
    func gather(_ cell: GridRevealCell) -> GridRevealSums {
        var sums = GridRevealSums()

        if let children = cell.children {
            sums = gather(children.0) + gather(children.1)
        } else {
            let x0 = Int((cell.x * Double(size)).rounded())
            let y0 = Int((cell.y * Double(size)).rounded())
            let x1 = max(x0 + 1, Int(((cell.x + cell.width) * Double(size)).rounded()))
            let y1 = max(y0 + 1, Int(((cell.y + cell.height) * Double(size)).rounded()))

            for y in y0 ..< min(y1, size) {
                for x in x0 ..< min(x1, size) {
                    let index = (y * size + x) * 4
                    guard index + 2 < pixels.count else { continue }
                    let red = Double(pixels[index])
                    let green = Double(pixels[index + 1])
                    let blue = Double(pixels[index + 2])
                    // The usual luminance weights, so brightness matches what an eye sees.
                    let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
                    sums.count += 1
                    sums.red += red
                    sums.green += green
                    sums.blue += blue
                    sums.luminance += luminance
                    sums.luminanceSquared += luminance * luminance
                }
            }
        }

        let count = sums.count == 0 ? 1 : sums.count
        cell.red = sums.red / count
        cell.green = sums.green / count
        cell.blue = sums.blue / count
        // The variance of the brightness: the mean of the squares less the square of the
        // mean, which is what says how much is going on inside this cell.
        cell.detail = max(
            0,
            sums.luminanceSquared / count - (sums.luminance / count) * (sums.luminance / count)
        )
        return sums
    }

    gather(root)
}

/// Reorders the splits so the busiest parts of the picture come apart first.
///
/// The times themselves are reused rather than recalculated, so only the order changes and
/// the pacing of the reveal stays exactly as it was built.
///
/// - Parameters:
///   - branches: Every cell that has children.
///   - openedBefore: Splits at or before this have already happened and are left alone.
func gridRevealOrderByDetail(_ branches: [GridRevealCell], openedBefore: Double) {
    let pending = branches.filter { $0.splitAt > openedBefore }
    guard pending.count >= 2 else { return }

    let slots = pending.map(\.splitAt).sorted()
    // Only cells whose parent has already come apart may go next, or a cell would be told
    // to split before it exists.
    var queue = pending.filter { $0.parent == nil || ($0.parent?.splitAt ?? 0) <= openedBefore }

    var next = 0
    while !queue.isEmpty, next < slots.count {
        var pick = 0
        for index in 1 ..< queue.count where queue[index].detail > queue[pick].detail {
            pick = index
        }
        let cell = queue.remove(at: pick)
        cell.splitAt = slots[next]
        next += 1

        if let children = cell.children {
            if children.0.children != nil { queue.append(children.0) }
            if children.1.children != nil { queue.append(children.1) }
        }
    }
}

/// The grey a cell shows before its colour arrives.
///
/// It breathes: the sine on the clock makes the placeholder shift very slightly, which is
/// what stops a grid of flat rectangles reading as a broken image.
///
/// - Parameters:
///   - tone: The cell's own number.
///   - dark: Whether the appearance is dark.
///   - clock: Seconds since the reveal started.
/// - Returns: A grey level, `0...255`.
func gridRevealGrey(tone: Double, dark: Bool, clock: Double) -> Double {
    (dark ? 30 : 228) + tone * 13 + sin(clock * 1.5 + tone * 6.28) * 3
}

/// How far a reveal with no progress of its own has got.
///
/// It approaches its ceiling without ever arriving, so a load that takes longer than its
/// estimate keeps creeping rather than stopping and waiting.
///
/// - Parameters:
///   - elapsed: Seconds since it started.
///   - duration: The estimate, in seconds.
/// - Returns: Progress, below ``gridRevealHold``.
func gridRevealSelfPaced(elapsed: Double, duration: Double) -> Double {
    let span = duration > 0 ? duration : 1
    return gridRevealHold * (1 - exp(-elapsed / span))
}

/// The smooth step upstream uses to fade the gutters and bring the photo in.
///
/// - Parameters:
///   - from: Where the transition starts.
///   - to: Where it finishes.
///   - value: The value being tested.
/// - Returns: A value in `0...1`, easing at both ends.
func gridRevealSmoothstep(_ from: Double, _ to: Double, _ value: Double) -> Double {
    let t = min(1, max(0, (value - from) / (to - from)))
    return t * t * (3 - 2 * t)
}
