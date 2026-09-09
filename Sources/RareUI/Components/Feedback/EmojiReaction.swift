//
//  EmojiReaction.swift
//  A port of upstream's `components/ui/emoji-reaction.tsx`.
//
//  A button that opens a bar of emoji. Picking one sends five copies of it drifting up the
//  screen, and holding it down keeps sending them.
//
//  One departure, recorded in docs/fidelity.md: upstream loads Apple's emoji artwork from
//  a CDN, because a browser on Windows would otherwise draw something else entirely. On an
//  Apple platform that artwork is the system font, so the emoji here are text. That removes
//  a network dependency from a component that has no other reason to touch the network.
//

import SwiftUI

/// Which edge of the trigger a ``EmojiReaction``'s bar lines up with.
public enum EmojiReactionAlign: String, Sendable, CaseIterable {
    /// The bar's leading edge meets the trigger's.
    case leading
    /// The bar is centred over the trigger.
    case center
    /// The bar's trailing edge meets the trigger's.
    case trailing
}

/// How large a ``EmojiReaction`` is drawn.
public enum EmojiReactionSize: String, Sendable, CaseIterable {
    /// The smallest.
    case small
    /// The default.
    case medium
    /// The largest.
    case large

    /// The trigger's width and height, in points.
    var trigger: Double {
        switch self {
        case .small: 32
        case .medium: 40
        case .large: 48
        }
    }

    /// The trigger's icon size, in points.
    var icon: Double {
        switch self {
        case .small: 16
        case .medium: 20
        case .large: 24
        }
    }

    /// The size of an emoji in the bar, in points.
    var emoji: Double {
        switch self {
        case .small: 26
        case .medium: 34
        case .large: 42
        }
    }

    /// The space between two emoji in the bar.
    var spacing: Double {
        switch self {
        case .small: 2
        case .medium: 4
        case .large: 6
        }
    }

    /// The padding inside the bar.
    var padding: Double {
        switch self {
        case .small: 4
        case .medium: 6
        case .large: 8
        }
    }
}

/// A button that opens a bar of emoji, and sends the one you pick drifting up the screen.
///
/// ```swift
/// EmojiReaction { emoji in
///     post(reaction: emoji)
/// }
/// ```
///
/// Holding an emoji down keeps sending copies, a little over twice a second.
///
/// Under Reduce Motion the bar fades in rather than springing and nothing is sent flying,
/// which is what upstream does under `prefers-reduced-motion`.
public struct EmojiReaction: View {
    private let emojis: [String]
    private let size: EmojiReactionSize
    private let align: EmojiReactionAlign
    private let onReact: ((String) -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var open = false
    @State private var last: String?
    @State private var particles: [EmojiParticle] = []
    @State private var seed = 0
    @State private var holding: Task<Void, Never>?
    @State private var placeAbove = true
    @State private var barHeight = 0.0

    /// The five upstream ships with, as the glyphs their names describe.
    public static let defaultEmojis = ["\u{1F970}", "\u{1F929}", "\u{1F615}", "\u{1F97A}", "\u{1F604}"]

    /// The bar's arrival.
    private static var barSpring: Animation {
        .rareUISpring(stiffness: 520, damping: 30)
    }

    /// Each emoji's own arrival, which is stiffer so they pop rather than drift in.
    private static var emojiSpring: Animation {
        .rareUISpring(stiffness: 800, damping: 25)
    }

    /// The space between the trigger and the bar, in points.
    private static var gap: Double {
        16
    }

    /// Creates a reaction button.
    ///
    /// - Parameters:
    ///   - emojis: The emoji to offer. Defaults to upstream's five.
    ///   - size: How large to draw it.
    ///   - align: Which edge of the trigger the bar lines up with.
    ///   - onReact: Called with the emoji picked, once per copy sent.
    public init(
        emojis: [String] = EmojiReaction.defaultEmojis,
        size: EmojiReactionSize = .medium,
        align: EmojiReactionAlign = .center,
        onReact: ((String) -> Void)? = nil
    ) {
        self.emojis = emojis
        self.size = size
        self.align = align
        self.onReact = onReact
    }

    public var body: some View {
        trigger
            .background {
                // The bar needs somewhere to go. Reading the trigger's place on the screen
                // is what decides whether that is above it or below.
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    Color.clear
                        .onAppear { placeAbove = hasRoomAbove(frame) }
                        .onChange(of: frame.minY) { _, _ in placeAbove = hasRoomAbove(frame) }
                }
            }
            .overlay(alignment: barAlignment) {
                if open {
                    bar
                        .fixedSize()
                        .background {
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear { barHeight = proxy.size.height }
                                    .onChange(of: proxy.size.height) { _, height in barHeight = height }
                            }
                        }
                        // Placed by offset rather than by an alignment guide. A guide is
                        // evaluated off the main actor, so it cannot read which way the bar
                        // is going, and it has to be told rather than asked.
                        .offset(y: placeAbove ? -(barHeight + Self.gap) : size.trigger + Self.gap)
                        .transition(barTransition)
                }
            }
            .animation(reduceMotion ? .linear(duration: 0.15) : Self.barSpring, value: open)
            .onDisappear { holding?.cancel() }
    }

    /// Whether the bar fits between the trigger and the top of the screen.
    ///
    /// Upstream asks the same question of the window; here the trigger's own global frame
    /// answers it, which works inside a scroll view as well as at the top level.
    private func hasRoomAbove(_ trigger: CGRect) -> Bool {
        // The bar is one emoji tall plus its padding, plus the tail and the gap.
        let needed = size.emoji + size.padding * 2 + 8 + 26 + Self.gap
        return trigger.minY - needed >= 8
    }

    /// The bar hangs off the top of the trigger and is then pushed into place, so the
    /// alignment only has to say which edges line up horizontally.
    private var barAlignment: Alignment {
        switch align {
        case .leading: .topLeading
        case .center: .top
        case .trailing: .topTrailing
        }
    }

    private var barTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .scale(scale: 0.85, anchor: .bottom)
                .combined(with: .offset(y: 10))
                .combined(with: .opacity),
            removal: .scale(scale: 0.9, anchor: .bottom)
                .combined(with: .offset(y: 6))
                .combined(with: .opacity)
        )
    }

    private var trigger: some View {
        Button {
            open.toggle()
        } label: {
            EmojiTriggerFace(open: open, last: last, size: size, theme: theme)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(open ? "Close reactions" : last.map { "Reacted \($0)" } ?? "Add a reaction")
    }

    private var bar: some View {
        EmojiBar(
            emojis: emojis,
            size: size,
            theme: theme,
            align: align,
            reduceMotion: reduceMotion,
            spring: Self.emojiSpring,
            onPress: { emoji, origin in react(emoji, at: origin) },
            onHoldStart: { emoji, origin in startHolding(emoji, at: origin) },
            onHoldEnd: { holding?.cancel() }
        )
        // Overlaid rather than handed to the bar. The overlay is still a descendant of the
        // bar's named coordinate space, so a particle knows where in the bar it started.
        .overlay { flight }
    }

    private var flight: some View {
        ZStack {
            ForEach(particles) { particle in
                FlyingEmoji(particle: particle, size: size.emoji) { finished in
                    particles.removeAll { $0.id == finished }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func react(_ emoji: String, at origin: CGPoint) {
        last = emoji
        onReact?(emoji)
        guard !reduceMotion else { return }

        seed += emojiBurstCount
        var generator = SystemRandomNumberGenerator()
        let burst = EmojiParticle.burst(
            glyph: emoji,
            seed: seed,
            origin: origin,
            using: &generator
        )
        // Holding a reaction down for long enough would otherwise fill the screen, and the
        // oldest copies are the ones nearest the top and about to fade anyway.
        particles = Array((particles + burst).suffix(emojiMaxParticles))
    }

    private func startHolding(_ emoji: String, at origin: CGPoint) {
        react(emoji, at: origin)
        holding?.cancel()
        holding = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(emojiHoldInterval))
                guard !Task.isCancelled else { return }
                react(emoji, at: origin)
            }
        }
    }
}
