//
//  RareUITheme.swift
//  Upstream hardcodes its palette inside each component, as Tailwind classes: the same
//  `bg-[#F4F4F9] dark:bg-[#262626]` appears in a dozen files. Those values are collected
//  here once so a host application can restyle the set without forking a component, while
//  the defaults stay exactly what the originals use.
//

import SwiftUI

/// The colours the components draw themselves in.
///
/// Every default is the value the matching upstream component hardcodes, so a view left
/// untouched looks like its counterpart on rareui.com. Override what you need through
/// ``SwiftUICore/View/rareUITheme(_:)``; the theme travels down the environment the way
/// upstream's CSS custom properties cascade.
public struct RareUITheme: Sendable {
    /// The raised surface almost every component sits on. `#F4F4F9` light, `#262626` dark.
    public var surface: Color

    /// The recessed surface a raised control sinks into, as in the delete button's panel.
    /// `#E7E7EF` light, `#1B1B1B` dark.
    public var surfaceRecessed: Color

    /// The page behind the components. White light, `#0A0A0A` dark.
    public var background: Color

    /// Text and icons at full strength. `#0A0A0A` light, `#FAFAFA` dark.
    public var foreground: Color

    /// The muted grey upstream draws inactive glyphs and labels in.
    /// `#868593` light, `#9B9AA7` dark.
    public var glyph: Color

    /// Hairline borders. Black and white at 8%, matching upstream's `rgb(255 255 255 / 0.08)`.
    public var border: Color

    /// The brand accent. `#FC4C01`, the orange the navigation and sidebar components mark
    /// their selection with.
    public var accent: Color

    /// The filled part of a track, as in the step player. `#3C3C43` light, `#EBEBF5` dark.
    public var track: Color

    /// The system red, used for destructive state and validation failure.
    public var red: Color

    /// The system orange.
    public var orange: Color

    /// The system green, used for validation success.
    public var green: Color

    /// The system blue.
    public var blue: Color

    /// The system violet.
    public var violet: Color

    /// Creates a theme. Every parameter defaults to the value upstream uses.
    ///
    /// - Parameters:
    ///   - surface: The raised surface.
    ///   - surfaceRecessed: The recessed surface.
    ///   - background: The page behind the components.
    ///   - foreground: Text and icons at full strength.
    ///   - glyph: The muted grey for inactive glyphs and labels.
    ///   - border: Hairline borders.
    ///   - accent: The brand accent.
    ///   - track: The filled part of a track.
    ///   - red: The system red.
    ///   - orange: The system orange.
    ///   - green: The system green.
    ///   - blue: The system blue.
    ///   - violet: The system violet.
    public init(
        surface: Color = .rareUI(light: "#F4F4F9", dark: "#262626"),
        surfaceRecessed: Color = .rareUI(light: "#E7E7EF", dark: "#1B1B1B"),
        background: Color = .rareUI(light: "#FFFFFF", dark: "#0A0A0A"),
        foreground: Color = .rareUI(light: "#0A0A0A", dark: "#FAFAFA"),
        glyph: Color = .rareUI(light: "#868593", dark: "#9B9AA7"),
        border: Color = .rareUI(light: "#0000000D", dark: "#FFFFFF14"),
        accent: Color = Color(hex: "#FC4C01"),
        track: Color = .rareUI(light: "#3C3C43", dark: "#EBEBF5"),
        // The five below are Apple's system colours, which is not a coincidence: upstream
        // reaches for the iOS palette by hex in its inputs and its notification badge.
        red: Color = .rareUI(light: "#FF3B30", dark: "#FF453A"),
        orange: Color = .rareUI(light: "#FF9500", dark: "#FF9F0A"),
        green: Color = .rareUI(light: "#34C759", dark: "#30D158"),
        blue: Color = .rareUI(light: "#007AFF", dark: "#0A84FF"),
        violet: Color = .rareUI(light: "#AF52DE", dark: "#BF5AF2")
    ) {
        self.surface = surface
        self.surfaceRecessed = surfaceRecessed
        self.background = background
        self.foreground = foreground
        self.glyph = glyph
        self.border = border
        self.accent = accent
        self.track = track
        self.red = red
        self.orange = orange
        self.green = green
        self.blue = blue
        self.violet = violet
    }
}

public extension EnvironmentValues {
    /// The theme the Rare UI components in this subtree draw themselves with.
    @Entry var rareUITheme: RareUITheme = .init()
}

public extension View {
    /// Adjusts the theme for this view and everything inside it.
    ///
    /// The closure receives the theme inherited from above, so an override is additive
    /// and a view nested inside another override keeps the outer one's changes:
    ///
    /// ```swift
    /// VStack { ... }
    ///     .rareUITheme { theme in
    ///         theme.accent = .purple
    ///     }
    /// ```
    ///
    /// - Parameter adjust: A closure that modifies the inherited theme in place.
    /// - Returns: A view whose subtree uses the adjusted theme.
    func rareUITheme(_ adjust: @escaping (inout RareUITheme) -> Void) -> some View {
        transformEnvironment(\.rareUITheme, transform: adjust)
    }

    /// Replaces the theme for this view and everything inside it.
    ///
    /// - Parameter theme: The theme to use.
    /// - Returns: A view whose subtree uses the given theme.
    func rareUITheme(_ theme: RareUITheme) -> some View {
        environment(\.rareUITheme, theme)
    }
}
