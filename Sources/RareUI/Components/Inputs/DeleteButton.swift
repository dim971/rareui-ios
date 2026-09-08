//
//  DeleteButton.swift
//  A port of upstream's `components/ui/delete-button.tsx`.
//
//  A bin that opens into a confirmation rather than a dialogue. The tile grows sideways,
//  a recessed panel appears in the space it made, and two raised buttons rise into it.
//

import SwiftUI

/// What the button last did.
private enum DeleteButtonStatus {
    /// Nothing yet, or long enough ago that it has gone back to nothing.
    case idle
    /// It deleted. The bin is replaced by a tick that draws itself on.
    case deleted
    /// It did not. The bin gives a small nod and stays.
    case kept
}

/// A delete button that asks first, in the space it makes for itself.
///
/// ```swift
/// DeleteButton {
///     remove(item)
/// }
/// ```
///
/// Tapping it opens the confirmation; tapping it again, or pressing the cross, keeps the
/// thing. The answer is held for a moment and then the button goes back to being a bin.
///
/// Under Reduce Motion everything happens without a duration: the panel appears, the lid
/// is simply open, and nothing springs.
public struct DeleteButton: View {
    private let onConfirm: (() -> Void)?
    private let onCancel: (() -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var open = false
    @State private var status = DeleteButtonStatus.idle
    @State private var nod = 1.0
    @State private var tick = 0.0
    @State private var holding: Task<Void, Never>?

    /// The tile's width and height, in points.
    private static var tile: Double {
        48
    }

    /// How much wider the button gets when it asks.
    private static var panel: Double {
        84
    }

    /// The tile's corner radius.
    private static var radius: Double {
        16
    }

    /// How far the lid swings, in degrees. Negative, because it opens backwards.
    private static var lidOpen: Double {
        -35
    }

    /// Where the walls start when the bin is shut.
    private static var wallTop: Double {
        6
    }

    /// And when it is open, which is what makes the bin appear to sink as the lid lifts.
    private static var wallTopOpen: Double {
        13.5
    }

    /// The accent both the tick and the confirm button are drawn in.
    private static var accent: Color {
        Color(hex: "#FF5F2E")
    }

    /// How long each answer is held before the button forgets it, in seconds.
    private static func hold(_ status: DeleteButtonStatus) -> Double {
        status == .deleted ? 1.4 : 0.6
    }

    /// Creates a delete button.
    ///
    /// - Parameters:
    ///   - onCancel: Called when the thing is kept, whether by the cross or by tapping the bin again.
    ///   - onConfirm: Called when the tick is pressed.
    public init(onCancel: (() -> Void)? = nil, onConfirm: (() -> Void)? = nil) {
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                .fill(theme.surface)

            if open { confirmation }
            trigger
        }
        .frame(width: open ? Self.tile + Self.panel : Self.tile, height: Self.tile)
        .animation(timing(duration: 0.62, curve: RareUIMotion.easeOutSettle), value: open)
        .accessibilityElement(children: .contain)
        .onDisappear { holding?.cancel() }
    }

    private var trigger: some View {
        Button {
            if open {
                resolve(.kept)
            } else {
                status = .idle
                open = true
            }
        } label: {
            ZStack {
                if status == .deleted {
                    BinTick()
                        .trim(from: 0, to: tick)
                        .stroke(
                            Self.accent,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 20, height: 20)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    bin
                        .transition(.opacity)
                }
            }
            .frame(width: Self.tile, height: Self.tile)
            .contentShape(.rect)
        }
        .buttonStyle(PressScale(scale: 0.94, reduceMotion: reduceMotion))
        .animation(timing(duration: 0.22, curve: RareUIMotion.easeOutSettle), value: status)
        .accessibilityLabel("Delete")
        .accessibilityValue(open ? "Confirming" : "")
    }

    private var bin: some View {
        ZStack {
            BinWalls(top: open ? Self.wallTopOpen : Self.wallTop)
                .stroke(
                    theme.glyph,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .animation(timing(duration: 0.56, curve: RareUIMotion.easeOutSettle), value: open)

            BinLid()
                .stroke(
                    theme.glyph,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                // An overshooting curve, so the lid is thrown a little past its open angle
                // before it settles back onto it.
                .rotationEffect(.degrees(open ? Self.lidOpen : 0), anchor: BinLid.hinge)
                .animation(timing(duration: 0.6, curve: RareUIMotion.easeOutOvershoot), value: open)
        }
        .frame(width: 20, height: 20)
        // The bin is drawn at 20 points inside a 24 point box, so the lid swings outside it.
        .allowsHitTesting(false)
        .scaleEffect(nod)
    }

    private var confirmation: some View {
        HStack(spacing: 8) {
            RaisedCircle(label: "Confirm delete", tint: Self.accent, reduceMotion: reduceMotion) {
                resolve(.deleted)
            } icon: {
                BinTick()
            }

            RaisedCircle(label: "Cancel", tint: theme.glyph, reduceMotion: reduceMotion) {
                resolve(.kept)
            } icon: {
                BinCross()
            }
        }
        .frame(width: Self.panel, height: Self.tile)
        .background {
            RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                .fill(theme.surfaceRecessed)
                // The notch, pointing back at the tile the panel opened out of.
                .overlay(alignment: .leading) {
                    Notch()
                        .fill(theme.surfaceRecessed)
                        .frame(width: 6, height: 10)
                        .offset(x: -5)
                }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .transition(
            reduceMotion
                ? .opacity
                : .offset(x: -6).combined(with: .opacity)
        )
        .animation(panelTiming, value: open)
    }

    /// The panel waits a beat before it arrives, so the tile has already started widening
    /// and the panel appears in a space rather than pushing one open.
    private var panelTiming: Animation? {
        guard !reduceMotion else { return nil }
        return .rareUICurve(RareUIMotion.easeOutSettle, duration: 0.44).delay(0.14)
    }

    private func timing(duration: Double, curve: CubicBezier) -> Animation? {
        reduceMotion ? nil : .rareUICurve(curve, duration: duration)
    }

    private func resolve(_ next: DeleteButtonStatus) {
        open = false
        status = next
        (next == .deleted ? onConfirm : onCancel)?()

        tick = 0
        nod = 1
        if next == .deleted, !reduceMotion {
            withAnimation(.rareUICurve(RareUIMotion.easeOutSettle, duration: 0.45)) { tick = 1 }
        } else if next == .deleted {
            tick = 1
        }

        holding?.cancel()
        holding = Task {
            if next == .kept, !reduceMotion { await nudge() }
            try? await Task.sleep(for: .seconds(Self.hold(next)))
            guard !Task.isCancelled else { return }
            status = .idle
        }
    }

    /// The small nod the bin gives when the thing is kept: down to 86% and back.
    private func nudge() async {
        withAnimation(.rareUICurve(RareUIMotion.easeOutSettle, duration: 0.225)) { nod = 0.86 }
        try? await Task.sleep(for: .seconds(0.225))
        withAnimation(.rareUICurve(RareUIMotion.easeOutSettle, duration: 0.225)) { nod = 1 }
    }
}

/// The triangle that points from the panel back at the tile.
private struct Notch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// One of the two buttons in the panel: a raised disc with an icon stroked on it.
private struct RaisedCircle<Icon: Shape>: View {
    let label: String
    let tint: Color
    let reduceMotion: Bool
    let action: () -> Void
    let icon: () -> Icon

    @Environment(\.rareUITheme) private var theme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            icon()
                .stroke(tint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .frame(width: 14, height: 14)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(theme.surface)
                        // The lift: a hairline highlight along the top and two soft shadows
                        // under it, which is what makes the disc read as sitting proud of
                        // the recess rather than printed on it.
                        .shadow(color: .black.opacity(0.05), radius: 0.5, y: 0.5)
                        .shadow(color: .black.opacity(0.08), radius: 1.5, y: 1)
                }
                .contentShape(.circle)
        }
        .buttonStyle(PressScale(scale: 0.84, hoverScale: 1.03, reduceMotion: reduceMotion))
        .accessibilityLabel(label)
    }
}

/// The press behaviour shared by the tile and the two discs.
private struct PressScale: ButtonStyle {
    let scale: Double
    var hoverScale: Double = 1
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            // Upstream's `PRESS`, which is stiff and light so the disc snaps rather than
            // squashing.
            .animation(
                reduceMotion ? nil : .rareUISpring(stiffness: 520, damping: 18, mass: 0.5),
                value: configuration.isPressed
            )
    }
}
