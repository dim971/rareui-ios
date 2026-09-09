//
//  OTPInput.swift
//  A port of upstream's `components/ui/otp-input.tsx`.
//
//  A row of boxes for a one time code. Characters roll in from below as they are typed
//  and roll back out the way they came when they are deleted, a caret slides from box to
//  box, and the row shakes or draws itself a green outline depending on how the code was
//  received.
//
//  One deliberate departure, recorded in docs/fidelity.md. Upstream gives every box its
//  own text input, because on the web that is the only way to put a real caret in a
//  particular box. Here the row is backed by a single field instead. That is what makes
//  the platform behave: `.oneTimeCode` autofill offers the code from a message, paste
//  works, dictation works, and the keyboard's own delete key does the right thing. The
//  price is upstream's arrow key editing in the middle of a code, which has no equivalent
//  on a touch keyboard anyway.
//

import SwiftUI

/// What the field is saying about the code in it.
public enum OTPStatus: String, Sendable, CaseIterable {
    /// Nothing to report.
    case idle
    /// The code was accepted. Each box draws itself a green outline in turn.
    case success
    /// The code was refused. The row shakes and turns red.
    case error
}

/// What may be typed into a one time code.
public enum OTPCharacterSet: String, Sendable, CaseIterable {
    /// Digits only, with a number pad to match.
    case numbers
    /// Letters only.
    case letters
    /// Letters and digits.
    case alphanumeric

    /// Whether a character belongs in the code.
    func accepts(_ character: Character) -> Bool {
        switch self {
        case .numbers: character.isASCII && character.isNumber
        case .letters: character.isASCII && character.isLetter
        case .alphanumeric: character.isASCII && (character.isNumber || character.isLetter)
        }
    }
}

/// How large a ``OTPInput`` is drawn.
public enum OTPSize: String, Sendable, CaseIterable {
    /// The smallest, at 40 points a box.
    case small
    /// The default, at 48.
    case medium
    /// The largest, at 56.
    case large

    /// The width and height of a box, in points.
    var box: Double {
        switch self {
        case .small: 40
        case .medium: 48
        case .large: 56
        }
    }

    /// The corner radius of a box, in points.
    var radius: Double {
        switch self {
        case .small: 8
        case .medium: 12
        case .large: 16
        }
    }

    /// The character's point size.
    var fontSize: Double {
        switch self {
        case .small: 16
        case .medium: 18
        case .large: 20
        }
    }

    /// The caret's height, in points.
    var caretHeight: Double {
        switch self {
        case .small: 20
        case .medium: 24
        case .large: 28
        }
    }

    /// The space between two boxes, in points.
    var gap: Double {
        switch self {
        case .small: 6
        case .medium: 8
        case .large: 10
        }
    }
}

/// A row of boxes for a one time code.
///
/// ```swift
/// OTPInput(code: $code, status: verifying ? .idle : .error) { code in
///     verify(code)
/// }
/// ```
///
/// Under Reduce Motion the characters appear without rolling, the caret does not blink,
/// and the error shake is dropped, leaving the red outline to carry the message.
public struct OTPInput: View {
    @Binding private var code: String
    private let length: Int
    private let characterSet: OTPCharacterSet
    private let size: OTPSize
    private let status: OTPStatus
    private let mask: Bool
    private let autoFocus: Bool
    private let onComplete: ((String) -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    @FocusState private var isFocused: Bool
    @State private var caretVisible = true
    /// Whether the last change removed a character, which decides which way the outgoing
    /// one rolls: back down the way it came in, rather than up and out of the top.
    @State private var cleared = false

    /// The roll, from upstream's `ROLL_SPRING`.
    private static var roll: Animation {
        .rareUISpring(stiffness: 500, damping: 34)
    }

    /// The caret's slide, from upstream's `CARET_SPRING`.
    private static var caretSlide: Animation {
        .rareUISpring(stiffness: 500, damping: 40)
    }

    /// Half of upstream's 1.1 second blink, which is a square wave rather than a fade.
    private static var blinkHalfPeriod: Double {
        0.55
    }

    /// How far out of the box a character starts and finishes, as a fraction of its height.
    private static var rollDistance: Double {
        1.1
    }

    /// Creates a code field.
    ///
    /// - Parameters:
    ///   - code: The code typed so far. Anything in it that does not belong is dropped.
    ///   - length: How many characters the code has. Defaults to `6`.
    ///   - characterSet: What may be typed. Defaults to digits.
    ///   - size: How large to draw the boxes.
    ///   - status: What the field is saying about the code.
    ///   - mask: Whether to show bullets instead of the characters.
    ///   - autoFocus: Whether to take the keyboard as soon as the row appears.
    ///   - onComplete: Called with the code once the last box is filled.
    public init(
        code: Binding<String>,
        length: Int = 6,
        characterSet: OTPCharacterSet = .numbers,
        size: OTPSize = .medium,
        status: OTPStatus = .idle,
        mask: Bool = false,
        autoFocus: Bool = false,
        onComplete: ((String) -> Void)? = nil
    ) {
        _code = code
        self.length = max(1, length)
        self.characterSet = characterSet
        self.size = size
        self.status = status
        self.mask = mask
        self.autoFocus = autoFocus
        self.onComplete = onComplete
    }

    private var characters: [Character] {
        Array(code.prefix(length))
    }

    private var caretIndex: Int {
        min(characters.count, length - 1)
    }

    private var showsCaret: Bool {
        isFocused && characters.count < length
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            field
            boxes.allowsHitTesting(false)
            caret
        }
        .fixedSize()
        .opacity(isEnabled ? 1 : 0.5)
        .keyframeAnimator(initialValue: 0.0, trigger: shakeTrigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            // Upstream's SHAKE, over its 0.32 seconds. Four equal steps, since Motion
            // spaces a keyframe array evenly unless it is told otherwise.
            CubicKeyframe(-5, duration: 0.08)
            CubicKeyframe(4, duration: 0.08)
            CubicKeyframe(-2, duration: 0.08)
            CubicKeyframe(0, duration: 0.08)
        }
        .onChange(of: code) { old, new in
            sanitise(new, wasLonger: new.count < old.count)
        }
        .onAppear {
            sanitise(code, wasLonger: false)
            // A one time code field is usually the only thing on the screen, so taking the
            // keyboard is a kindness rather than a rudeness. Off by default all the same.
            if autoFocus, isEnabled { isFocused = true }
        }
        .accessibilityElement(children: .contain)
    }

    /// The one real text field behind the row, filling it so a tap anywhere lands here.
    ///
    /// Its own text is invisible and so is its caret, because the row draws both itself.
    private var field: some View {
        TextField("", text: $code)
            .focused($isFocused)
            .textContentType(.oneTimeCode)
            .modifier(OTPKeyboard(characterSet: characterSet))
            .autocorrectionDisabled()
            .foregroundStyle(.clear)
            .tint(.clear)
            .accentColor(.clear)
            .font(.system(size: 1))
            .frame(width: rowWidth, height: size.box)
            .contentShape(.rect)
            .accessibilityLabel("One time code, \(length) characters")
            .accessibilityValue(code.isEmpty ? "Empty" : code.map(String.init).joined(separator: " "))
    }

    private var boxes: some View {
        HStack(spacing: size.gap) {
            ForEach(0 ..< length, id: \.self) { index in
                box(at: index)
            }
        }
    }

    private func box(at index: Int) -> some View {
        let character = index < characters.count ? characters[index] : nil

        return RoundedRectangle(cornerRadius: size.radius, style: .continuous)
            .fill(theme.surface)
            .frame(width: size.box, height: size.box)
            .overlay {
                ZStack {
                    if let character {
                        Text(mask ? "\u{2022}" : String(character))
                            .font(.system(size: size.fontSize, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                            .id(String(character))
                            .transition(rollTransition)
                    }
                }
                // A character on its way in or out is riding past the edge of the box, and
                // the box is what it should disappear behind.
                .clipped()
            }
            .overlay {
                // Idle focus and error both draw a ring; success draws its own, stroke by
                // stroke, so it must not have a second one underneath.
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .strokeBorder(ringColour(at: index), lineWidth: 2)
            }
            .overlay { successRing(at: index) }
            .animation(reduceMotion ? nil : Self.roll, value: characters.count)
    }

    private var rollTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let distance = size.box * Self.rollDistance
        return .asymmetric(
            insertion: .offset(y: distance),
            // Deleting sends the character back down the way it came in; replacing it
            // pushes it up and out of the top, so the two never look like the same event.
            removal: .offset(y: cleared ? distance : -distance)
        )
    }

    private func ringColour(at index: Int) -> Color {
        switch status {
        case .error: theme.red.opacity(0.7)
        case .success: .clear
        case .idle: isFocused && index == caretIndex ? theme.glyph.opacity(0.5) : .clear
        }
    }

    @ViewBuilder
    private func successRing(at index: Int) -> some View {
        if status == .success {
            RoundedRectangle(cornerRadius: size.radius - 1, style: .continuous)
                .trim(from: 0, to: 1)
                .stroke(theme.green, lineWidth: 2)
                .padding(1)
                .modifier(
                    DrawnRing(
                        // Each box starts a twentieth of a second after the one before, so
                        // the outline runs along the row rather than appearing all at once.
                        delay: reduceMotion ? 0 : 0.15 + Double(index) * 0.05,
                        animated: !reduceMotion
                    )
                )
        }
    }

    @ViewBuilder
    private var caret: some View {
        if showsCaret {
            Capsule()
                .fill(theme.foreground)
                .frame(width: 2, height: size.caretHeight)
                .offset(x: caretOffset)
                .opacity(caretVisible ? 1 : 0)
                .animation(reduceMotion ? nil : Self.caretSlide, value: caretIndex)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .task(id: caretIndex) { await blink() }
        }
    }

    /// The caret sits in the middle of the box it is in.
    private var caretOffset: Double {
        Double(caretIndex) * (size.box + size.gap) + size.box / 2 - 1
    }

    private var rowWidth: Double {
        Double(length) * size.box + Double(length - 1) * size.gap
    }

    /// Upstream's blink is a square wave, not a fade: fully on for half the period and
    /// fully off for the other half. The caret is also restarted whenever it moves, so it
    /// is always solid at the moment it arrives in a new box.
    private func blink() async {
        caretVisible = true
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Self.blinkHalfPeriod))
            guard !Task.isCancelled else { return }
            caretVisible.toggle()
        }
    }

    /// Changes only when an error arrives, so the row shakes once per rejection rather
    /// than on every keystroke while it is in an error state.
    private var shakeTrigger: Bool {
        status == .error && !reduceMotion
    }

    /// Drops anything that does not belong in the code and stops it growing past the row.
    private func sanitise(_ raw: String, wasLonger: Bool) {
        cleared = wasLonger
        let kept = otpAccepted(raw, length: length, characterSet: characterSet)
        if kept != raw { code = kept }
        if kept.count == length { onComplete?(kept) }
    }
}

/// What survives of a string once it has to be a code.
///
/// Everything that does not belong in the character set is dropped rather than refused,
/// which is what lets a pasted or autofilled code arrive with its own punctuation and
/// still land in the boxes. What is left is cut to the row's length.
///
/// - Parameters:
///   - raw: Whatever arrived in the field.
///   - length: How many characters the row holds.
///   - characterSet: What belongs in the code.
/// - Returns: The code to show.
func otpAccepted(_ raw: String, length: Int, characterSet: OTPCharacterSet) -> String {
    String(raw.filter(characterSet.accepts).prefix(max(0, length)))
}

/// The keyboard a code should be typed on.
///
/// Its own file's worth of conditional compilation, because a keyboard type and an
/// autocapitalisation policy are both UIKit ideas and this package builds for macOS too.
private struct OTPKeyboard: ViewModifier {
    let characterSet: OTPCharacterSet

    func body(content: Content) -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
            content
                .keyboardType(characterSet == .numbers ? .numberPad : .asciiCapable)
                .textInputAutocapitalization(characterSet == .numbers ? .never : .characters)
        #else
            content
        #endif
    }
}

/// Draws a ring on, once, after a delay.
///
/// The trim has to start at zero and end at one, and both have to happen after the view
/// is on screen for the stroke to animate rather than simply appear.
private struct DrawnRing: ViewModifier {
    let delay: Double
    let animated: Bool

    @State private var drawn = false

    func body(content: Content) -> some View {
        content
            .mask {
                GeometryReader { proxy in
                    // Masking with a growing rectangle draws the ring from the left, which
                    // is what a trimmed path does on a rounded rectangle without any of the
                    // corner cases a trim has at the corners themselves.
                    Rectangle()
                        .frame(width: drawn ? proxy.size.width : 0)
                }
            }
            .onAppear {
                guard animated else {
                    drawn = true
                    return
                }
                withAnimation(.easeOut(duration: 0.45).delay(delay)) { drawn = true }
            }
    }
}
