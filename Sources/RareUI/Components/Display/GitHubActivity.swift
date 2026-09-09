//
//  GitHubActivity.swift
//  A port of upstream's `components/ui/github-activity.tsx`.
//
//  A contribution heatmap on a card, with a footer that lifts up over the grid and turns
//  into a ranked list of the repositories the contributions went to.
//
//  One deliberate departure, recorded in docs/fidelity.md: this takes its data as values
//  and never touches the network. Upstream can fetch a year of contributions from a public
//  API given a username, which is convenient on a page and wrong in a component library: a
//  view that makes its own requests cannot be tested, cannot be previewed offline, and
//  gives an application no say over caching, failure or when it happens.
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

/// A contribution heatmap with a footer that opens into a ranked list.
///
/// ```swift
/// GitHubActivity(contributions: days, repos: repositories)
/// ```
///
/// Under Reduce Motion the cells appear without sweeping in and the footer opens without
/// springing.
public struct GitHubActivity: View {
    private let contributions: [GitHubContribution]
    private let repos: [GitHubRepoContribution]
    private let accent: Color
    private let cellSize: Double
    private let months: Int
    private let label: String
    private let showsMonths: Bool

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var expanded = false
    @State private var swept = false
    @Namespace private var avatars

    /// How many avatars the collapsed footer shows before it stops.
    private static var stackLimit: Int {
        3
    }

    /// How far apart two columns start appearing, in seconds.
    private static var columnStagger: Double {
        0.012
    }

    /// How long a cell takes to appear.
    private static var cellFade: Double {
        0.2
    }

    /// The panel's spring, from upstream's `SPRING`.
    private static var panelSpring: Animation {
        .spring(duration: 0.62, bounce: 0.2)
    }

    /// The header's, which bounces harder so it arrives with more life than the rows.
    private static var headerSpring: Animation {
        .spring(duration: 0.62, bounce: 0.45)
    }

    /// The rows', which wait a beat so the panel has opened before they arrive.
    private static var rowSpring: Animation {
        .spring(duration: 0.62, bounce: 0.26)
    }

    /// How far a row starts from where it lands, in points.
    private static var rowOffset: Double {
        16
    }

    /// Creates a heatmap.
    ///
    /// - Parameters:
    ///   - contributions: One entry per day, oldest first.
    ///   - repos: The repositories the contributions went to, in whatever order you want them ranked.
    ///   - accent: The colour the cells are drawn in. Defaults to GitHub's green.
    ///   - cellSize: How large one cell is, in points.
    ///   - months: How many months to show.
    ///   - label: The footer's wording.
    ///   - showsMonths: Whether to label the months above the grid.
    public init(
        contributions: [GitHubContribution],
        repos: [GitHubRepoContribution] = [],
        accent: Color = Color(hex: "#39D353"),
        cellSize: Double = 11,
        months: Int = 12,
        label: String = "Top contributions in:",
        showsMonths: Bool = false
    ) {
        self.contributions = contributions
        self.repos = repos
        self.accent = accent
        self.cellSize = cellSize
        self.months = months
        self.label = label
        self.showsMonths = showsMonths
    }

    private var gap: Double {
        gitHubCellGap(cellSize: cellSize)
    }

    /// The days arranged into weeks of seven, cut to the months asked for.
    private var weeks: [[GitHubContribution]] {
        let all = stride(from: 0, to: contributions.count, by: 7).map {
            Array(contributions[$0 ..< min($0 + 7, contributions.count)])
        }
        return Array(all.suffix(gitHubWeeks(months: months)))
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                if showsMonths { monthLabels }
                columns
            }
        }
        // The year is browsable rather than trimmed. Upstream fits the columns to the card
        // because a web page is as wide as the window; a component on a phone is as wide as
        // it is given, and dropping months to fit would quietly change what it says.
        // Recorded in docs/fidelity.md.
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .defaultScrollAnchor(.trailing)
        .padding(16)
        // Room under the grid for the footer, which sits over the card rather than in it.
        .padding(.bottom, 52)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.background)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                }
        }
        .overlay(alignment: .bottom) { footer }
        .task { await sweep() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Contribution activity")
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { column, week in
                VStack(spacing: gap) {
                    ForEach(week) { day in
                        cell(day)
                    }
                }
                .modifier(
                    ColumnSweep(
                        // Each column starts a little after the one before, so the year
                        // draws itself left to right rather than appearing all at once.
                        delay: reduceMotion ? 0 : Double(column) * Self.columnStagger,
                        duration: reduceMotion ? 0 : Self.cellFade
                    )
                )
            }
        }
    }

    private func cell(_ day: GitHubContribution) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(theme.foreground.opacity(0.08))
            .frame(width: cellSize, height: cellSize)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accent.opacity(gitHubLevelOpacity(day.level)))
            }
            .accessibilityLabel(describe(day))
    }

    private var monthLabels: some View {
        HStack(alignment: .bottom, spacing: gap) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { column, week in
                Text(monthLabel(at: column, week: week) ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.glyph)
                    .fixedSize()
                    .frame(width: cellSize, alignment: .leading)
            }
        }
        // The labels wait for the grid to finish drawing itself, then resolve out of a
        // blur rather than fading, so they read as settling onto the year rather than
        // being switched on over it.
        .blur(radius: swept || reduceMotion ? 0 : 6)
        .opacity(swept || reduceMotion ? 1 : 0)
        .animation(
            reduceMotion ? nil : .rareUICurve(RareUIMotion.easeOutQuint, duration: 0.45),
            value: swept
        )
    }

    private var footer: some View {
        Group {
            if expanded {
                expandedPanel
            } else {
                collapsedFooter
            }
        }
        .padding(12)
        .animation(reduceMotion ? nil : Self.panelSpring, value: expanded)
    }

    private var collapsedFooter: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.glyph)

            HStack(spacing: -8) {
                ForEach(repos.prefix(Self.stackLimit)) { repo in
                    avatar(repo)
                        .matchedGeometryEffect(id: repo.id, in: avatars)
                }
            }

            Spacer(minLength: 0)
            chevron
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(theme.surface))
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.glyph)
                Spacer(minLength: 0)
                chevron
            }
            .modifier(PanelArrival(spring: reduceMotion ? nil : Self.headerSpring, offset: 0))

            ForEach(Array(repos.enumerated()), id: \.element.id) { index, repo in
                HStack(spacing: 10) {
                    avatar(repo)
                        .matchedGeometryEffect(id: repo.id, in: avatars)
                    Text(repo.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.foreground)
                    Spacer(minLength: 0)
                    Text("\(repo.count)")
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(theme.glyph)
                }
                .modifier(
                    PanelArrival(
                        spring: reduceMotion ? nil : Self.rowSpring.delay(0.08 + Double(index) * 0.03),
                        offset: Self.rowOffset
                    )
                )
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.surface))
    }

    private func avatar(_ repo: GitHubRepoContribution) -> some View {
        Circle()
            .fill(theme.background)
            .frame(width: 28, height: 28)
            .overlay {
                Text(String(repo.name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.foreground)
            }
            .overlay { Circle().strokeBorder(theme.border, lineWidth: 1) }
    }

    private var chevron: some View {
        Button {
            expanded.toggle()
        } label: {
            Image(systemName: "chevron.up")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.glyph)
                .rotationEffect(.degrees(expanded ? 180 : 0))
                .frame(width: 22, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? "Hide repositories" : "Show repositories")
    }

    private func monthLabel(at column: Int, week: [GitHubContribution]) -> String? {
        guard let first = week.first else { return nil }
        let month = Calendar.current.component(.month, from: first.date)
        guard column > 0 else { return Self.monthNames[month - 1] }

        let previous = weeks[column - 1].first.map {
            Calendar.current.component(.month, from: $0.date)
        }
        // Only the first week of a month is labelled, and only when the month has at least
        // three weeks on screen: any fewer and the word is wider than the run it names.
        guard previous != month else { return nil }
        let remaining = weeks[column...].prefix {
            $0.first.map { Calendar.current.component(.month, from: $0.date) } == month
        }
        return remaining.count >= 3 ? Self.monthNames[month - 1] : nil
    }

    private func describe(_ day: GitHubContribution) -> String {
        let noun = day.count == 1 ? "contribution" : "contributions"
        return "\(day.count) \(noun) on \(day.date.formatted(date: .abbreviated, time: .omitted))"
    }

    private func sweep() async {
        guard !reduceMotion else {
            swept = true
            return
        }
        let total = Double(weeks.count) * Self.columnStagger + Self.cellFade
        try? await Task.sleep(for: .seconds(total))
        swept = true
    }

    private static let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]
}

/// A column of cells appearing, small and faint, in its turn.
private struct ColumnSweep: ViewModifier {
    let delay: Double
    let duration: Double

    @State private var arrived = false

    func body(content: Content) -> some View {
        content
            .opacity(arrived ? 1 : 0)
            .scaleEffect(arrived ? 1 : 0.4)
            .task {
                guard duration > 0 else {
                    arrived = true
                    return
                }
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.rareUICurve(RareUIMotion.easeOutQuint, duration: duration)) {
                    arrived = true
                }
            }
    }
}

/// A row of the opened panel rising into place.
private struct PanelArrival: ViewModifier {
    let spring: Animation?
    let offset: Double

    @State private var arrived = false

    func body(content: Content) -> some View {
        content
            .opacity(arrived ? 1 : 0)
            .offset(x: arrived ? 0 : offset, y: arrived ? 0 : offset)
            .onAppear {
                guard let spring else {
                    arrived = true
                    return
                }
                withAnimation(spring) { arrived = true }
            }
    }
}
