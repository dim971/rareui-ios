//
//  DigitWheel.swift
//  One column of AnimatedCounter, ported from the `Digit` component and the `useWheel`
//  hook in upstream's `components/ui/animated-counter.tsx`.
//

import SwiftUI

/// The eleven faces a wheel turns through.
///
/// Ten digits and a repeat of zero. Without the last one, the wrap from nine back to
/// zero would have to travel the whole way round the wheel instead of continuing on to
/// an identical face.
private let wheelFaces = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0]

/// The soft edge the wheel turns behind.
///
/// The stops are upstream's, and they are eased rather than a straight ramp: a linear
/// fade of the same width reads as a hard edge. The middle stays fully opaque from 22%
/// to 78%, which is where a resting glyph sits, so a digit that is not moving is solid.
private let wheelFade = LinearGradient(
    stops: [
        .init(color: .black.opacity(0), location: 0),
        .init(color: .black.opacity(0.06), location: 0.055),
        .init(color: .black.opacity(0.5), location: 0.11),
        .init(color: .black.opacity(0.94), location: 0.165),
        .init(color: .black, location: 0.22),
        .init(color: .black, location: 0.78),
        .init(color: .black.opacity(0.94), location: 0.835),
        .init(color: .black.opacity(0.5), location: 0.89),
        .init(color: .black.opacity(0.06), location: 0.945),
        .init(color: .black.opacity(0), location: 1)
    ],
    startPoint: .top,
    endPoint: .bottom
)

/// Turns the wheel by offsetting the stack of faces, one face per whole turn.
private struct WheelTurn: ViewModifier, Animatable {
    var position: Double
    let faceHeight: CGFloat
    let tracker: RareUILiveValue

    /// `ViewModifier` is main actor isolated and `Animatable` is not, so without this the
    /// conformance is rejected as crossing between the two.
    nonisolated var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    func body(content: Content) -> some View {
        tracker.value = position
        // The offset wraps with the position, which is why the eleventh face exists: at
        // the moment the wrap happens the face leaving the top and the face arriving are
        // the same glyph, so nothing jumps.
        return content.offset(y: -CGFloat(rareUIMod(position, 10)) * faceHeight)
    }
}

/// One digit of the counter, drawn as a wheel that turns to the digit it should show.
struct DigitWheel: View {
    let digit: Int
    /// The counter's whole value, which is how a wheel knows whether the number went up
    /// or down and therefore which way to turn.
    let amount: Double
    /// The face this wheel starts on.
    let from: Int
    let pace: Double
    let faceHeight: CGFloat
    let reduceMotion: Bool

    @State private var position: Double
    @State private var goal: Double
    @State private var tracker = RareUILiveValue()

    /// Motion's `{ visualDuration: pace, bounce: 0.18 }`.
    private static var bounce: Double {
        0.18
    }

    init(digit: Int, amount: Double, from: Int, pace: Double, faceHeight: CGFloat, reduceMotion: Bool) {
        self.digit = digit
        self.amount = amount
        self.from = from
        self.pace = pace
        self.faceHeight = faceHeight
        self.reduceMotion = reduceMotion
        _position = State(initialValue: Double(from))
        _goal = State(initialValue: Double(from))
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(wheelFaces.enumerated()), id: \.offset) { _, face in
                Text(verbatim: String(face))
                    .frame(height: faceHeight)
            }
        }
        .modifier(WheelTurn(position: position, faceHeight: faceHeight, tracker: tracker))
        .frame(height: faceHeight, alignment: .top)
        .clipped()
        .mask(wheelFade)
        .onAppear {
            tracker.value = position
            // A wheel that was already on screen when the counter appeared starts settled,
            // because its seed is its own digit. One that appeared later starts at zero
            // and rolls up into place.
            turn(heading: 1)
        }
        .onChange(of: amount) { old, new in
            turn(heading: new >= old ? 1 : -1)
        }
        .onChange(of: reduceMotion) { _, _ in
            turn(heading: 1)
        }
    }

    /// Re-aims the wheel at its digit and sets it going.
    ///
    /// - Parameter heading: `1` to turn up, `-1` to turn down.
    private func turn(heading: Double) {
        guard !reduceMotion else {
            goal = Double(digit)
            position = Double(digit)
            tracker.value = Double(digit)
            return
        }

        goal = wheelGoal(aimedAt: goal, from: tracker.value, digit: digit, heading: heading)
        withAnimation(.spring(duration: pace, bounce: Self.bounce)) {
            position = goal
        }
    }
}

/// Works out where a wheel should be aimed so that it lands showing `digit`.
///
/// The wheel's position is not confined to `0..<10`: it counts turns, and only its
/// remainder decides which face is showing. Aiming therefore means adding just enough to
/// reach the next occurrence of the face in the direction of travel, which is what keeps
/// a rising number rolling upward past nine into zero rather than spinning backward.
///
/// - Parameters:
///   - goal: Where the wheel is currently aimed.
///   - position: Where the wheel actually is, which is behind the goal while it moves.
///   - digit: The face it should end up showing.
///   - heading: `1` to turn up, `-1` to turn down.
/// - Returns: The new aim, unchanged when the wheel is already heading at that face.
func wheelGoal(aimedAt goal: Double, from position: Double, digit: Int, heading: Double) -> Double {
    let target = Double(digit)
    // Re-aim only when the face has actually changed. Without this a reversal alone would
    // send every wheel the long way round to the face it is already showing.
    guard rareUIMod(goal, 10) != target else { return goal }

    // Aim from where the wheel is rather than from where it was sent, so a value that
    // changes several times inside one roll does not queue up a backlog of turns.
    return heading < 0
        ? position - rareUIMod(position - target, 10)
        : position + rareUIMod(target - position, 10)
}
