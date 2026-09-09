import RareUI
import SwiftUI

@MainActor
let animatedCounterEntry = CatalogEntry(
    "Animated Counter",
    summary: "An odometer. Each digit is a wheel that rolls to its new face.",
    demos: [
        Demo(
            "Drag the ruler",
            note: """
            Upstream's own demonstration, down to its numbers: forty-one ticks over a \
            hundred and fifty thousand, and a dash that is a tick rather than an overlay, \
            so it lands dead on one. The ruler is the demonstration and not the component: \
            upstream draws it on the page, out of a range input and a row of spans.
            """,
            code: """
            AnimatedCounter(value: value, duration: 0.5, grouping: .indian, prefix: "$")
            """
        ) { CounterRuler() },

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

/// Upstream's own demonstration of the counter: a ruler you drag.
///
/// It lives here rather than in the library because it lives on the page rather than in the
/// component upstream, where it is a range input with a row of spans over it. The dash is
/// one of the ticks rather than something drawn on top of them, which is what makes it land
/// exactly on a tick instead of between two.
private struct CounterRuler: View {
    /// How far the ruler goes, from upstream's `MAX`.
    private static let maximum = 150_000.0
    /// How many ticks it is drawn with, from `TICKS`.
    private static let ticks = 41
    /// How long the counter takes to roll, from `ROLL`.
    private static let roll = 0.5
    /// Upstream's `ACCENT`.
    private static let accent = Color(hex: "#FC4C01")

    @Environment(\.colorScheme) private var colorScheme
    @State private var value = 12480.0

    /// The ruler only changes when the dash crosses a tick, not on every pixel of the drag.
    private var marker: Int {
        min(max(Int((value / Self.maximum * Double(Self.ticks - 1)).rounded()), 0), Self.ticks - 1)
    }

    var body: some View {
        VStack(spacing: 56) {
            AnimatedCounter(value: value, duration: Self.roll, grouping: .indian, prefix: "$")
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .tracking(-0.02 * 48)

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(0 ..< Self.ticks, id: \.self) { index in
                        tick(at: index)
                        if index < Self.ticks - 1 { Spacer(minLength: 0) }
                    }
                }
                .frame(height: 32, alignment: .bottom)
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            guard proxy.size.width > 0 else { return }
                            let fraction = drag.location.x / proxy.size.width
                            value = min(max(fraction * Self.maximum, 0), Self.maximum)
                        }
                )
            }
            .frame(height: 32)
            .accessibilityElement()
            .accessibilityLabel("Counter value")
            .accessibilityValue("\(Int(value))")
        }
    }

    private func tick(at index: Int) -> some View {
        let isMarker = index == marker
        let passed = index < marker
        // Upstream's two tick colours, which are not the theme's: the passed ones take the
        // track colour and the ones still ahead take a pale grey of their own.
        let ahead = colorScheme == .dark ? Color(hex: "#3C3C43") : Color(hex: "#E7E7EF")
        let behind = colorScheme == .dark ? Color(hex: "#EBEBF5") : Color(hex: "#3C3C43")

        return Capsule()
            .fill(isMarker ? Self.accent : passed ? behind : ahead)
            .frame(width: isMarker ? 3 : 2, height: isMarker ? 28 : passed ? 20 : 14)
            .animation(.easeInOut(duration: 0.2), value: marker)
    }
}
