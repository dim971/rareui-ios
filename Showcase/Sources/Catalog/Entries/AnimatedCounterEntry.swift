import RareUI
import SwiftUI

@MainActor
let animatedCounterEntry = CatalogEntry(
    "Animated Counter",
    summary: "An odometer. Each digit is a wheel that rolls to its new face.",
    demos: [
        Demo(
            "Up and down",
            note: "The roll follows the value: up when it grows, down when it shrinks.",
            code: """
            AnimatedCounter(value: total)
            """
        ) { CounterPlayground(start: 1234, step: 111, decimals: 0) },

        Demo(
            "Currency",
            note: "Two decimal places, with a symbol in front.",
            code: """
            AnimatedCounter(value: revenue, decimals: 2, prefix: "$")
            """
        ) { CounterPlayground(start: 4820.5, step: 137.25, decimals: 2, prefix: "$") },

        Demo(
            "Indian grouping",
            note: "Three at the end, pairs above it: 12,34,567 rather than 1,234,567.",
            code: """
            AnimatedCounter(value: population, grouping: .indian)
            """
        ) { CounterPlayground(start: 1_234_567, step: 111_111, decimals: 0, grouping: .indian) },

        Demo(
            "Padded",
            note: "A minimum width, so the number never changes size. Useful for a timer.",
            code: """
            AnimatedCounter(value: count, padStart: 6, separator: "")
            """
        ) { CounterPlayground(start: 42, step: 7, decimals: 0, padStart: 6, separator: "") },

        Demo(
            "Faster and slower",
            note: "The duration is Motion's visual duration, so it is what the roll feels like.",
            code: """
            AnimatedCounter(value: score, duration: 0.2)
            AnimatedCounter(value: score, duration: 1.6)
            """
        ) { CounterPace() }
    ]
) {
    AnimatedCounter(value: 1234)
        .font(.title3.weight(.semibold))
}

/// A counter with the two buttons that make it interesting.
private struct CounterPlayground: View {
    let start: Double
    let step: Double
    let decimals: Int
    var padStart: Int = 1
    var separator: String = ","
    var grouping: CounterGrouping = .western
    var prefix: String?

    @State private var value: Double

    init(
        start: Double,
        step: Double,
        decimals: Int,
        padStart: Int = 1,
        separator: String = ",",
        grouping: CounterGrouping = .western,
        prefix: String? = nil
    ) {
        self.start = start
        self.step = step
        self.decimals = decimals
        self.padStart = padStart
        self.separator = separator
        self.grouping = grouping
        self.prefix = prefix
        _value = State(initialValue: start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            counter
                .font(.system(size: 36, weight: .semibold))

            HStack(spacing: 10) {
                Button("Less") { value -= step }
                Button("More") { value += step }
                Button("Reset") { value = start }
                Spacer()
            }
            .buttonStyle(.bordered)
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private var counter: some View {
        if let prefix {
            AnimatedCounter(
                value: value,
                decimals: decimals,
                padStart: padStart,
                separator: separator,
                grouping: grouping,
                prefix: prefix
            )
        } else {
            AnimatedCounter(
                value: value,
                decimals: decimals,
                padStart: padStart,
                separator: separator,
                grouping: grouping
            )
        }
    }
}

/// The same value at two paces, side by side, which is the only way to feel the difference.
private struct CounterPace: View {
    @State private var value: Double = 5000

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledContent("0.2s") {
                AnimatedCounter(value: value, duration: 0.2)
                    .font(.system(size: 28, weight: .semibold))
            }
            LabeledContent("1.6s") {
                AnimatedCounter(value: value, duration: 1.6)
                    .font(.system(size: 28, weight: .semibold))
            }
            Button("Roll") { value += Double.random(in: 1000 ... 9000) }
                .buttonStyle(.bordered)
                .font(.subheadline)
        }
    }
}
