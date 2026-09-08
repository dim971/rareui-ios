//
//  MatrixOrb.swift
//  A port of upstream's `components/ui/matrix-orb.tsx`.
//
//  A grid of dots clipped to a circle, each one's size driven by a field that depends on
//  what the orb is doing. Upstream paints it into a 2D canvas on a frame loop; this does
//  the same with `Canvas` inside a `TimelineView`, which is the same arrangement: one
//  draw call per frame, no view tree to reconcile.
//

import SwiftUI

/// A grid of dots that breathes, ripples or thinks.
///
/// ```swift
/// MatrixOrb(state: .listening)
/// MatrixOrb(state: .listening, level: microphone.level)
/// ```
///
/// Give it a `level` and the listening state follows it. Leave the level out and it
/// synthesises one, so the orb has something to do while nothing is actually listening.
///
/// Under Reduce Motion it paints a single still frame, which is what upstream does when
/// `prefers-reduced-motion` is set.
public struct MatrixOrb: View {
    private let state: MatrixOrbState
    private let level: Double?
    private let size: Double
    private let color: Color?
    private let dots: Int
    private let labels: [MatrixOrbState: String]

    @Environment(\.rareUITheme) private var theme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var clock = MatrixOrbClock()

    /// Creates an orb.
    ///
    /// - Parameters:
    ///   - state: What the orb is doing. Defaults to ``MatrixOrbState/idle``.
    ///   - level: A level in `0...1`, such as a microphone's. Leave it out to have one
    ///     synthesised.
    ///   - size: The orb's width and height, in points. Defaults to `240`.
    ///   - color: The dots' colour. Defaults to the theme's accent.
    ///   - dots: How many dots across the grid is. Defaults to `11`, and never goes below `3`.
    ///   - labels: Replacements for the status text under the orb.
    public init(
        state: MatrixOrbState = .idle,
        level: Double? = nil,
        size: Double = 240,
        color: Color? = nil,
        dots: Int = 11,
        labels: [MatrixOrbState: String] = [:]
    ) {
        self.state = state
        self.level = level
        self.size = size
        self.color = color
        self.dots = dots
        self.labels = labels
    }

    public var body: some View {
        VStack(spacing: 12) {
            orb
                .frame(width: size, height: size)
                .accessibilityHidden(true)

            Text(labels[state] ?? Self.defaultLabel(state))
                .font(.subheadline)
                .foregroundStyle(theme.foreground.opacity(0.7))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    @ViewBuilder
    private var orb: some View {
        if reduceMotion {
            // A still frame, taken at the moment the orb would have started, with the
            // current state at full weight and the orb already at its resting size.
            Canvas(rendersAsynchronously: false) { context, canvasSize in
                paint(
                    context: &context,
                    canvasSize: canvasSize,
                    frame: MatrixOrbFrame(
                        time: 0,
                        amplitude: level.map { min(1, max(0, $0)) } ?? matrixOrbEnvelope(0),
                        scale: matrixOrbScale(state),
                        weights: MatrixOrbWeights(showing: state)
                    )
                )
            }
        } else {
            TimelineView(.animation) { timeline in
                // The clock is advanced here rather than inside the draw closure so the
                // simulation is stepped exactly once per frame, whatever the renderer does.
                let frame = clock.advance(to: timeline.date, state: state, level: level)
                Canvas(rendersAsynchronously: false) { context, canvasSize in
                    paint(context: &context, canvasSize: canvasSize, frame: frame)
                }
            }
        }
    }

    private func paint(context: inout GraphicsContext, canvasSize: CGSize, frame: MatrixOrbFrame) {
        let grid = max(3, dots)
        let half = Double(grid - 1) / 2
        let extent = min(canvasSize.width, canvasSize.height)
        let spacing = extent * 0.74 / Double(grid - 1)
        let maxRadius = spacing * 0.6
        let centre = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let ink = GraphicsContext.Shading.color(color ?? theme.accent)

        for row in 0 ..< grid {
            for column in 0 ..< grid {
                let normalisedX = (Double(column) - half) / half
                let normalisedY = (Double(row) - half) / half
                let distance = (normalisedX * normalisedX + normalisedY * normalisedY).squareRoot()
                // 1.12 rather than the square's own 1.41 corner is what rounds the outline.
                if distance > 1.12 { continue }

                var blended = 0.0
                for candidate in MatrixOrbState.allCases {
                    let weight = frame.weights[candidate]
                    if weight < 0.001 { continue }
                    blended += weight * matrixOrbIntensity(
                        candidate,
                        distance: distance,
                        normalisedX: normalisedX,
                        normalisedY: normalisedY,
                        time: frame.time,
                        amplitude: frame.amplitude
                    )
                }

                let intensity = min(1, max(0, blended))
                let radius = maxRadius * exp(-distance * distance * 1.7) * intensity * frame.scale
                // Anything under half a device pixel comes out as haze rather than a dot.
                if radius * displayScale < 0.5 { continue }

                let dot = CGRect(
                    x: centre.x + (Double(column) - half) * spacing * frame.scale - radius,
                    y: centre.y + (Double(row) - half) * spacing * frame.scale - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(Path(ellipseIn: dot), with: ink)
            }
        }
    }

    private static func defaultLabel(_ state: MatrixOrbState) -> String {
        switch state {
        case .idle: "Idle"
        case .listening: "Listening"
        case .thinking: "Thinking"
        }
    }
}

/// The orb's simulation, stepped once per frame.
///
/// It is a reference type because the state has to survive between frames, and it is not
/// observable because nothing should re-render when it changes: the `TimelineView` is
/// already asking for a new frame, and an observation on top of that would ask again.
@MainActor
private final class MatrixOrbClock {
    private var time = 0.0
    private var amplitude = 0.0
    private var scale: Double?
    private var velocity = 0.0
    private var weights: MatrixOrbWeights?
    private var last: Date?

    /// Steps the simulation up to `now` and reports what to paint.
    ///
    /// - Parameters:
    ///   - now: The frame's timestamp.
    ///   - state: What the orb is doing, which the loop retargets toward rather than
    ///     restarting for.
    ///   - level: The caller's level, if there is one.
    /// - Returns: The frame to paint.
    func advance(to now: Date, state: MatrixOrbState, level: Double?) -> MatrixOrbFrame {
        var weights = weights ?? MatrixOrbWeights(showing: state)
        var scale = scale ?? matrixOrbScale(state)

        // A frame that arrives late, because the app was in the background or the main
        // thread was busy, is capped rather than integrated in one enormous step.
        let elapsed = last.map { min(now.timeIntervalSince($0), 0.05) } ?? 0
        last = now
        time += elapsed

        let target = Self.level(level, at: time)
        // Rising follows quickly and falling follows slowly, so a peak is held for a
        // moment instead of dropping the instant the level does.
        let rate = target > amplitude ? matrixOrbAttack : matrixOrbRelease
        amplitude += (target - amplitude) * (1 - pow(1 - rate, elapsed * 60))

        weights.blend(toward: state, step: 1 - pow(1 - matrixOrbBlend, elapsed * 60))

        // The spring is integrated by hand rather than handed to SwiftUI, because its
        // output feeds a draw call rather than a view property.
        velocity += (-matrixOrbStiffness * (scale - matrixOrbScale(state))
            - matrixOrbDamping * velocity) * elapsed
        scale += velocity * elapsed

        self.weights = weights
        self.scale = scale
        return MatrixOrbFrame(time: time, amplitude: amplitude, scale: scale, weights: weights)
    }

    /// The level to follow: the caller's when there is a usable one, a synthesised one
    /// otherwise. A level that is not a number would stick in the smoother forever.
    private static func level(_ given: Double?, at time: Double) -> Double {
        guard let given, given.isFinite else { return matrixOrbEnvelope(time) }
        return min(1, max(0, given))
    }
}
