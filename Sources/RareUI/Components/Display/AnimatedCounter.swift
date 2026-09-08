//
//  AnimatedCounter.swift
//  A port of upstream's `components/ui/animated-counter.tsx`.
//
//  An odometer. Each digit is a wheel of eleven faces, the ten digits plus a repeat of
//  zero so the wrap from nine back to zero lands on an identical face rather than
//  spinning the long way round. The wheel is masked top and bottom so a digit in motion
//  fades out of the window instead of being cut off by a hard edge.
//

import SwiftUI

/// A number that rolls to its new value, one digit wheel at a time.
///
/// ```swift
/// AnimatedCounter(value: total)
/// AnimatedCounter(value: revenue, decimals: 2, prefix: { Text("$") })
/// ```
///
/// The roll is direction aware: a value going up rolls its wheels up, a value coming
/// down rolls them down. Places that appear as the number grows roll in from zero
/// rather than snapping into existence, and places that disappear fade out.
///
/// Under Reduce Motion the digits change without rolling, which is what upstream does
/// under `prefers-reduced-motion`.
public struct AnimatedCounter<Prefix: View, Suffix: View>: View {
    private let value: Double
    private let decimals: Int
    private let duration: Double
    private let padStart: Int
    private let separator: String
    private let decimalSeparator: String
    private let grouping: CounterGrouping
    private let prefix: Prefix
    private let suffix: Suffix

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The faces each wheel started on when the counter first appeared.
    ///
    /// A place that was already there at that point starts settled on its digit; a place
    /// that appears later is absent from this and starts from zero, so it rolls in.
    @State private var seed: [Int: Int]

    /// The natural height of one line of the current font, measured rather than assumed
    /// because the caller chooses the font.
    @State private var lineBox: CGFloat = 0

    /// Upstream draws each face in a box `1.5em` tall, which leaves enough air above and
    /// below the glyph that the mask's fade never touches it. SwiftUI's line box is closer
    /// to `1.2em`, so it is opened out by this much to put the glyph back in the clear.
    /// See docs/fidelity.md.
    private static var lineBoxToFaceBox: CGFloat {
        1.25
    }

    /// Motion's `{ visualDuration, bounce: 0.18 }`, which is SwiftUI's `.spring(duration:bounce:)`.
    private static var bounce: Double {
        0.18
    }

    /// `LEAVE` upstream: a column on its way out goes quickly and does not spring.
    private static var leaveDuration: Double {
        0.18
    }

    private var faceHeight: CGFloat {
        lineBox * Self.lineBoxToFaceBox
    }

    /// Creates a counter with something on either side of it.
    ///
    /// - Parameters:
    ///   - value: The number to show.
    ///   - decimals: How many decimal places to show. Defaults to none.
    ///   - duration: How long a roll takes, in seconds. Defaults to `0.6`.
    ///   - padStart: The minimum number of whole digits, padded with leading zeros.
    ///   - separator: The grouping separator. Pass `""` for none.
    ///   - decimalSeparator: The decimal separator.
    ///   - grouping: How the whole digits are grouped.
    ///   - prefix: A view shown before the number, such as a currency symbol.
    ///   - suffix: A view shown after it, such as a unit.
    public init(
        value: Double,
        decimals: Int = 0,
        duration: Double = 0.6,
        padStart: Int = 1,
        separator: String = ",",
        decimalSeparator: String = ".",
        grouping: CounterGrouping = .western,
        @ViewBuilder prefix: () -> Prefix,
        @ViewBuilder suffix: () -> Suffix
    ) {
        self.value = value
        self.decimals = decimals
        self.duration = duration
        self.padStart = padStart
        self.separator = separator
        self.decimalSeparator = decimalSeparator
        self.grouping = grouping
        self.prefix = prefix()
        self.suffix = suffix()

        // The seed is worked out here rather than on appearance so the first frame shows
        // the number settled. Deriving it in `onAppear` would show every wheel at zero
        // for one frame and then roll the whole number in, which is not what upstream does.
        let shape = counterShape(value: value, decimals: decimals, padStart: padStart, duration: duration)
        let characters = counterFormat(
            shape,
            separator: separator,
            decimalSeparator: decimalSeparator,
            grouping: grouping
        )
        var faces: [Int: Int] = [:]
        for case let .digit(place, digit) in counterCells(characters, width: shape.width) {
            faces[place] = digit
        }
        _seed = State(initialValue: faces)
    }

    public var body: some View {
        let shape = counterShape(value: value, decimals: decimals, padStart: padStart, duration: duration)
        let characters = counterFormat(
            shape,
            separator: separator,
            decimalSeparator: decimalSeparator,
            grouping: grouping
        )
        let cells = counterCells(characters, width: shape.width)
        // A value that rounds away to nothing is not negative, however it was written.
        let negative = shape.amount < 0 && shape.scaled > 0

        HStack(spacing: 0) {
            prefix
            if negative { Text(verbatim: "-") }

            ForEach(cells) { cell in
                switch cell {
                case let .digit(place, digit):
                    DigitWheel(
                        digit: digit,
                        amount: shape.amount,
                        from: seed[place] ?? 0,
                        pace: shape.pace,
                        faceHeight: faceHeight,
                        reduceMotion: reduceMotion
                    )
                    .transition(columnTransition(pace: shape.pace))
                case let .mark(_, _, character):
                    Text(String(character))
                        .transition(columnTransition(pace: shape.pace))
                }
            }

            suffix
        }
        .monospacedDigit()
        .animation(
            RareUIMotion.settling(
                .spring(duration: shape.pace, bounce: Self.bounce),
                reduceMotion: reduceMotion
            ),
            value: characters
        )
        // The number is drawn as a stack of wheels, which VoiceOver would otherwise read
        // as eleven faces per digit. Upstream solves the same problem with an sr-only span.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((negative ? "-" : "") + characters)
        .background {
            Text(verbatim: "0")
                .monospacedDigit()
                .hidden()
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { lineBox = proxy.size.height }
                            .onChange(of: proxy.size.height) { _, height in lineBox = height }
                    }
                }
        }
        // Nothing can be laid out until the font has been measured. One invisible frame
        // is cheaper than one frame at the wrong size.
        .opacity(lineBox > 0 ? 1 : 0)
    }

    private func columnTransition(pace: Double) -> AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .opacity.animation(.spring(duration: pace, bounce: Self.bounce)),
            removal: .opacity.animation(
                .rareUICurve(RareUIMotion.easeOutQuint, duration: Self.leaveDuration)
            )
        )
    }
}

// MARK: - Convenience initialisers

//
// The affixes are strings here rather than view builders. Two builder based initialisers,
// one taking a prefix and one taking a suffix, would be ambiguous under trailing closure
// syntax: `AnimatedCounter(value: total) { Text("$") }` cannot tell them apart, and the
// compiler's diagnostic for that is unhelpful. Strings cover the currency symbols and
// units these are almost always used for; the builder initialiser above is still there
// for an icon.

public extension AnimatedCounter where Prefix == EmptyView, Suffix == EmptyView {
    /// Creates a counter on its own.
    ///
    /// - Parameters:
    ///   - value: The number to show.
    ///   - decimals: How many decimal places to show. Defaults to none.
    ///   - duration: How long a roll takes, in seconds. Defaults to `0.6`.
    ///   - padStart: The minimum number of whole digits, padded with leading zeros.
    ///   - separator: The grouping separator. Pass `""` for none.
    ///   - decimalSeparator: The decimal separator.
    ///   - grouping: How the whole digits are grouped.
    init(
        value: Double,
        decimals: Int = 0,
        duration: Double = 0.6,
        padStart: Int = 1,
        separator: String = ",",
        decimalSeparator: String = ".",
        grouping: CounterGrouping = .western
    ) {
        self.init(
            value: value, decimals: decimals, duration: duration, padStart: padStart,
            separator: separator, decimalSeparator: decimalSeparator, grouping: grouping,
            prefix: { EmptyView() }, suffix: { EmptyView() }
        )
    }
}

public extension AnimatedCounter where Prefix == Text, Suffix == EmptyView {
    /// Creates a counter with something in front of it, such as a currency symbol.
    ///
    /// - Parameters:
    ///   - value: The number to show.
    ///   - decimals: How many decimal places to show. Defaults to none.
    ///   - duration: How long a roll takes, in seconds. Defaults to `0.6`.
    ///   - padStart: The minimum number of whole digits, padded with leading zeros.
    ///   - separator: The grouping separator. Pass `""` for none.
    ///   - decimalSeparator: The decimal separator.
    ///   - grouping: How the whole digits are grouped.
    ///   - prefix: The text shown before the number.
    init(
        value: Double,
        decimals: Int = 0,
        duration: Double = 0.6,
        padStart: Int = 1,
        separator: String = ",",
        decimalSeparator: String = ".",
        grouping: CounterGrouping = .western,
        prefix: String
    ) {
        self.init(
            value: value, decimals: decimals, duration: duration, padStart: padStart,
            separator: separator, decimalSeparator: decimalSeparator, grouping: grouping,
            prefix: { Text(prefix) }, suffix: { EmptyView() }
        )
    }
}

public extension AnimatedCounter where Prefix == EmptyView, Suffix == Text {
    /// Creates a counter with something after it, such as a unit.
    ///
    /// - Parameters:
    ///   - value: The number to show.
    ///   - decimals: How many decimal places to show. Defaults to none.
    ///   - duration: How long a roll takes, in seconds. Defaults to `0.6`.
    ///   - padStart: The minimum number of whole digits, padded with leading zeros.
    ///   - separator: The grouping separator. Pass `""` for none.
    ///   - decimalSeparator: The decimal separator.
    ///   - grouping: How the whole digits are grouped.
    ///   - suffix: The text shown after the number.
    init(
        value: Double,
        decimals: Int = 0,
        duration: Double = 0.6,
        padStart: Int = 1,
        separator: String = ",",
        decimalSeparator: String = ".",
        grouping: CounterGrouping = .western,
        suffix: String
    ) {
        self.init(
            value: value, decimals: decimals, duration: duration, padStart: padStart,
            separator: separator, decimalSeparator: decimalSeparator, grouping: grouping,
            prefix: { EmptyView() }, suffix: { Text(suffix) }
        )
    }
}

public extension AnimatedCounter where Prefix == Text, Suffix == Text {
    /// Creates a counter with text on both sides of it.
    ///
    /// - Parameters:
    ///   - value: The number to show.
    ///   - decimals: How many decimal places to show. Defaults to none.
    ///   - duration: How long a roll takes, in seconds. Defaults to `0.6`.
    ///   - padStart: The minimum number of whole digits, padded with leading zeros.
    ///   - separator: The grouping separator. Pass `""` for none.
    ///   - decimalSeparator: The decimal separator.
    ///   - grouping: How the whole digits are grouped.
    ///   - prefix: The text shown before the number.
    ///   - suffix: The text shown after it.
    init(
        value: Double,
        decimals: Int = 0,
        duration: Double = 0.6,
        padStart: Int = 1,
        separator: String = ",",
        decimalSeparator: String = ".",
        grouping: CounterGrouping = .western,
        prefix: String,
        suffix: String
    ) {
        self.init(
            value: value, decimals: decimals, duration: duration, padStart: padStart,
            separator: separator, decimalSeparator: decimalSeparator, grouping: grouping,
            prefix: { Text(prefix) }, suffix: { Text(suffix) }
        )
    }
}
