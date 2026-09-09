//
//  GitHubActivityData.swift
//  What a contribution heatmap is made of, and the arithmetic behind it, from upstream's
//  `components/ui/github-activity.tsx`.
//

import SwiftUI

/// One day's contributions.
public struct GitHubContribution: Identifiable, Hashable, Sendable {
    /// The day.
    public let date: Date
    /// How many contributions were made.
    public let count: Int
    /// How dark the cell is drawn, from `0` for none to `4` for the most.
    public let level: Int

    public var id: Date {
        date
    }

    /// Creates a day.
    ///
    /// - Parameters:
    ///   - date: The day.
    ///   - count: How many contributions were made.
    ///   - level: How dark to draw it, `0` through `4`.
    public init(date: Date, count: Int, level: Int) {
        self.date = date
        self.count = count
        self.level = min(4, max(0, level))
    }
}

/// One repository's share of the contributions.
public struct GitHubRepoContribution: Identifiable, Hashable, Sendable {
    /// The repository's name.
    public let name: String
    /// How many contributions went to it.
    public let count: Int

    public var id: String {
        name
    }

    /// Creates a repository's share.
    ///
    /// - Parameters:
    ///   - name: The repository's name.
    ///   - count: How many contributions went to it.
    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

/// How dark each level is drawn, as a fraction of the accent.
///
/// Level zero is not drawn at all: the cell underneath shows through, which is what gives
/// the grid its empty days without spending a colour on them.
func gitHubLevelOpacity(_ level: Int) -> Double {
    switch min(4, max(0, level)) {
    case 1: 0.3
    case 2: 0.52
    case 3: 0.76
    case 4: 1
    default: 0
    }
}

/// The colour one cell is drawn in, given a scale of your own.
///
/// Upstream takes either one colour, shaded by level, or a list of them. A list of four is
/// the four levels that have anything in them, with an empty day left to show the cell
/// underneath; a longer list sets every level including the empty one. A list too short for
/// the level asked for repeats its last colour rather than falling off the end.
///
/// - Parameters:
///   - level: The day's level.
///   - scale: The colours to draw from.
/// - Returns: The colour, or clear for an empty day the scale does not name.
func gitHubLevelInk(_ level: Int, scale: [Color]) -> Color {
    guard !scale.isEmpty else { return .clear }
    let colours = scale.count > 4 ? scale : [Color.clear] + scale
    let index = min(4, max(0, level))
    return index < colours.count ? colours[index] : (colours.last ?? .clear)
}

/// The gap between two cells, which grows with them.
///
/// - Parameter cellSize: How large one cell is, in points.
/// - Returns: The gap, never below two points.
func gitHubCellGap(cellSize: Double) -> Double {
    max(2, (cellSize / 4).rounded())
}

/// How many weeks are in a given number of months.
///
/// Never zero, because a grid of no weeks would be a grid of the whole history: upstream
/// notes that slicing the last nought weeks off an array hands back all of it.
///
/// - Parameter months: How many months to show.
/// - Returns: The number of weeks.
func gitHubWeeks(months: Int) -> Int {
    max(1, Int(ceil(Double(months) * 365.25 / 12 / 7)))
}
