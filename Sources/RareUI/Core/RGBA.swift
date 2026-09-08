//
//  RGBA.swift
//  Colour arithmetic, kept free of SwiftUI so it can be unit tested on any platform.
//  CodeBlock derives an entire syntax theme from one accent hex by way of HSL, so the
//  conversions here are load-bearing rather than convenience.
//

import Foundation

/// A colour in the sRGB space, with each component in `0...1`.
public struct RGBA: Equatable, Sendable {
    /// The red component, in `0...1`.
    public var red: Double
    /// The green component, in `0...1`.
    public var green: Double
    /// The blue component, in `0...1`.
    public var blue: Double
    /// The alpha component, in `0...1`.
    public var alpha: Double

    /// Creates a colour from its components.
    ///
    /// - Parameters:
    ///   - red: The red component, in `0...1`.
    ///   - green: The green component, in `0...1`.
    ///   - blue: The blue component, in `0...1`.
    ///   - alpha: The alpha component, in `0...1`. Defaults to fully opaque.
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parses a CSS style hex string.
    ///
    /// Accepts `RGB`, `RGBA`, `RRGGBB` and `RRGGBBAA`, with or without a leading `#`.
    /// Returns `nil` for anything else, including strings of the right length holding
    /// characters that are not hex digits.
    ///
    /// - Parameter hex: The hex string, for example `"#F4F4F9"`.
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.allSatisfy(\.isHexDigit) else { return nil }

        // The three and four digit forms repeat each digit, so `#f80` is `#ff8800`.
        let expanded: String
        switch text.count {
        case 3, 4: expanded = text.map { "\($0)\($0)" }.joined()
        case 6, 8: expanded = text
        default: return nil
        }

        guard let value = UInt32(expanded, radix: 16) else { return nil }
        let hasAlpha = expanded.count == 8
        let shifted = hasAlpha ? value : value << 8 | 0xFF

        self.init(
            red: Double(shifted >> 24 & 0xFF) / 255,
            green: Double(shifted >> 16 & 0xFF) / 255,
            blue: Double(shifted >> 8 & 0xFF) / 255,
            alpha: Double(shifted & 0xFF) / 255
        )
    }
}

/// A colour expressed as hue, saturation and lightness.
///
/// CodeBlock builds its whole palette by taking one accent colour here, walking the
/// lightness up and down a ramp, and converting back. Working in HSL rather than sRGB
/// is what keeps the derived tones reading as the same hue.
public struct HSL: Equatable, Sendable {
    /// The hue, in degrees, `0..<360`.
    public var hue: Double
    /// The saturation, as a percentage, `0...100`.
    public var saturation: Double
    /// The lightness, as a percentage, `0...100`.
    public var lightness: Double
    /// The alpha component, in `0...1`.
    public var alpha: Double

    /// Creates a colour from its components.
    ///
    /// - Parameters:
    ///   - hue: The hue, in degrees.
    ///   - saturation: The saturation, as a percentage.
    ///   - lightness: The lightness, as a percentage.
    ///   - alpha: The alpha component, in `0...1`. Defaults to fully opaque.
    public init(hue: Double, saturation: Double, lightness: Double, alpha: Double = 1) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
        self.alpha = alpha
    }
}

public extension RGBA {
    /// This colour converted to hue, saturation and lightness.
    var hsl: HSL {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let lightness = (maximum + minimum) / 2
        let delta = maximum - minimum

        guard delta > 0 else { return HSL(hue: 0, saturation: 0, lightness: lightness * 100, alpha: alpha) }

        // Saturation folds around mid lightness: the same delta means more saturation
        // near the ends of the range than it does in the middle.
        let saturation = delta / (1 - abs(2 * lightness - 1))

        let hue: Double = switch maximum {
        case red: 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        case green: 60 * ((blue - red) / delta + 2)
        default: 60 * ((red - green) / delta + 4)
        }

        return HSL(
            hue: hue < 0 ? hue + 360 : hue,
            saturation: saturation * 100,
            lightness: lightness * 100,
            alpha: alpha
        )
    }
}

public extension HSL {
    /// This colour converted back to sRGB.
    var rgba: RGBA {
        let saturation = saturation / 100
        let lightness = lightness / 100
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let sector = (hue.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) / 60
        let second = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let lift = lightness - chroma / 2

        // The hue circle is six sectors wide. In each one, one channel is at full chroma,
        // one is off, and the third ramps between them.
        let unlifted = switch sector {
        case ..<1: RGBA(red: chroma, green: second, blue: 0)
        case ..<2: RGBA(red: second, green: chroma, blue: 0)
        case ..<3: RGBA(red: 0, green: chroma, blue: second)
        case ..<4: RGBA(red: 0, green: second, blue: chroma)
        case ..<5: RGBA(red: second, green: 0, blue: chroma)
        default: RGBA(red: chroma, green: 0, blue: second)
        }

        return RGBA(
            red: unlifted.red + lift,
            green: unlifted.green + lift,
            blue: unlifted.blue + lift,
            alpha: alpha
        )
    }

    /// This colour with its lightness replaced.
    ///
    /// - Parameter lightness: The new lightness, as a percentage. Clamped to `0...100`.
    /// - Returns: A colour of the same hue and saturation at the given lightness.
    func withLightness(_ lightness: Double) -> HSL {
        HSL(hue: hue, saturation: saturation, lightness: min(100, max(0, lightness)), alpha: alpha)
    }
}
