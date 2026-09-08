//
//  NotificationBell.swift
//  A port of upstream's `components/ui/notification-bell.tsx`.
//
//  A bell that rings when the count goes up. Nothing has to be tapped: the arrival of a
//  notification is the event, and the harder it arrives the further the bell swings.
//

import SwiftUI

/// The colour of a ``NotificationBell``'s badge.
public enum NotificationBellColor: String, Sendable, CaseIterable {
    /// The system red, and the default.
    case red
    /// The system orange.
    case orange
    /// The system green.
    case green
    /// The system blue.
    case blue
    /// The system violet.
    case violet

    func resolve(in theme: RareUITheme) -> Color {
        switch self {
        case .red: theme.red
        case .orange: theme.orange
        case .green: theme.green
        case .blue: theme.blue
        case .violet: theme.violet
        }
    }
}

/// How a ``NotificationBell`` shows that there is something waiting.
public enum NotificationBellVariant: String, Sendable, CaseIterable {
    /// A badge with the number in it.
    case count
    /// A small dot, with no number.
    case dot
}

/// A bell that swings when its count goes up.
///
/// ```swift
/// NotificationBell(count: unread)
/// NotificationBell(count: unread, variant: .dot, color: .blue)
/// ```
///
/// The ring is a push rather than a destination: the bell is given a velocity in the
/// direction it is already travelling, so notifications arriving in quick succession make
/// it swing harder rather than resetting it. Five at once is as hard as it gets.
///
/// Under Reduce Motion the bell does not swing and the badge fades rather than springing.
public struct NotificationBell: View {
    private let count: Int
    private let max: Int
    private let variant: NotificationBellVariant
    private let size: Double
    private let color: NotificationBellColor
    private let action: (() -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var clock = BellClock()
    @State private var ringing = false
    @State private var settle: Task<Void, Never>?

    /// The icon's size as a fraction of the button's.
    private static var iconScale: Double {
        0.56
    }

    /// The badge's size as a fraction of the button's, with a number in it.
    private static var badgeScale: Double {
        0.38
    }

    /// And without one.
    private static var dotScale: Double {
        0.22
    }

    /// The badge's type size as a fraction of the button's size.
    private static var fontScale: Double {
        0.21
    }

    /// The padding either side of the number, as a fraction of the button's size.
    private static var padScale: Double {
        0.09
    }

    /// How far out the badge sits. One would put it exactly on the button's edge.
    private static var orbit: Double {
        0.9
    }

    /// The badge's arrival, from upstream's `ENTER_SPRING`.
    private static var enter: Animation {
        .rareUISpring(stiffness: 600, damping: 20)
    }

    /// Creates a bell.
    ///
    /// - Parameters:
    ///   - count: How many notifications are waiting. A rise rings the bell.
    ///   - max: The largest number to write out. Above it the badge reads `99+`.
    ///   - variant: Whether to show the number or only a dot.
    ///   - size: The button's width and height, in points. Everything else is a fraction of it.
    ///   - color: The badge's colour.
    ///   - action: What to do when the bell is tapped.
    public init(
        count: Int,
        max: Int = 99,
        variant: NotificationBellVariant = .count,
        size: Double = 48,
        color: NotificationBellColor = .red,
        action: (() -> Void)? = nil
    ) {
        // A count below zero would ring the bell on the way back up to zero.
        self.count = Swift.max(0, count)
        self.max = max
        self.variant = variant
        self.size = size
        self.color = color
        self.action = action
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            ZStack {
                Circle().fill(theme.surface)
                bell
            }
            .frame(width: size, height: size)
            .overlay(alignment: .topTrailing) { badge }
        }
        .buttonStyle(BellButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(count > 0 ? "Notifications, \(count) unread" : "Notifications")
        .accessibilityAddTraits(.updatesFrequently)
        .onChange(of: count) { old, new in ring(by: new - old) }
    }

    @ViewBuilder
    private var bell: some View {
        if reduceMotion {
            BellIcon(swing: 0, clapper: 0, color: theme.glyph)
                .frame(width: size * Self.iconScale, height: size * Self.iconScale)
        } else {
            // The loop is only wound up while the bell is actually moving. A settled spring
            // redrawn sixty times a second is sixty identical frames.
            TimelineView(.animation(paused: !ringing)) { timeline in
                let frame = clock.advance(to: timeline.date)
                BellIcon(swing: frame.swing, clapper: frame.clapper, color: theme.glyph)
                    .frame(width: size * Self.iconScale, height: size * Self.iconScale)
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if count > 0 {
            let side = size * (variant == .dot ? Self.dotScale : Self.badgeScale)
            let inset = bellBadgeInset(size: size, side: side, orbit: Self.orbit)

            // The number sizes the badge rather than the other way round: a badge that was
            // laid out first and then given an overlay could not grow to hold three digits.
            Group {
                if variant == .count {
                    BadgeNumber(
                        count: count,
                        max: max,
                        fontSize: size * Self.fontScale,
                        reduceMotion: reduceMotion
                    )
                    .padding(.horizontal, size * Self.padScale)
                }
            }
            .frame(minWidth: side, minHeight: side)
            .background(Capsule().fill(color.resolve(in: theme)))
            .fixedSize()
            .offset(x: -inset, y: inset)
            .transition(
                reduceMotion
                    ? .opacity
                    : .scale.combined(with: .opacity)
            )
            .animation(
                reduceMotion ? .linear(duration: 0.15) : Self.enter,
                value: count > 0
            )
            .accessibilityHidden(true)
        }
    }

    private func ring(by delta: Int) {
        guard delta > 0, !reduceMotion else { return }
        clock.ring(by: delta)
        ringing = true

        // Motion stops its own loop once the spring reaches rest. There is no equivalent
        // hook on a TimelineView, so the loop is wound down after long enough for this
        // spring to have settled from its hardest possible push, which is under two seconds.
        settle?.cancel()
        settle = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            ringing = false
        }
    }
}

/// The press behaviour of the bell, which upstream writes as `active:scale-90`.
private struct BellButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// The bell's swing and its clapper, stepped one frame at a time.
///
/// Both are springs integrated by hand, because SwiftUI cannot be handed a starting
/// velocity and a starting velocity is what ringing a bell is.
@MainActor
private final class BellClock {
    private var swing = RareUISpringState()
    private var clapper = RareUISpringState()
    private var last: Date?

    /// Upstream's `SWING_SPRING`: low damping, so it keeps swinging for a while.
    private static let swingStiffness = 220.0
    private static let swingDamping = 10.0
    /// Upstream's `CLAPPER_SPRING`.
    private static let clapperStiffness = 300.0
    private static let clapperDamping = 14.0

    // However many arrive at once, the bell is never pushed harder than this.
    // How far the clapper trails the bell at full tilt, in degrees.

    /// Steps both springs up to `now`.
    ///
    /// - Parameter now: The frame's timestamp.
    /// - Returns: The angles to draw the bell and its clapper at.
    func advance(to now: Date) -> (swing: Double, clapper: Double) {
        let elapsed = last.map { Swift.min(now.timeIntervalSince($0), 0.05) } ?? 0
        last = now

        swing.advance(to: 0, by: elapsed, stiffness: Self.swingStiffness, damping: Self.swingDamping)

        clapper.advance(
            to: bellClapperLag(swingVelocity: swing.velocity),
            by: elapsed,
            stiffness: Self.clapperStiffness,
            damping: Self.clapperDamping
        )

        return (swing.value, clapper.value)
    }

    /// Rings the bell.
    ///
    /// - Parameter delta: How many notifications arrived at once.
    func ring(by delta: Int) {
        swing.velocity = bellRingVelocity(from: swing.velocity, delta: delta)
    }
}

/// How hard one notification pushes, in degrees per second.
let bellImpulse = 500.0
/// However many arrive at once, the bell is never pushed harder than this.
let bellMaxVelocity = 900.0
/// The number of notifications at which the push stops growing.
let bellBurst = 5.0
/// How far the clapper trails the bell at full tilt, in degrees.
let bellClapperSweep = 13.0
/// The bell speed at which it reaches that.
let bellClapperVelocity = 450.0

/// The speed to give the bell when notifications arrive.
///
/// The push is added to whatever the bell is already doing, in the direction it is already
/// going, so a second notification arriving mid swing adds to the ring rather than fighting
/// it. More arriving at once pushes harder, up to a point: five is as hard as it gets, and
/// the result is capped so the bell cannot be made to spin.
///
/// - Parameters:
///   - current: How fast the bell is going now, in degrees per second.
///   - delta: How many notifications arrived at once.
/// - Returns: The bell's new speed.
func bellRingVelocity(from current: Double, delta: Int) -> Double {
    let weight = 0.7 + 0.6 * min(Double(delta), bellBurst) / bellBurst
    let along: Double = current > 1 ? 1 : -1
    let pushed = current + along * bellImpulse * weight
    return max(-bellMaxVelocity, min(bellMaxVelocity, pushed))
}

/// Where the clapper is trying to be, given how fast the bell is going.
///
/// It is driven by the bell's speed rather than by its position, which is what makes it
/// trail behind rather than move with it: the bell is fastest at the bottom of its swing,
/// which is exactly where the clapper is furthest out.
///
/// - Parameter swingVelocity: The bell's speed, in degrees per second.
/// - Returns: The clapper's angle relative to the bell, in degrees.
func bellClapperLag(swingVelocity: Double) -> Double {
    -bellClapperSweep * max(-1, min(1, swingVelocity / bellClapperVelocity))
}

/// How far the badge is inset from the button's corner.
///
/// Placing it on a circle rather than at a fixed offset keeps it in the same relation to
/// the button's edge whatever the size. A negative result means it hangs outside, which is
/// where it usually sits.
///
/// - Parameters:
///   - size: The button's width and height.
///   - side: The badge's own height.
///   - orbit: How far out to place it. One puts it exactly on the button's edge.
/// - Returns: The inset from the top and from the trailing edge.
func bellBadgeInset(size: Double, side: Double, orbit: Double) -> Double {
    size / 2 - (orbit * size * 0.5.squareRoot()) / 2 - side / 2
}
