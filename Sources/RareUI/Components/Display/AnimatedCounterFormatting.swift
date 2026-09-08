//
//  AnimatedCounterFormatting.swift
//  The arithmetic behind AnimatedCounter, ported from the `measure`, `format`, `group`
//  and `toCells` functions in upstream's `components/ui/animated-counter.tsx`.
//
//  It is separated from the view because it is the part that can be checked exactly.
//  Whether a roll feels right is a matter for the showcase; whether 12345678 groups as
//  1,23,45,678 in Indian digits is a matter for a test.
//

import Foundation

/// How the digits before the decimal separator are grouped.
public enum CounterGrouping: String, Sendable, CaseIterable {
    /// Groups of three all the way up, as in `1,234,567`.
    case western
    /// Three at the end and pairs above it, as in `12,34,567`.
    case indian
}

/// The measured shape of a value: what will actually be drawn, and how fast.
struct CounterShape: Equatable {
    /// The value, with anything that is not a finite number replaced by zero.
    let amount: Double
    /// The value as a whole number, scaled up past the decimal point.
    let scaled: Int
    /// How many decimal places are shown.
    let places: Int
    /// The roll duration, confined to something a spring can actually do.
    let pace: Double
    /// How many digit columns there are, before any separators.
    let width: Int
}

/// Past this, the digits are floating point noise rather than information.
///
/// It is JavaScript's `Number.MAX_SAFE_INTEGER`, which upstream clamps to for the same
/// reason: `String(scaled)` turns exponential above 1e21 and starts skipping integers
/// well before that.
private let maxSafeInteger = 9_007_199_254_740_991

private let maxDecimals = 15.0
private let maxPad = 24.0
private let minDuration = 0.01
private let maxDuration = 60.0

/// Works out what a value will look like before anything is laid out.
///
/// - Parameters:
///   - value: The number to show.
///   - decimals: How many decimal places to show.
///   - padStart: The minimum number of whole digits, padded with leading zeros.
///   - duration: The roll duration, in seconds.
/// - Returns: The measured shape.
func counterShape(value: Double, decimals: Int, padStart: Int, duration: Double) -> CounterShape {
    // A value that is not a number would make the previous-value comparison true forever,
    // so the counter would never roll again.
    let amount = value.isFinite ? value : 0
    let places = Int(rareUIClamp(Double(decimals), 0, maxDecimals))
    let pad = Int(rareUIClamp(Double(padStart), 1, maxPad))

    let raised = (abs(amount) * pow(10, Double(places))).rounded()
    let scaled = raised.isFinite ? min(Double(maxSafeInteger), raised) : 0

    let whole = Int(scaled)
    return CounterShape(
        amount: amount,
        scaled: whole,
        places: places,
        pace: rareUIClamp(duration, minDuration, maxDuration),
        width: max(String(whole).count, places + pad)
    )
}

/// Inserts a separator between groups of digits.
///
/// - Parameters:
///   - digits: The whole part, as digits only.
///   - separator: The separator to insert. An empty separator leaves the digits alone.
///   - grouping: Which grouping to use.
/// - Returns: The grouped digits.
func counterGroup(_ digits: String, separator: String, grouping: CounterGrouping) -> String {
    guard !separator.isEmpty else { return digits }
    guard grouping == .indian else { return chunked(digits, every: 3, separator: separator) }

    // Indian grouping is three at the end and pairs the rest of the way up, so the
    // trailing group is split off before the pairs are counted.
    let head = String(digits.dropLast(3))
    guard !head.isEmpty else { return digits }
    return chunked(head, every: 2, separator: separator) + separator + String(digits.suffix(3))
}

/// Inserts a separator every `size` characters, counting from the right.
private func chunked(_ digits: String, every size: Int, separator: String) -> String {
    var result = ""
    let characters = Array(digits)
    for (index, character) in characters.enumerated() {
        // Never at the start, which is what upstream's `\B` in the regex is there for.
        if index > 0, (characters.count - index) % size == 0 { result += separator }
        result.append(character)
    }
    return result
}

/// Renders a measured shape as the string the counter will show.
///
/// - Parameters:
///   - shape: The measured shape.
///   - separator: The grouping separator.
///   - decimalSeparator: The decimal separator.
///   - grouping: Which grouping to use.
/// - Returns: The formatted digits, without any sign.
func counterFormat(
    _ shape: CounterShape,
    separator: String,
    decimalSeparator: String,
    grouping: CounterGrouping
) -> String {
    let raw = String(shape.scaled)
    let padded = String(repeating: "0", count: max(0, shape.width - raw.count)) + raw
    let wholeDigits = String(padded.dropLast(shape.places))
    let whole = counterGroup(
        wholeDigits.isEmpty ? "0" : wholeDigits,
        separator: separator,
        grouping: grouping
    )
    guard shape.places > 0 else { return whole }
    return whole + decimalSeparator + String(padded.suffix(shape.places))
}

/// One column of the counter.
enum CounterCell: Identifiable, Equatable {
    /// A digit that rolls. The place is its distance from the right.
    case digit(place: Int, value: Int)
    /// A separator or any other character that does not roll.
    case mark(place: Int, run: Int, character: Character)

    /// The identity a column keeps across value changes.
    ///
    /// Digits are keyed by distance from the right rather than by position, so a number
    /// gaining a place shifts the existing columns along instead of tearing all of them
    /// down and building new ones.
    var id: String {
        switch self {
        case let .digit(place, _): "digit-\(place)"
        case let .mark(place, run, _): "mark-\(place)-\(run)"
        }
    }
}

/// Splits formatted digits into the columns that get drawn.
///
/// - Parameters:
///   - characters: The formatted string, from ``counterFormat(_:separator:decimalSeparator:grouping:)``.
///   - width: The shape's digit count, which anchors the place numbering.
/// - Returns: One cell per character.
func counterCells(_ characters: String, width: Int) -> [CounterCell] {
    var cells: [CounterCell] = []
    var seen = 0
    // Only digits advance the place, so without the run counter a two character
    // separator would give two marks the same identity.
    var run = 0

    for character in characters {
        if character.isASCII, character.isNumber {
            run = 0
            cells.append(.digit(place: width - seen, value: character.wholeNumberValue ?? 0))
            seen += 1
        } else {
            cells.append(.mark(place: width - seen, run: run, character: character))
            run += 1
        }
    }
    return cells
}
