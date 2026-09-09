//
//  GridReveal.swift
//  A port of upstream's `components/ui/grid-reveal.tsx`.
//
//  A placeholder that becomes a picture by dividing itself, over and over, into the picture.
//  Each split slides two halves out of where their parent was, the cells take on the average
//  colour of what is underneath them, and the photograph itself only arrives at the very end.
//
//  One departure, recorded in docs/fidelity.md: this takes an image rather than a URL, for
//  the same reason nothing else in this library reaches the network.
//

import CoreGraphics
import SwiftUI

/// A picture that reveals itself by subdividing.
///
/// ```swift
/// GridReveal(image: photo, caption: "Generating")
/// ```
///
/// Give it a `progress` and it follows that. Leave it out and it paces itself, creeping
/// toward nine tenths and holding there until the picture is ready, so a load that takes
/// longer than expected still looks like it is working.
///
/// Under Reduce Motion it draws the finished picture without revealing it.
public struct GridReveal: View {
    private let image: CGImage?
    private let progress: Double?
    private let aspect: Double
    private let caption: String?
    private let estimatedDuration: Double
    private let onRevealComplete: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene = GridRevealScene()
    @State private var started = Date()

    /// Where the gutters between cells begin closing.
    private static var gutterFrom: Double {
        0.35
    }

    /// And where they have gone entirely.
    private static var gutterTo: Double {
        0.75
    }

    /// Where the photograph itself begins to arrive.
    private static var photoFrom: Double {
        0.93
    }

    /// Creates a reveal.
    ///
    /// - Parameters:
    ///   - image: The picture. Until it is given, the grid stays grey and keeps working.
    ///   - progress: How far along the work is, in `0...1`. Leave it out to let the reveal
    ///     pace itself.
    ///   - aspect: The frame's width over its height.
    ///   - caption: A line shown over the grid while it works.
    ///   - estimatedDuration: How long the work is expected to take, in seconds, which is
    ///     what a self-paced reveal creeps against.
    ///   - onRevealComplete: Called once the picture has fully arrived.
    public init(
        image: CGImage? = nil,
        progress: Double? = nil,
        aspect: Double = 1,
        caption: String? = nil,
        estimatedDuration: Double = 6,
        onRevealComplete: (() -> Void)? = nil
    ) {
        self.image = image
        self.progress = progress
        self.aspect = aspect
        self.caption = caption
        self.estimatedDuration = estimatedDuration
        self.onRevealComplete = onRevealComplete
    }

    public var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas(rendersAsynchronously: false) { context, size in
                let frame = scene.advance(
                    to: timeline.date,
                    since: started,
                    progress: reduceMotion ? 1 : progress,
                    duration: estimatedDuration,
                    hasImage: image != nil,
                    reduceMotion: reduceMotion
                )
                draw(frame, into: &context, size: size)
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottom) { captionPill }
        .onAppear { prepare() }
        .onChange(of: image) { _, _ in prepare() }
        .accessibilityHidden(caption == nil)
        .accessibilityLabel(caption ?? "")
    }

    @ViewBuilder
    private var captionPill: some View {
        // Shown while there is nothing to show yet. Asking the scene how far along it is
        // would mean reading state the draw pass writes, which is the loop described above.
        if let caption {
            Text(caption)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(.black.opacity(0.45)))
                .background(.ultraThinMaterial, in: .capsule)
                .padding(12)
        }
    }

    private func prepare() {
        started = Date()
        scene.build(aspect: aspect, image: image, dark: colorScheme == .dark)
        if reduceMotion { scene.finish() }
    }

    private func draw(_ frame: GridRevealFrame, into context: inout GraphicsContext, size: CGSize) {
        guard let root = scene.root else { return }

        // The gutters recess into this rather than cutting through to whatever is behind
        // the component, so the grid reads as one object with grooves in it.
        // A shade darker than the cells, so a gutter looks like a groove cut into the
        // surface rather than a hole through it. Upstream multiplies the ground by 0.92.
        let base = shaded(
            grey: gridRevealGrey(tone: root.tone, dark: frame.dark, clock: frame.clock),
            target: GridRevealInk(red: root.red, green: root.green, blue: root.blue),
            tint: frame.tint,
            dim: 0.92
        )
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(base)
        )

        let soft = 1 - gridRevealSmoothstep(Self.gutterFrom, Self.gutterTo, frame.split)
        walk(
            root,
            patch: GridRevealPatch(
                rect: CGRect(origin: .zero, size: size),
                red: root.red, green: root.green, blue: root.blue, tone: root.tone
            ),
            frame: frame,
            size: size,
            gutter: soft,
            into: &context
        )

        guard let image, frame.fade > 0 else { return }
        let photo = scene.hasColours
            ? gridRevealSmoothstep(Self.photoFrom, 1, frame.split) * frame.fade
            : frame.fade
        guard photo > 0.002 else { return }

        context.opacity = photo
        context.draw(Image(decorative: image, scale: 1), in: coverRect(image, in: size))
        context.opacity = 1
    }

    private func walk(
        _ cell: GridRevealCell,
        patch: GridRevealPatch,
        frame: GridRevealFrame,
        size: CGSize,
        gutter: Double,
        into context: inout GraphicsContext
    ) {
        guard let children = cell.children, frame.split >= cell.splitAt else {
            paint(patch, frame: frame, size: size, gutter: gutter, into: &context)
            return
        }

        // The children start on their parent's rectangle and slide into their own, so a
        // split looks like one thing coming apart rather than two things appearing.
        let t = 1 - pow(1 - min(1, max(0, (frame.split - cell.splitAt) / gridRevealMorph)), 3)
        for kid in [children.0, children.1] {
            walk(
                kid,
                patch: patch.blended(
                    toward: kid,
                    at: t,
                    in: CGSize(width: size.width, height: size.height)
                ),
                frame: frame,
                size: size,
                gutter: gutter,
                into: &context
            )
        }
    }

    private func paint(
        _ patch: GridRevealPatch,
        frame: GridRevealFrame,
        size: CGSize,
        gutter soft: Double,
        into context: inout GraphicsContext
    ) {
        // Whole pixels, so two neighbouring cells stay flush and no seam shows between them.
        let x = patch.rect.minX.rounded()
        let y = patch.rect.minY.rounded()
        let width = patch.rect.maxX.rounded() - x
        let height = patch.rect.maxY.rounded() - y

        let gutter = soft * 2
        // Only interior edges are inset, so the outer silhouette stays the frame.
        let left = x <= 0 ? 0 : gutter
        let top = y <= 0 ? 0 : gutter
        let innerWidth = width - left - (x + width >= size.width ? 0 : gutter)
        let innerHeight = height - top - (y + height >= size.height ? 0 : gutter)
        guard innerWidth > 0, innerHeight > 0 else { return }

        let colour = shaded(
            grey: gridRevealGrey(tone: patch.tone, dark: frame.dark, clock: frame.clock),
            target: GridRevealInk(red: patch.red, green: patch.green, blue: patch.blue),
            tint: frame.tint
        )
        let radius = min(innerWidth, innerHeight) * 0.12 * soft
        let rect = CGRect(x: x + left, y: y + top, width: innerWidth, height: innerHeight)

        context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(colour))
    }

    /// Mixes a cell's placeholder grey toward the colour of what is underneath it.
    private func shaded(
        grey: Double,
        target: GridRevealInk,
        tint: Double,
        dim: Double = 1
    ) -> Color {
        Color(
            red: (grey + (target.red - grey) * tint) / 255 * dim,
            green: (grey + (target.green - grey) * tint) / 255 * dim,
            blue: (grey + (target.blue - grey) * tint) / 255 * dim
        )
    }

    /// The rectangle a picture fills the frame with, cropping rather than letterboxing.
    private func coverRect(_ image: CGImage, in size: CGSize) -> CGRect {
        let scale = max(size.width / Double(image.width), size.height / Double(image.height))
        let width = Double(image.width) * scale
        let height = Double(image.height) * scale
        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
    }
}

/// A colour in the eight bit terms the averages are measured in.
struct GridRevealInk {
    var red: Double
    var green: Double
    var blue: Double
}

/// One rectangle being painted, partway between its parent's place and its own.
struct GridRevealPatch {
    var rect: CGRect
    var red: Double
    var green: Double
    var blue: Double
    var tone: Double

    /// This patch moved a fraction of the way toward a cell's own place and colour.
    func blended(toward cell: GridRevealCell, at t: Double, in size: CGSize) -> GridRevealPatch {
        func mix(_ from: Double, _ to: Double) -> Double {
            from + (to - from) * t
        }
        return GridRevealPatch(
            rect: CGRect(
                x: mix(rect.minX, cell.x * size.width),
                y: mix(rect.minY, cell.y * size.height),
                width: mix(rect.width, cell.width * size.width),
                height: mix(rect.height, cell.height * size.height)
            ),
            red: mix(red, cell.red),
            green: mix(green, cell.green),
            blue: mix(blue, cell.blue),
            tone: mix(tone, cell.tone)
        )
    }
}

/// Everything one frame of the reveal needs.
struct GridRevealFrame {
    let clock: Double
    let split: Double
    let fade: Double
    let tint: Double
    let dark: Bool
}

/// The reveal's state between frames.
///
/// Deliberately not observable. It is written to from inside the draw pass, and anything
/// watching it would ask for another frame in response to the frame it is already drawing,
/// which never stops. The `TimelineView` above is already asking for every frame there is.
@MainActor
final class GridRevealScene {
    private(set) var root: GridRevealCell?
    private(set) var hasColours = false
    private(set) var split = 0.0

    private var branches: [GridRevealCell] = []
    private var clock = 0.0
    private var fade = 0.0
    private var last: Date?
    private var dark = false

    /// Builds the subdivision and, if there is a picture, measures it.
    func build(aspect: Double, image: CGImage?, dark: Bool) {
        let tree = gridRevealBuildTree(aspect: aspect)
        root = tree.root
        branches = tree.branches
        self.dark = dark
        clock = 0
        split = 0
        fade = 0
        last = nil
        hasColours = false

        guard let image, let pixels = Self.sample(image) else { return }
        gridRevealMeasure(root: tree.root, pixels: pixels, size: gridRevealSample)
        // Now that the picture is known, the splits are reordered so its busiest parts come
        // apart first. The times are reused, so the pacing does not change with the order.
        gridRevealOrderByDetail(tree.branches, openedBefore: split)
        hasColours = true
    }

    /// Sends the reveal straight to the end, for when nothing should move.
    func finish() {
        split = 1
        fade = 1
    }

    /// Steps the reveal up to a moment.
    func advance(
        to now: Date,
        since started: Date,
        progress: Double?,
        duration: Double,
        hasImage: Bool,
        reduceMotion: Bool
    ) -> GridRevealFrame {
        let elapsed = last.map { min(now.timeIntervalSince($0), 0.05) } ?? 0
        last = now
        clock += elapsed

        let target: Double = if let progress {
            min(1, max(0, progress))
        } else if hasImage {
            1
        } else {
            // Waiting: the grid creeps but stops short, leaving the arrival somewhere to go.
            min(gridRevealWaitCap, gridRevealSelfPaced(
                elapsed: now.timeIntervalSince(started),
                duration: duration
            ))
        }

        if reduceMotion {
            split = target
            fade = hasColours ? 1 : 0
        } else {
            // Two exponential smoothers, upstream's own rates: the split settles a little
            // faster than the colour does.
            split += (target - split) * (1 - exp(-elapsed * 5.5))
            let colourTarget: Double = hasColours ? 1 : 0
            fade += (colourTarget - fade) * (1 - exp(-elapsed * 4))
        }

        return GridRevealFrame(
            clock: clock,
            split: split,
            fade: fade,
            tint: hasColours ? fade : 0,
            dark: dark
        )
    }

    /// Reduces a picture to a small square of pixels, which is all the averages need.
    private static func sample(_ image: CGImage) -> [UInt8]? {
        let size = gridRevealSample
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        var drawn = false

        pixels.withUnsafeMutableBytes { buffer in
            guard
                let base = buffer.baseAddress,
                let context = CGContext(
                    data: base,
                    width: size,
                    height: size,
                    bitsPerComponent: 8,
                    bytesPerRow: size * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return }

            // Cropped to fill rather than squashed, so the averages line up with what the
            // finished picture will actually show.
            let scale = max(Double(size) / Double(image.width), Double(size) / Double(image.height))
            let width = Double(image.width) * scale
            let height = Double(image.height) * scale
            context.draw(
                image,
                in: CGRect(
                    x: (Double(size) - width) / 2,
                    y: (Double(size) - height) / 2,
                    width: width,
                    height: height
                )
            )
            drawn = true
        }

        // A picture that could not be read leaves the grid grey rather than colouring it
        // in from a buffer full of nothing.
        return drawn ? pixels : nil
    }
}
