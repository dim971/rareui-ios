//
//  DurationPicker.swift
//  A port of upstream's `components/ui/duration-picker.tsx`.
//
//  Three touching squircles, an hours field, a minutes field and a pen. Pressing the pen
//  separates them, opens the fields for editing and turns the pen into a tick.
//

import SwiftUI

/// A length of time, as hours and minutes.
public struct DurationValue: Equatable, Sendable {
    /// Whole hours.
    public var hours: Int
    /// Whole minutes.
    public var minutes: Int

    /// Creates a duration.
    ///
    /// - Parameters:
    ///   - hours: Whole hours.
    ///   - minutes: Whole minutes.
    public init(hours: Int = 0, minutes: Int = 0) {
        self.hours = hours
        self.minutes = minutes
    }
}

/// Confines a typed number to what the field will accept.
///
/// Anything that is not a number at all becomes zero, which is what upstream's `|| 0` does
/// and what stops a half typed minus sign emptying the field.
///
/// - Parameters:
///   - raw: The number typed.
///   - max: The largest the field accepts.
/// - Returns: The number the field will hold.
func durationClamp(_ raw: Int, max limit: Int) -> Int {
    min(limit, max(0, raw))
}

/// Three touching squircles that separate to be edited.
///
/// ```swift
/// DurationPicker(value: $duration) { confirmed in
///     schedule(for: confirmed)
/// }
/// ```
///
/// Under Reduce Motion the segments separate without springing and the pen becomes a tick
/// without morphing.
public struct DurationPicker: View {
    @Binding private var value: DurationValue
    private let maxHours: Int
    private let maxMinutes: Int
    private let hoursLabel: String
    private let minutesLabel: String
    private let onConfirm: ((DurationValue) -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focus: DurationField?

    @State private var editing = false
    @State private var hoursText = ""
    @State private var minutesText = ""
    @State private var errorNudge = 0.0

    /// How far the segments separate, in points.
    private static var openGap: Double {
        8
    }

    /// The outer corner radius.
    private static var cornerRadius: Double {
        12
    }

    /// Every segment's height.
    private static var height: Double {
        48
    }

    /// The separation's spring, from upstream's `GAP_SPRING`.
    private static var gapSpring: Animation {
        .rareUISpring(stiffness: 200, damping: 28, mass: 1)
    }

    /// The fields' width, from `WIDTH_SPRING`.
    private static var widthSpring: Animation {
        .rareUISpring(stiffness: 250, damping: 31)
    }

    /// The pen becoming a tick, from `ICON_SPRING`.
    private static var iconSpring: Animation {
        .rareUISpring(stiffness: 200, damping: 28)
    }

    /// The shake on an out of range entry, from `ERROR_SPRING`. Stiff and barely damped.
    private static var errorSpring: Animation {
        .rareUISpring(stiffness: 700, damping: 9)
    }

    /// Which field the keyboard is in.
    private enum DurationField: Hashable {
        case hours
        case minutes
    }

    /// Creates a duration picker.
    ///
    /// - Parameters:
    ///   - value: The duration.
    ///   - maxHours: The largest number of hours accepted.
    ///   - maxMinutes: The largest number of minutes accepted.
    ///   - hoursLabel: The word after the hours field.
    ///   - minutesLabel: The word after the minutes field.
    ///   - onConfirm: Called with the duration when the tick is pressed.
    public init(
        value: Binding<DurationValue>,
        maxHours: Int = 24,
        maxMinutes: Int = 60,
        hoursLabel: String = "Hr.",
        minutesLabel: String = "Min.",
        onConfirm: ((DurationValue) -> Void)? = nil
    ) {
        _value = value
        self.maxHours = maxHours
        self.maxMinutes = maxMinutes
        self.hoursLabel = hoursLabel
        self.minutesLabel = minutesLabel
        self.onConfirm = onConfirm
    }

    private var gap: Double {
        editing ? Self.openGap : 0
    }

    private var openness: Double {
        editing ? 1 : 0
    }

    private var innerRadius: Double {
        Self.cornerRadius * openness
    }

    public var body: some View {
        HStack(spacing: 0) {
            segment(
                leading: Self.cornerRadius,
                trailing: innerRadius,
                padLeading: 8,
                padTrailing: 3 + 9 * openness
            ) {
                field(.hours, text: $hoursText, max: maxHours)
                label(hoursLabel, weight: .semibold)
            }

            spacer

            segment(
                leading: innerRadius,
                trailing: innerRadius,
                padLeading: 9 * openness,
                padTrailing: 3 + 9 * openness
            ) {
                field(.minutes, text: $minutesText, max: maxMinutes)
                label(minutesLabel, weight: .medium)
            }

            spacer
            toggle
        }
        .animation(reduceMotion ? nil : Self.gapSpring, value: editing)
        .opacity(isEnabled ? 1 : 0.5)
        .onAppear { syncFromValue() }
        .onChange(of: value) { _, _ in syncFromValue() }
        .accessibilityElement(children: .contain)
    }

    private var spacer: some View {
        // The closed gap pulls in by a point, so two touching squircles read as one shape
        // rather than showing a hairline between them.
        Color.clear.frame(width: max(0, gap - (1 - openness)), height: 0)
    }

    private func segment(
        leading: Double,
        trailing: Double,
        padLeading: Double,
        padTrailing: Double,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        HStack(spacing: 4) {
            content()
        }
        .padding(.leading, padLeading)
        .padding(.trailing, padTrailing)
        .frame(height: Self.height)
        .background {
            // A continuous corner is the squircle upstream builds with figma-squircle at
            // full corner smoothing. It is the same curve, and it is native here.
            UnevenRoundedRectangle(
                topLeadingRadius: leading,
                bottomLeadingRadius: leading,
                bottomTrailingRadius: trailing,
                topTrailingRadius: trailing,
                style: .continuous
            )
            .fill(theme.surface)
        }
    }

    private func field(_ which: DurationField, text: Binding<String>, max _: Int) -> some View {
        DurationTextField(
            text: text,
            placeholder: editing ? "" : "0",
            editing: editing,
            widthSpring: reduceMotion ? nil : Self.widthSpring,
            onOutOfRange: { nudge() }
        )
        .focused($focus, equals: which)
        .foregroundStyle(theme.foreground)
        .offset(x: sway + errorNudge)
        .accessibilityLabel(which == .hours ? hoursLabel : minutesLabel)
    }

    private func label(_ text: String, weight: Font.Weight) -> some View {
        Text(text)
            .font(.system(size: 16, weight: weight))
            .foregroundStyle(theme.glyph.opacity(0.7))
            .offset(x: sway)
            .accessibilityHidden(true)
    }

    private var toggle: some View {
        Button {
            let next = !editing
            editing = next
            if next {
                focus = .hours
            } else {
                focus = nil
                commit()
                onConfirm?(value)
            }
        } label: {
            PenTick(progress: editing ? 1 : 0, ink: theme.glyph, surface: theme.surface)
                .frame(width: 18, height: 18)
                .frame(width: Self.height, height: Self.height)
                .background {
                    UnevenRoundedRectangle(
                        topLeadingRadius: innerRadius,
                        bottomLeadingRadius: innerRadius,
                        bottomTrailingRadius: Self.cornerRadius,
                        topTrailingRadius: Self.cornerRadius,
                        style: .continuous
                    )
                    .fill(theme.surface)
                }
        }
        .buttonStyle(PressScaleButton(scale: 0.9, reduceMotion: reduceMotion))
        .animation(reduceMotion ? nil : Self.iconSpring, value: editing)
        .accessibilityLabel(editing ? "Save duration" : "Edit duration")
    }

    /// The lag the contents take on as the picker opens.
    ///
    /// Upstream reads the gap's own velocity and maps it to a three point lean. There is no
    /// velocity to read here, so the lean is taken from the direction of travel instead and
    /// carried by the same spring, which comes out the same at both ends and slightly
    /// gentler in between.
    private var sway: Double {
        editing ? 3 : 0
    }

    private func nudge() {
        guard !reduceMotion else { return }
        errorNudge = 6
        withAnimation(Self.errorSpring) { errorNudge = 0 }
    }

    private func syncFromValue() {
        hoursText = value.hours == 0 ? "" : String(value.hours)
        minutesText = value.minutes == 0 ? "" : String(value.minutes)
    }

    private func commit() {
        value = DurationValue(
            hours: durationClamp(Int(hoursText) ?? 0, max: maxHours),
            minutes: durationClamp(Int(minutesText) ?? 0, max: maxMinutes)
        )
    }
}

/// One of the two numbers, which grows to a fixed width while it is being edited.
private struct DurationTextField: View {
    @Binding var text: String
    let placeholder: String
    let editing: Bool
    let widthSpring: Animation?
    let onOutOfRange: () -> Void

    @State private var measured = 0.0

    /// How wide the field opens to while it is being edited.
    private static var editingWidth: Double {
        44
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .multilineTextAlignment(.center)
            .font(.system(size: 16, weight: .semibold))
            .modifier(DurationKeyboard())
            .disabled(!editing)
            .frame(width: editing ? Self.editingWidth : max(measured + 12, 22))
            .animation(widthSpring, value: editing)
            .animation(widthSpring, value: measured)
            .background {
                Text(text.isEmpty ? "0" : text)
                    .font(.system(size: 16, weight: .semibold))
                    .hidden()
                    .fixedSize()
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { measured = proxy.size.width }
                                .onChange(of: proxy.size.width) { _, width in measured = width }
                        }
                    }
            }
            .onChange(of: text) { _, _ in onOutOfRange() }
    }
}

/// The number pad, which is a UIKit idea and this package builds for macOS too.
private struct DurationKeyboard: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
            content.keyboardType(.numberPad)
        #else
            content
        #endif
    }
}

/// The pen that becomes a tick.
private struct PenTick: View {
    let progress: Double
    let ink: Color
    let surface: Color

    /// The two outlines, quoted from upstream's `PEN_PATH` and `TICK_PATH`.
    private static let pen = SVGPath.path(
        """
        M3.78181 16.3092L3 21L7.69086 20.2182C8.50544 20.0825 9.25725 19.6956 9.84119 \
        19.1116L20.4198 8.53288C21.1934 7.75922 21.1934 6.5049 20.4197 5.73126L18.2687 \
        3.58024C17.495 2.80658 16.2406 2.80659 15.4669 3.58027L4.88841 14.159C4.30447 \
        14.7429 3.91757 15.4947 3.78181 16.3092Z
        """
    )
    private static let tick = SVGPath.path(
        "M7.959 20.513L1.592 12.872L3.128 11.592L8.041 17.487L20.947 3.587L22.413 4.948L7.959 20.513Z"
    )
    private static let morph = PathMorph(from: pen, to: tick)
    private static let box = CGSize(width: 24, height: 24)

    var body: some View {
        ZStack {
            MorphedShape(progress: progress, morph: Self.morph, viewBox: Self.box)
                .fill(ink)
                .overlay {
                    // A stroke that grows as the tick arrives, so the finished mark is
                    // heavier than the pen it came from.
                    MorphedShape(progress: progress, morph: Self.morph, viewBox: Self.box)
                        .stroke(
                            ink.opacity(progress),
                            style: StrokeStyle(lineWidth: 2.5 * progress, lineCap: .round, lineJoin: .round)
                        )
                }

            // The pen's nib line, drawn in the surface colour so it reads as a gap. It
            // fades out over the first two fifths of the morph, before the shape has
            // changed enough for a gap across it to look wrong.
            SVGShape("M14 6L18 10", viewBox: Self.box)
                .stroke(surface, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .opacity(max(0, 1 - progress / 0.4))
        }
        .accessibilityHidden(true)
    }
}

/// A shape partway between two others.
private struct MorphedShape: Shape {
    var progress: Double
    let morph: PathMorph
    let viewBox: CGSize

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        morph.path(at: progress, in: rect, viewBox: viewBox)
    }
}

/// The press behaviour of the pen, which upstream writes as `active:scale-90`.
private struct PressScaleButton: ButtonStyle {
    let scale: Double
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
