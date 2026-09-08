//
//  StepPlayer.swift
//  A port of upstream's `components/ui/step-player.tsx`.
//
//  An iOS style step track: a row of dots where the current one stretches into a bar and
//  fills left to right, with a play control beside it. The proportions are all fractions of
//  one size, so it holds together from a toolbar glyph to a hero control.
//
//  One change of unit, recorded in docs/fidelity.md: durations are seconds here rather than
//  upstream's milliseconds, because every other duration in this library and in SwiftUI is
//  a number of seconds and having one that is not would be a trap.
//

import SwiftUI

/// One step of a ``StepPlayer``.
public struct StepPlayerStep: Identifiable, Hashable, Sendable {
    /// The step's identity, which keeps it stable as the track fills.
    public let id: Int
    /// How long this step lasts, in seconds, or `nil` to take the player's own duration.
    public let duration: Double?
    /// A name for the step, read out when the track is seekable.
    public let label: String?

    /// Creates a step.
    ///
    /// - Parameters:
    ///   - id: The step's position in the track.
    ///   - duration: How long it lasts, in seconds.
    ///   - label: A name for VoiceOver.
    public init(id: Int, duration: Double? = nil, label: String? = nil) {
        self.id = id
        self.duration = duration
        self.label = label
    }
}

/// Which side of the track the play control sits on.
public enum StepPlayerControlPosition: String, Sendable, CaseIterable {
    /// Before the track.
    case leading
    /// After it, which is upstream's default.
    case trailing
}

/// A row of steps that fills as it plays, with a control beside it.
///
/// ```swift
/// StepPlayer(steps: 5, index: $step, playing: $playing, duration: 3)
/// ```
///
/// Under Reduce Motion the steps change width without springing and the icons swap without
/// morphing, but the track still fills, because the fill is the information rather than
/// the decoration.
public struct StepPlayer: View {
    private let steps: [StepPlayerStep]
    @Binding private var index: Int
    @Binding private var playing: Bool
    private let duration: Double
    private let loop: Bool
    private let size: Double
    private let showsControl: Bool
    private let controlPosition: StepPlayerControlPosition
    private let seekable: Bool
    private let onComplete: (() -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var progress = 0.0
    @State private var finished = false

    /// The step's change of width, from upstream's `WIDTH_SPRING`.
    private static var widthSpring: Animation {
        .spring(duration: 0.42, bounce: 0.14)
    }

    /// The icon's morph, from `ICON_SPRING`.
    private static var iconSpring: Animation {
        .spring(duration: 0.32, bounce: 0.22)
    }

    /// The crossfade to and from replay, from `ICON_FADE`.
    private static var iconFade: Double {
        0.26
    }

    /// How small an icon starts before it fades in, from `ENTER_SCALE`.
    private static var enterScale: Double {
        0.82
    }

    /// Creates a player over a fixed number of steps.
    ///
    /// - Parameters:
    ///   - steps: How many steps there are.
    ///   - index: The step being played.
    ///   - playing: Whether it is playing.
    ///   - duration: How long each step lasts, in seconds.
    ///   - loop: Whether to start again at the end.
    ///   - size: The track's height, which every other measurement is a fraction of.
    ///   - showsControl: Whether to draw the play control.
    ///   - controlPosition: Which side the control sits on.
    ///   - seekable: Whether a step can be tapped to jump to it.
    ///   - onComplete: Called when the last step finishes.
    public init(
        steps: Int = 4,
        index: Binding<Int>,
        playing: Binding<Bool>,
        duration: Double = 4,
        loop: Bool = false,
        size: Double = 48,
        showsControl: Bool = true,
        controlPosition: StepPlayerControlPosition = .trailing,
        seekable: Bool = false,
        onComplete: (() -> Void)? = nil
    ) {
        self.init(
            steps: (0 ..< max(1, steps)).map { StepPlayerStep(id: $0) },
            index: index,
            playing: playing,
            duration: duration,
            loop: loop,
            size: size,
            showsControl: showsControl,
            controlPosition: controlPosition,
            seekable: seekable,
            onComplete: onComplete
        )
    }

    /// Creates a player over steps of their own lengths.
    ///
    /// - Parameters:
    ///   - steps: The steps, in order.
    ///   - index: The step being played.
    ///   - playing: Whether it is playing.
    ///   - duration: How long a step with no length of its own lasts, in seconds.
    ///   - loop: Whether to start again at the end.
    ///   - size: The track's height, which every other measurement is a fraction of.
    ///   - showsControl: Whether to draw the play control.
    ///   - controlPosition: Which side the control sits on.
    ///   - seekable: Whether a step can be tapped to jump to it.
    ///   - onComplete: Called when the last step finishes.
    public init(
        steps: [StepPlayerStep],
        index: Binding<Int>,
        playing: Binding<Bool>,
        duration: Double = 4,
        loop: Bool = false,
        size: Double = 48,
        showsControl: Bool = true,
        controlPosition: StepPlayerControlPosition = .trailing,
        seekable: Bool = false,
        onComplete: (() -> Void)? = nil
    ) {
        self.steps = steps.isEmpty ? [StepPlayerStep(id: 0)] : steps
        _index = index
        _playing = playing
        self.duration = duration
        self.loop = loop
        self.size = size
        self.showsControl = showsControl
        self.controlPosition = controlPosition
        self.seekable = seekable
        self.onComplete = onComplete
    }

    private var metrics: StepPlayerMetrics {
        StepPlayerMetrics(size: size)
    }

    private var current: Int {
        min(max(0, index), steps.count - 1)
    }

    private var stepDuration: Double {
        steps[current].duration ?? duration
    }

    public var body: some View {
        HStack(spacing: metrics.gap) {
            if showsControl, controlPosition == .leading { control }
            track
            if showsControl, controlPosition == .trailing { control }
        }
        .task(id: Ticket(index: current, playing: playing, finished: finished)) { await play() }
    }

    private var control: some View {
        Button {
            if finished {
                restart()
            } else {
                playing.toggle()
            }
        } label: {
            ZStack {
                Circle().fill(theme.surface)
                TransportGlyph(
                    state: iconState,
                    size: metrics.icon,
                    color: theme.glyph,
                    reduceMotion: reduceMotion,
                    morphSpring: Self.iconSpring,
                    fade: Self.iconFade,
                    enterScale: Self.enterScale
                )
            }
            .frame(width: metrics.track, height: metrics.track)
        }
        .buttonStyle(TapScale(scale: 0.88, reduceMotion: reduceMotion))
        .accessibilityLabel(finished ? "Replay" : playing ? "Pause" : "Play")
    }

    private var track: some View {
        HStack(spacing: metrics.gap) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { position, step in
                stepView(step, at: position)
            }
        }
        .padding(.horizontal, metrics.pad)
        .frame(height: metrics.track)
        .background(Capsule().fill(theme.surface))
        .accessibilityElement(children: seekable ? .contain : .ignore)
        .accessibilityLabel("Step \(current + 1) of \(steps.count)")
    }

    private func stepView(_ step: StepPlayerStep, at position: Int) -> some View {
        let isActive = position == current
        let isPast = position < current

        return Capsule()
            .fill(isPast ? theme.track : theme.glyph)
            .frame(width: isActive ? metrics.bar : metrics.dot, height: metrics.dot)
            .overlay(alignment: .leading) {
                if isActive {
                    Capsule()
                        .fill(theme.track)
                        .frame(width: metrics.bar * progress)
                }
            }
            .animation(reduceMotion ? nil : Self.widthSpring, value: current)
            .contentShape(.rect.size(width: metrics.bar, height: max(44, metrics.track)))
            .onTapGesture {
                guard seekable else { return }
                seek(to: position)
            }
            .allowsHitTesting(seekable)
            .accessibilityLabel(step.label ?? "Step \(position + 1)")
    }

    private var iconState: TransportState {
        if finished { return .replay }
        return playing ? .pause : .play
    }

    /// What a run of the clock is for. A change to any of it cancels the run and starts a
    /// new one, which is what upstream's effect dependencies do.
    private struct Ticket: Equatable {
        let index: Int
        let playing: Bool
        let finished: Bool
    }

    private func play() async {
        guard playing, !finished, stepDuration > 0 else { return }

        let start = Date()
        let from = progress
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }

            let elapsed = from + Date().timeIntervalSince(start) / stepDuration
            guard elapsed < 1 else {
                progress = 1
                finish()
                return
            }
            progress = elapsed
        }
    }

    private func finish() {
        guard current < steps.count - 1 else {
            onComplete?()
            if loop {
                progress = 0
                index = 0
            } else {
                finished = true
                playing = false
            }
            return
        }
        progress = 0
        index = current + 1
    }

    private func restart() {
        progress = 0
        finished = false
        index = 0
        playing = true
    }

    private func seek(to position: Int) {
        progress = 0
        finished = false
        index = position
        playing = true
    }
}

/// Everything about a player's size, derived from the one number the caller gives.
///
/// The ratios are traced from the iOS control upstream is following, and they are what
/// makes the component hold together at any size rather than only at forty-eight points.
struct StepPlayerMetrics {
    let track: Double
    let dot: Double
    let bar: Double
    let gap: Double
    let pad: Double
    let icon: Double

    init(size: Double) {
        track = max(12, size)
        dot = max(2, (track * 0.115).rounded())
        bar = (dot * 8.2).rounded()
        gap = max(2, (track * 0.18).rounded())
        // The same inset the dot leaves above and below it, so the row is centred.
        pad = ((track - dot) / 2).rounded()
        icon = (track * 0.64).rounded()
    }
}

/// The state the transport control is in.
enum TransportState {
    case play
    case pause
    case replay
}

/// The glyph on the control, which morphs between play and pause and crossfades to replay.
private struct TransportGlyph: View {
    let state: TransportState
    let size: Double
    let color: Color
    let reduceMotion: Bool
    let morphSpring: Animation
    let fade: Double
    let enterScale: Double

    var body: some View {
        ZStack {
            TransportShape(morph: state == .play ? 1 : 0)
                .fill(color)
                .frame(width: size, height: size)
                .opacity(state == .replay ? 0 : 1)
                .scaleEffect(state == .replay ? enterScale : 1)
                .animation(reduceMotion ? nil : morphSpring, value: state)

            ReplayShape()
                .fill(color)
                .frame(width: size, height: size)
                .opacity(state == .replay ? 1 : 0)
                .scaleEffect(state == .replay ? 1 : enterScale)
                .animation(
                    reduceMotion ? nil : .rareUICurve(RareUIMotion.easeOutSettle, duration: fade),
                    value: state
                )
        }
        .accessibilityHidden(true)
    }
}

/// The press behaviour of the control, from upstream's `TAP_SPRING`.
private struct TapScale: ButtonStyle {
    let scale: Double
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .animation(
                reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.3),
                value: configuration.isPressed
            )
    }
}
