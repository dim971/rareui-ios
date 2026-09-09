//
//  CodeBlockTheme.swift
//  The palette CodeBlock builds out of a single colour, ported from the `buildTheme`
//  function in upstream's `components/ui/code-block.tsx`.
//
//  This is the part of the component worth being exact about. Every colour in a syntax
//  theme is derived from one accent: its hue and saturation are kept, its lightness is
//  replaced with a value per token kind, and in a light appearance the whole ramp is
//  flipped. Eleven token kinds, one hex, no table of hand-picked colours to drift.
//

import SwiftUI

/// What a piece of source code is.
public enum CodeTokenKind: String, Sendable, CaseIterable {
    /// Anything with no other kind.
    case plain
    /// A comment, of either sort.
    case comment
    /// Brackets, commas, semicolons.
    case punctuation
    /// Arithmetic, comparison and assignment.
    case `operator`
    /// A reserved word, drawn in the accent itself.
    case keyword
    /// A string or a character.
    case string
    /// A name being called.
    case function
    /// An attribute's name, in a markup language.
    case attributeName
    /// A number, or a word that behaves like one.
    case number
    /// A type's name.
    case className
    /// A property or a variable.
    case property
    /// A regular expression.
    case regex

    /// Whether the kind is drawn in italic, as upstream draws comments and attribute names.
    var isItalic: Bool {
        self == .comment || self == .attributeName
    }
}

/// A syntax theme, and the chrome around it, derived from one colour.
public struct CodeBlockTheme: Sendable {
    /// The colour each token kind is drawn in.
    public let tokens: [CodeTokenKind: Color]
    /// The panel behind the code.
    public let background: Color
    /// The hairline around it and under its header.
    public let border: Color
    /// The header's own slightly lifted ground.
    public let headerBackground: Color
    /// The filename and the language, which are quieter than the code.
    public let muted: Color
    /// The line numbers, quieter still.
    public let gutter: Color
    /// The wash behind a highlighted line.
    public let lineWash: Color
    /// The accent, after it has been brought into a usable range.
    public let accent: Color

    /// Builds a theme from one colour.
    ///
    /// - Parameters:
    ///   - accent: Any colour. The whole theme is shades of it.
    ///   - dark: Whether to build the dark appearance.
    public init(accent: Color, dark: Bool) {
        self.init(hsl: CodeBlockTheme.hsl(of: accent), dark: dark)
    }

    /// Builds a theme from a colour already in hue, saturation and lightness.
    ///
    /// - Parameters:
    ///   - hsl: The accent.
    ///   - dark: Whether to build the dark appearance.
    init(hsl accentHSL: HSL, dark: Bool) {
        let hue = accentHSL.hue
        let saturation = accentHSL.saturation

        // The accent, kept where it is legible: not so dark it disappears into the panel,
        // not so pale it stops reading as a colour.
        let usable = dark
            ? min(max(accentHSL.lightness, 56), 70)
            : min(max(accentHSL.lightness, 38), 50)
        let accentTone = Color(HSL(hue: hue, saturation: saturation, lightness: usable))

        /// A light appearance is the same ramp upside down, which is the whole of what
        /// upstream does to invert the theme.
        func ramp(_ lightness: Double) -> Double {
            dark ? lightness : 100 - lightness
        }
        func tint(_ lightness: Double, _ saturation: Double = saturation) -> Color {
            Color(HSL(hue: hue, saturation: saturation, lightness: lightness))
        }

        tokens = [
            .plain: dark ? .white : Color(hex: "#171717"),
            .comment: tint(ramp(42), saturation * 0.35),
            .punctuation: tint(ramp(62), saturation * 0.3),
            .operator: tint(ramp(70), saturation * 0.4),
            .keyword: accentTone,
            .string: tint(ramp(76)),
            .function: tint(ramp(88), saturation * 0.5),
            .attributeName: tint(ramp(78), saturation * 0.7),
            .number: tint(ramp(70)),
            .className: tint(ramp(93), saturation * 0.35),
            .property: tint(ramp(97), saturation * 0.15),
            .regex: tint(ramp(72), saturation * 0.6)
        ]

        accent = accentTone
        // Upstream states these two in oklch, which has no counterpart here. These are the
        // same greys: a very dark neutral and a very light one.
        background = dark ? Color(hex: "#232323") : Color(hex: "#FAFAFA")
        border = dark ? .white.opacity(0.08) : .black.opacity(0.08)
        headerBackground = dark ? .white.opacity(0.03) : .black.opacity(0.03)
        muted = dark ? .white.opacity(0.6) : .black.opacity(0.6)
        gutter = dark ? .white.opacity(0.28) : .black.opacity(0.32)
        lineWash = Color(
            HSL(
                hue: hue,
                saturation: saturation,
                lightness: dark ? 58 : 45,
                alpha: dark ? 0.1 : 0.08
            )
        )
    }

    /// The colour a token kind is drawn in.
    ///
    /// - Parameter kind: The kind.
    /// - Returns: Its colour, falling back to plain text.
    public func color(for kind: CodeTokenKind) -> Color {
        tokens[kind] ?? tokens[.plain] ?? .primary
    }

    /// Reads a SwiftUI colour back into hue, saturation and lightness.
    ///
    /// Falls back to upstream's own fallback, a strong blue, for a colour that cannot be
    /// resolved, which is what stops an unreadable accent producing an unreadable theme.
    private static func hsl(of color: Color) -> HSL {
        let resolved = color.resolve(in: EnvironmentValues())
        let rgba = RGBA(
            red: Double(resolved.red),
            green: Double(resolved.green),
            blue: Double(resolved.blue),
            alpha: Double(resolved.opacity)
        )
        guard rgba.red.isFinite, rgba.green.isFinite, rgba.blue.isFinite else {
            return HSL(hue: 211, saturation: 100, lightness: 52)
        }
        return rgba.hsl
    }
}

extension Color {
    /// A colour from hue, saturation and lightness.
    init(_ hsl: HSL) {
        let rgba = hsl.rgba
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}
