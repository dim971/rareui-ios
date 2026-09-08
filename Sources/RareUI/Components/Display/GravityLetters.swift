//
//  GravityLetters.swift
//  A port of upstream's `components/ui/gravity-letters.tsx`.
//
//  Letters that fall out of your finger and pile up. Touch drops one, holding pours them,
//  and tilting the device makes the heap slide.
//

import CoreText
import SwiftUI

#if canImport(CoreMotion)
    import CoreMotion
#endif

/// Which glyphs fall.
public enum GravityGlyphs: String, Sendable, CaseIterable {
    /// Capital letters.
    case letters
    /// Digits.
    case numbers
    /// Both.
    case both

    var pool: [String] {
        switch self {
        case .letters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)
        case .numbers: "0123456789".map(String.init)
        case .both: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".map(String.init)
        }
    }
}

/// A container that letters fall into and pile up in.
///
/// ```swift
/// GravityLetters()
///     .frame(height: 320)
/// ```
///
/// Touching it drops a glyph where you touched. Holding for a third of a second starts
/// pouring them, and dragging steers the pour. Tilting the device past ten degrees makes
/// the pile slide the way it is leaning.
///
/// Under Reduce Motion the glyphs appear where they would have landed rather than falling
/// into place.
public struct GravityLetters: View {
    private let glyphs: GravityGlyphs
    private let items: [String]?
    private let gravity: Double
    private let size: Double
    private let color: Color?
    private let maxGlyphs: Int
    private let deviceTilt: Bool

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var field = GravityField(size: .zero)
    @State private var bounds = CGSize.zero
    @State private var running = false
    @State private var last: Date?
    @State private var pouring: Task<Void, Never>?
    @State private var tilt = GravityTilt()

    /// How long to hold before the pour starts, in seconds.
    private static var holdDelay: Double {
        0.3
    }

    /// How often it pours while held, in seconds.
    private static var pourInterval: Double {
        0.12
    }

    /// Creates a container of falling glyphs.
    ///
    /// - Parameters:
    ///   - glyphs: Which characters fall. Ignored when `items` is given.
    ///   - items: Your own strings to drop instead of letters.
    ///   - gravity: The acceleration, in points per second squared. Defaults to `800`.
    ///   - size: The glyphs' nominal point size. Each one varies around it.
    ///   - color: The ink. Defaults to the theme's foreground.
    ///   - maxGlyphs: The most to keep before the oldest are forgotten.
    ///   - deviceTilt: Whether tilting the device makes the pile slide.
    public init(
        glyphs: GravityGlyphs = .letters,
        items: [String]? = nil,
        gravity: Double = 800,
        size: Double = 28,
        color: Color? = nil,
        maxGlyphs: Int = 200,
        deviceTilt: Bool = true
    ) {
        self.glyphs = glyphs
        self.items = items
        self.gravity = gravity
        self.size = size
        self.color = color
        self.maxGlyphs = maxGlyphs
        self.deviceTilt = deviceTilt
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.clear
                heap
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(.rect)
            .gesture(pourGesture(in: proxy.size))
            .onAppear { resize(to: proxy.size) }
            .onChange(of: proxy.size) { _, size in resize(to: size) }
        }
        .accessibilityElement()
        .accessibilityLabel("Falling letters")
        .accessibilityValue("\(field.count) on the pile")
        .accessibilityHint("Touch to drop one, hold to pour")
        .onDisappear { pouring?.cancel() }
        .task(id: deviceTilt) { await watchTilt() }
    }

    @ViewBuilder
    private var heap: some View {
        let content = ZStack(alignment: .topLeading) {
            ForEach(field.bodies) { body in
                Text(body.glyph)
                    .font(.system(size: body.fontSize, weight: .semibold))
                    .foregroundStyle(color ?? theme.foreground)
                    .rotationEffect(.degrees(body.rotation))
                    .offset(x: body.x + body.offsetX, y: body.y + body.offsetY)
            }
        }

        if reduceMotion || field.isSettled {
            content
        } else {
            TimelineView(.animation) { timeline in
                content.onChange(of: timeline.date) { _, now in advance(to: now) }
            }
        }
    }

    private func advance(to now: Date) {
        // A frame that arrives late, because the app was away, is capped rather than
        // integrated in one enormous step that would fire every glyph through the floor.
        let elapsed = last.map { min(now.timeIntervalSince($0), 1.0 / 30) } ?? 0
        last = now
        field.step(by: elapsed, gravity: gravity)
    }

    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if bounds == .zero {
            field = GravityField(size: size)
        } else {
            field.resize(to: size)
        }
        bounds = size
    }

    private func pourGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard pouring == nil else {
                    // Already pouring, so the drag only steers where the next one lands.
                    pourTarget = value.location.x
                    return
                }
                drop(at: value.location.x, in: size)
                pourTarget = value.location.x
                pouring = Task { await pour(in: size) }
            }
            .onEnded { _ in
                pouring?.cancel()
                pouring = nil
            }
    }

    @State private var pourTarget = 0.0

    private func pour(in size: CGSize) async {
        try? await Task.sleep(for: .seconds(Self.holdDelay))
        while !Task.isCancelled {
            // A little scatter either side, so a held pour makes a heap rather than a tower.
            drop(at: pourTarget + Double.random(in: -8 ... 8), in: size)
            try? await Task.sleep(for: .seconds(Self.pourInterval))
        }
    }

    private func drop(at x: Double, in size: CGSize) {
        let glyph = items?.randomElement() ?? glyphs.pool.randomElement() ?? "A"
        // Each glyph is a little bigger or smaller than the nominal size, which is what
        // stops a pile of the same letter looking like a printed line.
        let fontSize = (size.height > 0 ? Double(self.size) : Double(self.size))
            * Double.random(in: 0.8 ... 1.2)
        let measured = GravityText.measure(glyph, at: fontSize)

        field.drop(
            glyph: glyph,
            fontSize: fontSize.rounded(),
            measurement: measured,
            at: min(max(x - measured.width / 2, 0), max(size.width - measured.width, 0)),
            limit: maxGlyphs
        )

        if reduceMotion {
            // Nothing falls, so the pile is simply built. Stepping it once at a large
            // interval lands everything on the spot it was already assigned.
            field.step(by: 10, gravity: gravity)
        }
        last = nil
    }

    private func watchTilt() async {
        guard deviceTilt else { return }
        for await lean in tilt.readings() {
            guard abs(lean) > 10 else {
                field.wind = 0
                continue
            }
            field.wind = lean < 0 ? -1 : 1
            field.rebuild(sliding: true)
            last = nil
            // Upstream will not start another avalanche for a third of a second, so a
            // wobbling device does not shake the pile apart.
            try? await Task.sleep(for: .seconds(0.35))
        }
    }
}

/// Measures a glyph, once per glyph and size.
///
/// CoreText rather than UIKit, because this package builds for macOS too, and cached
/// because a pour asks the same question eight times a second.
enum GravityText {
    private static let cache = GravityMeasurementCache()

    /// The size a glyph draws at.
    ///
    /// - Parameters:
    ///   - glyph: The text.
    ///   - fontSize: The point size.
    /// - Returns: Its width and height.
    static func measure(_ glyph: String, at fontSize: Double) -> CGSize {
        let key = "\(glyph)@\(Int(fontSize.rounded()))"
        if let known = cache.read(key) { return known }

        let font = CTFontCreateUIFontForLanguage(.system, fontSize, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributed = NSAttributedString(
            string: glyph,
            attributes: [kCTFontAttributeName as NSAttributedString.Key: font]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        // A glyph with no bounds would divide by nothing later on, so it takes the font's
        // own size instead.
        let measured = CGSize(
            width: max(bounds.width, fontSize * 0.4),
            height: max(bounds.height, fontSize * 0.6)
        )
        cache.write(measured, for: key)
        return measured
    }
}

/// The measurement cache's storage, locked because a shape may measure from any thread.
private final class GravityMeasurementCache: @unchecked Sendable {
    private var sizes: [String: CGSize] = [:]
    private let lock = NSLock()

    func read(_ key: String) -> CGSize? {
        lock.lock()
        defer { lock.unlock() }
        return sizes[key]
    }

    func write(_ size: CGSize, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        sizes[key] = size
    }
}

/// How far the device is leaning, in degrees, or nothing at all where there is no such idea.
@MainActor
final class GravityTilt {
    #if canImport(CoreMotion) && os(iOS)
        private let motion = CMMotionManager()
    #endif

    /// A stream of lean angles, in degrees, positive when the device is tipped right.
    func readings() -> AsyncStream<Double> {
        #if canImport(CoreMotion) && os(iOS)
            AsyncStream { continuation in
                guard motion.isDeviceMotionAvailable else {
                    continuation.finish()
                    return
                }
                motion.deviceMotionUpdateInterval = 1.0 / 10
                motion.startDeviceMotionUpdates(to: .main) { reading, _ in
                    guard let reading else { return }
                    continuation.yield(reading.gravity.x * 90)
                }
                // The manager itself cannot cross into the termination handler, which is
                // Sendable and it is not. This class is isolated to the main actor and so
                // can, and it is the one that owns the manager anyway.
                continuation.onTermination = { [weak self] _ in
                    Task { @MainActor in self?.motion.stopDeviceMotionUpdates() }
                }
            }
        #else
            AsyncStream { $0.finish() }
        #endif
    }
}
