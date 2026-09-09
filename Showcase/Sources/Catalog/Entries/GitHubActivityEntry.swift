import RareUI
import SwiftUI

@MainActor
let gitHubActivityEntry = CatalogEntry(
    "GitHub Activity",
    summary: "A contribution heatmap whose footer lifts up and turns into a ranked list.",
    demos: [
        Demo(
            "A year of it",
            note: """
            The grid draws itself left to right, a column at a time, and the month labels \
            wait for it to finish and then resolve out of a blur.
            """,
            code: """
            GitHubActivity(contributions: days, repos: repositories)
            """
        ) {
            GitHubActivity(
                contributions: SampleActivity.year,
                repos: SampleActivity.repos,
                showsMonths: true
            )
        },

        Demo(
            "Any accent, any size",
            code: """
            GitHubActivity(contributions: days, accent: .orange, cellSize: 8, months: 6)
            """
        ) {
            GitHubActivity(
                contributions: SampleActivity.year,
                repos: SampleActivity.repos,
                accent: Color(hex: "#FC4C01"),
                cellSize: 8,
                months: 6
            )
        }
    ]
) {
    GitHubActivity(
        contributions: Array(SampleActivity.year.suffix(70)),
        cellSize: 5,
        months: 2
    )
    .frame(width: 110)
}

/// A year of plausible looking activity, so the demo has something to draw.
private enum SampleActivity {
    static let year: [GitHubContribution] = {
        var generator = SystemRandomNumberGenerator()
        let start = Calendar.current.date(byAdding: .day, value: -364, to: Date()) ?? Date()

        return (0 ..< 365).map { day in
            let date = Calendar.current.date(byAdding: .day, value: day, to: start) ?? start
            // Weekends are quieter, and there are stretches of nothing at all, which is
            // what makes a real year of activity look like one.
            let weekday = Calendar.current.component(.weekday, from: date)
            let quiet = weekday == 1 || weekday == 7 || Int.random(in: 0 ... 4, using: &generator) == 0
            let count = quiet
                ? Int.random(in: 0 ... 2, using: &generator)
                : Int.random(in: 0 ... 14, using: &generator)

            let level = switch count {
            case 0: 0
            case 1 ... 2: 1
            case 3 ... 6: 2
            case 7 ... 10: 3
            default: 4
            }
            return GitHubContribution(date: date, count: count, level: level)
        }
    }()

    static let repos = [
        GitHubRepoContribution(name: "rareui-ios", count: 412),
        GitHubRepoContribution(name: "rareui-android", count: 287),
        GitHubRepoContribution(name: "drawably-ios", count: 143),
        GitHubRepoContribution(name: "openclaude", count: 61)
    ]
}
