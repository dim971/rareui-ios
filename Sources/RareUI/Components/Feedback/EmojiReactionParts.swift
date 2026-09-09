//
//  EmojiReactionParts.swift
//  The pieces EmojiReaction is assembled from.
//
//  They are separate views rather than computed properties on the component, and that is
//  not only tidiness: Swift 6.1.2 crashes in SILGen lowering this component when its body
//  is one large expression, with a stack dump and no diagnostic to read. Naming the parts
//  keeps each of them small enough to get through. Recorded in docs/fidelity.md.
//

import SwiftUI

/// One emoji in the bar, with its arrival, its hover lift and its press.
struct EmojiButton: View {
    let emoji: String
    let size: EmojiReactionSize
    let delay: Double
    let spring: Animation
    let reduceMotion: Bool
    let onPress: (CGPoint) -> Void
    let onHoldStart: (CGPoint) -> Void
    let onHoldEnd: () -> Void

    @State private var arrived = false
    @State private var hovering = false
    @State private var pressing = false
    @State private var centre = CGPoint.zero

    var body: some View {
        Text(emoji)
            .font(.system(size: size.emoji))
            .padding(4)
            .scaleEffect(scale)
            .offset(y: hovering && !reduceMotion ? -4 : 0)
            .opacity(arrived ? 1 : 0)
            .background {
                GeometryReader { proxy in
                    let middle = proxy.frame(in: .named("rareui.emojibar")).origin
                    Color.clear
                        .onAppear {
                            centre = CGPoint(
                                x: middle.x + proxy.size.width / 2,
                                y: middle.y + proxy.size.height / 2
                            )
                        }
                }
            }
            .contentShape(.rect)
            .onHover { hovering = $0 }
            // A press has to start the repeat and a release has to stop it, which a plain
            // button cannot say, so the gesture is written out.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressing else { return }
                        pressing = true
                        onHoldStart(centre)
                    }
                    .onEnded { _ in
                        pressing = false
                        onHoldEnd()
                    }
            )
            .animation(.rareUISpring(stiffness: 800, damping: 25), value: hovering)
            .animation(.rareUISpring(stiffness: 800, damping: 25), value: pressing)
            .task {
                guard !reduceMotion else {
                    arrived = true
                    return
                }
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(spring) { arrived = true }
            }
            .accessibilityLabel(emoji)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onPress(centre) }
    }

    private var scale: Double {
        if pressing { return 0.92 }
        if hovering, !reduceMotion { return 1.28 }
        return arrived ? 1 : 0.4
    }
}

/// One copy on its way up, which removes itself when it gets there.
struct FlyingEmoji: View {
    let particle: EmojiParticle
    let size: Double
    let onFinish: (Int) -> Void

    @State private var progress = 0.0

    var body: some View {
        Text(particle.glyph)
            .font(.system(size: size))
            .modifier(EmojiFlight(progress: progress, particle: particle, size: size))
            .position(particle.origin)
            .task {
                try? await Task.sleep(for: .seconds(particle.delay))
                // The flight's own easing is applied inside the modifier, one curve per
                // value, so the progress driving it has to be plain linear.
                withAnimation(.linear(duration: particle.duration)) { progress = 1 }
                try? await Task.sleep(for: .seconds(particle.duration))
                onFinish(particle.id)
            }
    }
}

/// The face on the trigger before anything has been picked, quoted from upstream's
/// `SmileIcon`: an open circle, two eyes, a smile and a sparkle off the top right.
struct SmileIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = SVGShape(
            "M21 12a9 9 0 1 1-9-9",
            viewBox: CGSize(width: 24, height: 24)
        ).path(in: rect)
        path
            .addPath(SVGShape("M8 13.9a4.7 4.7 0 0 0 8 0", viewBox: CGSize(width: 24, height: 24))
                .path(in: rect))
        path.addPath(SVGShape("M19 2.5v5M21.5 5h-5", viewBox: CGSize(width: 24, height: 24)).path(in: rect))

        // The eyes are filled rather than stroked upstream, but at this size a stroked
        // circle of the same radius is indistinguishable and keeps the icon one path.
        let scale = min(rect.width, rect.height) / 24
        for eye in [CGPoint(x: 8.9, y: 10), CGPoint(x: 15.1, y: 10)] {
            let centre = CGPoint(x: rect.minX + eye.x * scale, y: rect.minY + eye.y * scale)
            path.addEllipse(in: CGRect(
                x: centre.x - 0.7 * scale,
                y: centre.y - 0.7 * scale,
                width: 1.4 * scale,
                height: 1.4 * scale
            ))
        }
        return path
    }
}

/// What the trigger shows: a cross while the bar is open, the last reaction once one has
/// been picked, and a face before that.
///
/// Its own view rather than three branches inside the button's label. Swift 6.1.2 crashes
/// lowering this component when its body is one large expression, and naming the parts is
/// what keeps each of them small enough to get through. See docs/fidelity.md.
struct EmojiTriggerFace: View {
    let open: Bool
    let last: String?
    let size: EmojiReactionSize
    let theme: RareUITheme

    var body: some View {
        ZStack {
            Circle().fill(theme.surface)
            face
        }
        .frame(width: size.trigger, height: size.trigger)
    }

    @ViewBuilder
    private var face: some View {
        if open {
            Image(systemName: "xmark")
                .font(.system(size: size.icon * 0.8, weight: .semibold))
                .foregroundStyle(theme.foreground.opacity(0.6))
        } else if let last {
            Text(last)
                .font(.system(size: size.emoji * 0.72))
        } else {
            SmileIcon()
                .stroke(
                    theme.foreground.opacity(0.6),
                    style: StrokeStyle(lineWidth: 1.7, lineCap: .round)
                )
                .frame(width: size.icon, height: size.icon)
        }
    }
}

/// The bar of emoji, and the tail that points back at the trigger.
struct EmojiBar<Flight: View>: View {
    let emojis: [String]
    let size: EmojiReactionSize
    let theme: RareUITheme
    let align: EmojiReactionAlign
    let reduceMotion: Bool
    let spring: Animation
    let flight: Flight
    let onPress: (String, CGPoint) -> Void
    let onHoldStart: (String, CGPoint) -> Void
    let onHoldEnd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            row
            tail
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pick a reaction")
    }

    private var row: some View {
        HStack(spacing: size.spacing) {
            ForEach(Array(emojis.enumerated()), id: \.offset) { index, emoji in
                EmojiButton(
                    emoji: emoji,
                    size: size,
                    delay: reduceMotion ? 0 : 0.04 + Double(index) * 0.035,
                    spring: spring,
                    reduceMotion: reduceMotion,
                    onPress: { onPress(emoji, $0) },
                    onHoldStart: { onHoldStart(emoji, $0) },
                    onHoldEnd: onHoldEnd
                )
            }
        }
        .padding(size.padding)
        .background(Capsule().fill(theme.surface))
        .overlay { flight }
        .coordinateSpace(.named("rareui.emojibar"))
    }

    /// Two circles of falling size, which is how a message bubble points at whoever sent it.
    private var tail: some View {
        VStack(alignment: alignment, spacing: 2) {
            Circle().fill(theme.surface).frame(width: 12, height: 12)
            Circle().fill(theme.surface).frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .padding(.horizontal, size.padding + size.emoji / 2 - 6)
        .offset(y: -4)
    }

    private var alignment: HorizontalAlignment {
        switch align {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}
