//
//  BadgeNumber.swift
//  The number in NotificationBell's badge, ported from the `DigitColumn` component in
//  upstream's `components/ui/notification-bell.tsx`.
//
//  Each place is its own column, and each column is a spring. What makes this different
//  from an ordinary odometer is what a column is driven by: not the digit it should show,
//  but the whole number at that place. A count going from 39 to 40 moves the units column
//  from 39 to 40 and the tens column from 3 to 4, and taking each modulo ten afterwards
//  turns those into the right glyphs. The column therefore always knows which way to turn,
//  because it is following the count rather than a digit that has wrapped.
//

import SwiftUI

/// The number inside the badge, one rolling column per place.
struct BadgeNumber: View {
    let count: Int
    let max: Int
    let fontSize: Double
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 0) {
            if count > max {
                Text(verbatim: "\(max)+")
                    .font(font)
                    .foregroundStyle(.white)
            } else {
                let places = String(count).count
                ForEach(0 ..< places, id: \.self) { index in
                    let place = places - 1 - index
                    BadgeDigit(
                        value: count / pow10(place),
                        fontSize: fontSize,
                        reduceMotion: reduceMotion
                    )
                }
            }
        }
        // Digits have to share a width or the columns shift as the number changes.
        .monospacedDigit()
    }

    private var font: Font {
        .system(size: fontSize, weight: .semibold)
    }

    private func pow10(_ exponent: Int) -> Int {
        (0 ..< exponent).reduce(1) { total, _ in total * 10 }
    }
}

/// One place of the badge's number.
private struct BadgeDigit: View {
    /// The whole number at this place, not the digit: 4 for the tens column of 42.
    let value: Int
    let fontSize: Double
    let reduceMotion: Bool

    @State private var position: Double
    @State private var tracker = RollTracker()

    /// How many tiles are kept above and below the one showing.
    private static var window: Int {
        3
    }

    /// How far behind the spring is allowed to fall before it is moved up to catch it.
    private static var lag: Double {
        2
    }

    /// The widest the mask fades, as a percentage of the column.
    private static var fade: Double {
        34
    }

    /// The speed at which it reaches that width.
    private static var fadeVelocity: Double {
        9
    }

    /// Upstream's `COLUMN_SPRING`.
    private static var spring: Animation {
        .rareUISpring(stiffness: 400, damping: 30, mass: 0.9)
    }

    init(value: Int, fontSize: Double, reduceMotion: Bool) {
        self.value = value
        self.fontSize = fontSize
        self.reduceMotion = reduceMotion
        _position = State(initialValue: Double(value))
    }

    var body: some View {
        ZStack {
            ForEach(-Self.window ... Self.window, id: \.self) { offset in
                let tile = Int(position.rounded()) + offset
                Text(verbatim: String(Int(rareUIMod(Double(tile), 10))))
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(y: Double(tile) * fontSize)
            }
        }
        .frame(height: fontSize)
        .modifier(
            RollColumn(
                position: position,
                height: fontSize,
                tracker: tracker,
                fade: reduceMotion ? 0 : Self.fade,
                fadeVelocity: Self.fadeVelocity
            )
        )
        .clipped()
        .onChange(of: value) { _, new in roll(to: new) }
    }

    private func roll(to new: Int) {
        guard !reduceMotion else {
            position = Double(new)
            tracker.position.value = Double(new)
            return
        }

        // On a jump larger than the window, the column is moved up close first, so there
        // are still digits between here and there to roll past. Without it the spring
        // travels through a stretch of tiles that were never drawn.
        let gap = Double(new) - tracker.position.value
        if abs(gap) > Self.lag {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                position = Double(new) - (gap < 0 ? -Self.lag : Self.lag)
            }
        }

        withAnimation(Self.spring) { position = Double(new) }
    }
}

/// Where a column is and how fast it is going.
///
/// The speed is what the mask is driven by, and SwiftUI does not report it, so it is
/// worked out from the difference between one frame and the next.
@MainActor
private final class RollTracker {
    let position = RareUILiveValue()
    var velocity = 0.0
    var lastTime: CFTimeInterval?
}

/// Offsets a column to the place it is showing, and fades its edges by how fast it is moving.
private struct RollColumn: ViewModifier, Animatable {
    var position: Double
    let height: Double
    let tracker: RollTracker
    let fade: Double
    let fadeVelocity: Double

    /// `ViewModifier` is main actor isolated and `Animatable` is not, so without this the
    /// conformance is rejected as crossing between the two.
    nonisolated var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    func body(content: Content) -> some View {
        let speed = MainActor.assumeIsolated { measure() }
        // A window tall enough to fade at rest would show the next digit peeking out, so
        // the fade rides the speed instead: sharp when still, soft while rolling.
        let edge = min(fade, abs(speed) / fadeVelocity * fade) / 100

        return content
            // The mask covers the window the column is seen through, and the window does not
            // move: it is the tiles behind it that slide past. Offsetting the mask as well would
            // take the window with them and leave nothing to see.
            .offset(y: -position * height)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: edge),
                        .init(color: .black, location: 1 - edge),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }

    @MainActor
    private func measure() -> Double {
        let now = CACurrentMediaTime()
        defer {
            tracker.position.value = position
            tracker.lastTime = now
        }
        guard let lastTime = tracker.lastTime, now > lastTime else { return tracker.velocity }
        let elapsed = now - lastTime
        // A frame that arrived very late says nothing useful about speed.
        guard elapsed < 0.1 else { return tracker.velocity }
        tracker.velocity = (position - tracker.position.value) / elapsed
        return tracker.velocity
    }
}
