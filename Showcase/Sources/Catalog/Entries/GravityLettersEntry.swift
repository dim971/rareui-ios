import RareUI
import SwiftUI

@MainActor
let gravityLettersEntry = CatalogEntry(
    "Gravity Letters",
    summary: "Letters that fall out of your finger and pile up.",
    demos: [
        Demo(
            "Touch to drop",
            note: """
            Hold for a third of a second and it pours; drag to steer the pour. Tilt the \
            device past ten degrees and the pile slides the way it is leaning.
            """,
            code: """
            GravityLetters()
                .frame(height: 320)
            """
        ) {
            GravityLetters()
                .frame(height: 300)
                .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        },

        Demo(
            "Your own glyphs",
            note: "Anything can fall, not only letters. A squarer glyph tumbles faster than a tall thin one.",
            code: """
            GravityLetters(items: ["★", "●", "▲"], gravity: 1400, size: 34)
            """
        ) {
            GravityLetters(
                items: ["\u{2605}", "\u{25CF}", "\u{25B2}", "\u{25A0}"],
                gravity: 1400,
                size: 34
            )
            .frame(height: 260)
            .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        },

        Demo(
            "Numbers, falling gently",
            code: """
            GravityLetters(glyphs: .numbers, gravity: 400)
            """
        ) {
            GravityLetters(glyphs: .numbers, gravity: 400, size: 24)
                .frame(height: 220)
                .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        }
    ]
) {
    GravityLettersPreview()
}

private struct GravityLettersPreview: View {
    var body: some View {
        Text("A B C")
            .font(.system(size: 15, weight: .semibold))
            .rotationEffect(.degrees(-6))
    }
}
