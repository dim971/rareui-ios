//
//  DynamicColor.swift
//  Upstream writes every surface twice, as `bg-[#F4F4F9] dark:bg-[#262626]`. The
//  pair is the unit worth carrying across, so this file builds a single SwiftUI
//  Color that resolves itself from the current appearance rather than asking every
//  component to branch on the colour scheme.
//

import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public extension Color {
    /// A colour that resolves to `light` or `dark` depending on the current appearance.
    ///
    /// This resolves inside a `Canvas` as well as in the view tree, which matters
    /// because several of these components draw rather than lay out.
    ///
    /// - Parameters:
    ///   - light: The colour to use in a light appearance.
    ///   - dark: The colour to use in a dark appearance.
    static func rareUI(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            })
        #elseif canImport(AppKit)
            Color(NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    ? NSColor(dark)
                    : NSColor(light)
            })
        #else
            light
        #endif
    }

    /// A colour read from a CSS style hex string, the form every upstream constant is written in.
    ///
    /// Accepts `RGB`, `RGBA`, `RRGGBB` and `RRGGBBAA`, with or without a leading `#`.
    /// Anything else resolves to clear, which is deliberate: a typo in a constant should
    /// be visible on screen rather than silently become black.
    ///
    /// - Parameter hex: The hex string, for example `"#F4F4F9"`.
    init(hex: String) {
        guard let rgba = RGBA(hex: hex) else {
            self = .clear
            return
        }
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    /// A pair of hex strings resolved as a light and dark appearance.
    ///
    /// - Parameters:
    ///   - light: The light appearance hex, for example `"#F4F4F9"`.
    ///   - dark: The dark appearance hex, for example `"#262626"`.
    static func rareUI(light: String, dark: String) -> Color {
        .rareUI(light: Color(hex: light), dark: Color(hex: dark))
    }
}
