import RareUI
import SwiftUI

/// The knobs the catalog puts in the reader's hands.
///
/// Most of these components take an accent colour, and most of the interesting
/// questions about them are questions about how they look in someone else's palette.
/// Rather than hardcode the demo colours, the whole catalog draws through this.
@Observable
final class ShowcaseSettings {
    /// The accent every component in the catalog is tinted with.
    var accent: Color = .init(hex: "#FC4C01")

    /// The accent choices offered in the controls. The first is upstream's own.
    static let accents: [(name: String, colour: Color)] = [
        ("Rare", Color(hex: "#FC4C01")),
        ("Ember", Color(hex: "#F75001")),
        ("Grass", Color(hex: "#39D353")),
        ("Sky", Color(hex: "#1A73F2")),
        ("Violet", Color(hex: "#AF52DE"))
    ]

    /// The theme the catalog hands down to every sample.
    var theme: RareUITheme {
        RareUITheme(accent: accent)
    }
}
