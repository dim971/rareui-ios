//
//  AnimatedCounterTests.swift
//  The counter is mostly arithmetic wearing an animation, and the arithmetic is where it
//  can be wrong without looking wrong. Grouping, padding, rounding and the wheel's aim
//  are all checked here against upstream's `animated-counter.tsx`.
//

@testable import RareUI
import Testing

@Suite("Counter shape")
struct CounterShapeTests {
    @Test("a plain integer needs as many columns as it has digits")
    func integer() {
        let shape = counterShape(value: 1234, decimals: 0, padStart: 1, duration: 0.6)
        #expect(shape.scaled == 1234)
        #expect(shape.places == 0)
        #expect(shape.width == 4)
    }

    @Test("decimals are scaled into the whole number and counted as columns")
    func decimals() {
        let shape = counterShape(value: 12.34, decimals: 2, padStart: 1, duration: 0.6)
        #expect(shape.scaled == 1234)
        #expect(shape.places == 2)
        #expect(shape.width == 4)
    }

    @Test("padStart sets a floor on the width, which is what stops a timer jittering")
    func padding() {
        let shape = counterShape(value: 7, decimals: 0, padStart: 6, duration: 0.6)
        #expect(shape.width == 6)
    }

    @Test("the sign is kept separately, so the columns are the same either way")
    func negative() {
        let up = counterShape(value: 42, decimals: 0, padStart: 1, duration: 0.6)
        let down = counterShape(value: -42, decimals: 0, padStart: 1, duration: 0.6)
        #expect(up.scaled == down.scaled)
        #expect(down.amount == -42)
    }

    @Test("a value that is not a number becomes zero rather than poisoning every comparison")
    func notANumber() {
        #expect(counterShape(value: .nan, decimals: 0, padStart: 1, duration: 0.6).amount == 0)
        #expect(counterShape(value: .infinity, decimals: 0, padStart: 1, duration: 0.6).amount == 0)
    }

    @Test("decimals, padding and duration are all confined to what can actually be drawn")
    func limits() {
        let wild = counterShape(value: 1, decimals: 99, padStart: 999, duration: 1e6)
        #expect(wild.places == 15)
        #expect(wild.pace == 60)
        // 15 decimal places plus the 24 place padding ceiling.
        #expect(wild.width == 39)

        let tiny = counterShape(value: 1, decimals: -5, padStart: -5, duration: 0)
        #expect(tiny.places == 0)
        #expect(tiny.pace == 0.01)
        #expect(tiny.width == 1)
    }
}

@Suite("Counter grouping")
struct CounterGroupingTests {
    @Test("western grouping is threes all the way up")
    func western() {
        #expect(counterGroup("1", separator: ",", grouping: .western) == "1")
        #expect(counterGroup("123", separator: ",", grouping: .western) == "123")
        #expect(counterGroup("1234", separator: ",", grouping: .western) == "1,234")
        #expect(counterGroup("1234567", separator: ",", grouping: .western) == "1,234,567")
        #expect(counterGroup("1000000", separator: ",", grouping: .western) == "1,000,000")
    }

    @Test("indian grouping is three at the end and pairs above it")
    func indian() {
        #expect(counterGroup("123", separator: ",", grouping: .indian) == "123")
        #expect(counterGroup("1234", separator: ",", grouping: .indian) == "1,234")
        #expect(counterGroup("1234567", separator: ",", grouping: .indian) == "12,34,567")
        #expect(counterGroup("123456789", separator: ",", grouping: .indian) == "12,34,56,789")
    }

    @Test("an empty separator leaves the digits alone")
    func noSeparator() {
        #expect(counterGroup("1234567", separator: "", grouping: .western) == "1234567")
        #expect(counterGroup("1234567", separator: "", grouping: .indian) == "1234567")
    }

    @Test("a separator of more than one character is inserted whole")
    func longSeparator() {
        #expect(counterGroup("1234567", separator: " ", grouping: .western) == "1 234 567")
    }
}

@Suite("Counter formatting")
struct CounterFormattingTests {
    private func format(
        _ value: Double,
        decimals: Int = 0,
        padStart: Int = 1,
        separator: String = ",",
        decimalSeparator: String = ".",
        grouping: CounterGrouping = .western
    ) -> String {
        let shape = counterShape(value: value, decimals: decimals, padStart: padStart, duration: 0.6)
        return counterFormat(
            shape,
            separator: separator,
            decimalSeparator: decimalSeparator,
            grouping: grouping
        )
    }

    @Test("whole numbers are grouped and nothing else")
    func plain() {
        #expect(format(0) == "0")
        #expect(format(1234) == "1,234")
        #expect(format(-1234) == "1,234", "the sign is drawn separately")
    }

    @Test("decimals keep their trailing zeros, which is the point of a fixed width")
    func decimals() {
        #expect(format(12.5, decimals: 2) == "12.50")
        #expect(format(0.5, decimals: 2) == "0.50")
        #expect(format(1234.5, decimals: 2) == "1,234.50")
    }

    @Test("a value smaller than the smallest shown place rounds into it")
    func rounding() {
        #expect(format(0.004, decimals: 2) == "0.00")
        #expect(format(0.005, decimals: 2) == "0.01", "halves round away from zero, as in JavaScript")
        #expect(format(0.9999, decimals: 2) == "1.00")
    }

    @Test("padding fills from the left with zeros")
    func padding() {
        #expect(format(7, padStart: 4, separator: "") == "0007")
        #expect(format(7.5, decimals: 1, padStart: 3, separator: "") == "007.5")
    }

    @Test("the decimal separator is independent of the grouping one")
    func continental() {
        #expect(format(1234.5, decimals: 2, separator: ".", decimalSeparator: ",") == "1.234,50")
    }
}

@Suite("Counter columns")
struct CounterCellTests {
    @Test("digits are keyed by distance from the right, so a new place shifts rather than remounts")
    func stableKeys() {
        let narrow = counterCells("999", width: 3)
        let wide = counterCells("1,000", width: 4)

        // The three rightmost columns keep their identity across the change from 999 to 1000.
        #expect(narrow.compactMap(digitPlace) == [3, 2, 1])
        #expect(wide.compactMap(digitPlace) == [4, 3, 2, 1])
    }

    @Test("a separator is a column too, and does not advance the place")
    func marks() {
        let cells = counterCells("1,234", width: 4)
        #expect(cells.count == 5)
        if case let .mark(place, run, character) = cells[1] {
            #expect(character == ",")
            #expect(place == 3)
            #expect(run == 0)
        } else {
            Issue.record("the second column should be the separator")
        }
    }

    @Test("every column has an identity of its own, including repeated separators")
    func uniqueIdentities() {
        let cells = counterCells("1,234,567.89", width: 9)
        #expect(Set(cells.map(\.id)).count == cells.count)
    }

    private func digitPlace(_ cell: CounterCell) -> Int? {
        if case let .digit(place, _) = cell { return place }
        return nil
    }
}

@Suite("Digit wheel aim")
struct DigitWheelTests {
    @Test("a wheel already heading at its face is left alone")
    func noChange() {
        #expect(wheelGoal(aimedAt: 4, from: 4, digit: 4, heading: 1) == 4)
        #expect(wheelGoal(aimedAt: 14, from: 14, digit: 4, heading: -1) == 14)
    }

    @Test("turning up adds the shortest forward distance to the face")
    func up() {
        #expect(wheelGoal(aimedAt: 3, from: 3, digit: 5, heading: 1) == 5)
        #expect(wheelGoal(aimedAt: 8, from: 8, digit: 1, heading: 1) == 11)
    }

    @Test("turning down subtracts the shortest backward distance")
    func down() {
        #expect(wheelGoal(aimedAt: 5, from: 5, digit: 3, heading: -1) == 3)
        #expect(wheelGoal(aimedAt: 1, from: 1, digit: 8, heading: -1) == -2)
    }

    @Test("nine to zero rolls forward into the repeated face rather than back through eight")
    func wrap() {
        // The eleventh face is a second zero, so a single step forward lands on it and the
        // wheel never travels the nine faces backward to reach the same glyph.
        #expect(wheelGoal(aimedAt: 9, from: 9, digit: 0, heading: 1) == 10)
        #expect(wheelGoal(aimedAt: 10, from: 10, digit: 9, heading: -1) == 9)
    }

    @Test("aiming starts from where the wheel is, not from where it was sent")
    func aimsFromLive() {
        // Mid roll: aimed at 7, currently passing 5.5, and the digit becomes 9. Aiming from
        // the goal would ask for 9; aiming from the live position asks for 9 as well here,
        // but the distance travelled is what differs, and it is measured from 5.5.
        let goal = wheelGoal(aimedAt: 7, from: 5.5, digit: 9, heading: 1)
        #expect(goal == 9)
        #expect(goal - 5.5 == 3.5)
    }

    @Test("the aim always lands on the requested face")
    func alwaysLands() {
        for digit in 0 ... 9 {
            for start in stride(from: -20.0, through: 20.0, by: 0.5) {
                for heading in [1.0, -1.0] {
                    let goal = wheelGoal(aimedAt: start, from: start, digit: digit, heading: heading)
                    #expect(
                        abs(rareUIMod(goal, 10) - Double(digit)) < 1e-9,
                        "aiming at \(digit) from \(start) heading \(heading) landed on \(goal)"
                    )
                }
            }
        }
    }
}
