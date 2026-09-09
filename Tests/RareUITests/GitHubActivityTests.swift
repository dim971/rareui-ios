//
//  GitHubActivityTests.swift
//  The arithmetic behind the heatmap, checked against `components/ui/github-activity.tsx`.
//

@testable import RareUI
import Testing

@Suite("Contribution levels")
struct GitHubLevelTests {
    @Test("an empty day is not drawn at all")
    func emptyIsInvisible() {
        // The cell underneath shows through, which is how the grid gets its empty days
        // without spending a colour on them.
        #expect(gitHubLevelOpacity(0) == 0)
    }

    @Test("each level is darker than the last, and the top one is the accent itself")
    func increasing() {
        var previous = -1.0
        for level in 0 ... 4 {
            let opacity = gitHubLevelOpacity(level)
            #expect(opacity > previous)
            previous = opacity
        }
        #expect(gitHubLevelOpacity(4) == 1)
    }

    @Test("a level outside the range is brought back into it")
    func clamped() {
        #expect(gitHubLevelOpacity(-3) == gitHubLevelOpacity(0))
        #expect(gitHubLevelOpacity(99) == gitHubLevelOpacity(4))
    }
}

@Suite("Heatmap measurements")
struct GitHubMeasurementTests {
    @Test("the gap grows with the cells but never disappears")
    func gap() {
        #expect(gitHubCellGap(cellSize: 11) == 3)
        #expect(gitHubCellGap(cellSize: 20) == 5)
        // A gap of nothing would turn the grid into a solid block.
        #expect(gitHubCellGap(cellSize: 1) == 2)
        #expect(gitHubCellGap(cellSize: 0) == 2)
    }

    @Test("a year is about fifty-three weeks")
    func weeksInAYear() {
        #expect(gitHubWeeks(months: 12) == 53)
        #expect(gitHubWeeks(months: 6) == 27)
        #expect(gitHubWeeks(months: 1) == 5)
    }

    @Test("no months still means one week, not the whole history")
    func neverNone() {
        // Upstream notes the trap: slicing the last nought weeks off an array hands back
        // all of it, so a grid of no months would silently become a grid of everything.
        #expect(gitHubWeeks(months: 0) == 1)
        #expect(gitHubWeeks(months: -5) == 1)
    }
}
