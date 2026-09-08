//
//  ColourTests.swift
//  The colour conversions are the one piece of the theme that can be wrong quietly:
//  a hue that drifts by a degree is invisible on its own and obvious once CodeBlock
//  has built nine tones out of it.
//

@testable import RareUI
import Testing

@Suite("Hex parsing")
struct HexParsingTests {
    @Test("the six digit form parses, with or without its hash")
    func sixDigits() throws {
        let withHash = try #require(RGBA(hex: "#F4F4F9"))
        let without = try #require(RGBA(hex: "F4F4F9"))
        #expect(withHash == without)
        #expect(abs(withHash.red - 244.0 / 255) < 1e-12)
        #expect(abs(withHash.green - 244.0 / 255) < 1e-12)
        #expect(abs(withHash.blue - 249.0 / 255) < 1e-12)
        #expect(withHash.alpha == 1)
    }

    @Test("the three digit form repeats each digit, so #f80 is #ff8800")
    func threeDigits() throws {
        #expect(try #require(RGBA(hex: "#f80")) == #require(RGBA(hex: "#ff8800")))
    }

    @Test("the eight digit form carries alpha")
    func eightDigits() throws {
        let colour = try #require(RGBA(hex: "#FFFFFF14"))
        #expect(colour.red == 1)
        #expect(abs(colour.alpha - 20.0 / 255) < 1e-12)
    }

    @Test("a string that is not a colour parses as nothing rather than as black")
    func rejected() {
        #expect(RGBA(hex: "#GGGGGG") == nil)
        #expect(RGBA(hex: "#FFFFF") == nil)
        #expect(RGBA(hex: "") == nil)
        #expect(RGBA(hex: "rebeccapurple") == nil)
    }
}

@Suite("HSL conversion")
struct HSLConversionTests {
    @Test("the primaries land on the hues they are named after")
    func primaries() throws {
        let red = try #require(RGBA(hex: "#FF0000")).hsl
        #expect(red.hue == 0)
        #expect(red.saturation == 100)
        #expect(red.lightness == 50)

        let green = try #require(RGBA(hex: "#00FF00")).hsl
        #expect(abs(green.hue - 120) < 1e-9)

        let blue = try #require(RGBA(hex: "#0000FF")).hsl
        #expect(abs(blue.hue - 240) < 1e-9)
    }

    @Test("a grey has no hue and no saturation to lose")
    func grey() throws {
        let grey = try #require(RGBA(hex: "#808080")).hsl
        #expect(grey.saturation == 0)
        #expect(grey.hue == 0)
    }

    @Test("round tripping a colour through HSL returns it unchanged")
    func roundTrip() throws {
        // The accent, the matrix orb's orange and the code block's default, which are the
        // three the derived palettes are actually built from.
        for hex in ["#FC4C01", "#F75001", "#39D353", "#1A73F2", "#F4F4F9", "#262626"] {
            let original = try #require(RGBA(hex: hex))
            let returned = original.hsl.rgba
            #expect(abs(original.red - returned.red) < 1e-9, "red drifted for \(hex)")
            #expect(abs(original.green - returned.green) < 1e-9, "green drifted for \(hex)")
            #expect(abs(original.blue - returned.blue) < 1e-9, "blue drifted for \(hex)")
        }
    }

    @Test("replacing lightness keeps the hue and clamps to the range")
    func lightness() throws {
        let accent = try #require(RGBA(hex: "#FC4C01")).hsl
        let lifted = accent.withLightness(70)
        #expect(lifted.hue == accent.hue)
        #expect(lifted.saturation == accent.saturation)
        #expect(lifted.lightness == 70)
        #expect(accent.withLightness(140).lightness == 100)
        #expect(accent.withLightness(-20).lightness == 0)
    }
}

@Suite("Cubic bezier easing")
struct CubicBezierTests {
    @Test("every curve starts at nothing and finishes at everything")
    func endpoints() {
        for curve in [
            RareUIMotion.easeOutQuint,
            RareUIMotion.easeOutSettle,
            RareUIMotion.easeOutOvershoot,
            RareUIMotion.easeOutLanding,
            RareUIMotion.easeInOut,
            RareUIMotion.easeParticle
        ] {
            #expect(curve(0) == 0)
            #expect(curve(1) == 1)
        }
    }

    @Test("the diagonal curve is the identity")
    func linear() {
        let linear = CubicBezier(0.25, 0.25, 0.75, 0.75)
        for step in 0 ... 10 {
            let t = Double(step) / 10
            #expect(abs(linear(t) - t) < 1e-6)
        }
    }

    @Test("an ease out is ahead of linear the whole way")
    func easeOutLeadsLinear() {
        for step in 1 ..< 10 {
            let t = Double(step) / 10
            #expect(RareUIMotion.easeOutQuint(t) > t)
        }
    }

    @Test("the bin lid's curve overshoots, which is the point of it")
    func overshoot() {
        // cubic-bezier(0.34, 1.1, 0.64, 1) puts its first control point above 1, so the
        // lid passes its open angle before settling back onto it.
        let peak = stride(from: 0.0, through: 1.0, by: 0.01)
            .map { RareUIMotion.easeOutOvershoot($0) }
            .max() ?? 0
        #expect(peak > 1)
    }

    @Test("progress outside the unit interval is clamped rather than extrapolated")
    func clamping() {
        #expect(RareUIMotion.easeOutQuint(-1) == 0)
        #expect(RareUIMotion.easeOutQuint(2) == 1)
    }
}
