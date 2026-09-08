import RareUI
import SwiftUI

@MainActor
let emojiReactionEntry = CatalogEntry(
    "Emoji Reaction",
    summary: "A bar of emoji, and copies of the one you pick drifting up the screen.",
    demos: [
        Demo(
            "Pick one",
            note: """
            Five copies leave a quarter of a second apart, each with its own lane, tilt, \
            blur and pace. Holding one down keeps sending them, a little over twice a second.
            """,
            code: """
            EmojiReaction { emoji in
                post(reaction: emoji)
            }
            """
        ) { EmojiReactionDemo() },

        Demo(
            "Alignment and size",
            note: "The bar lines up with whichever edge of the trigger you name.",
            code: """
            EmojiReaction(size: .large, align: .leading)
            """
        ) {
            HStack {
                EmojiReaction(size: .small, align: .leading)
                Spacer()
                EmojiReaction(size: .medium)
                Spacer()
                EmojiReaction(size: .large, align: .trailing)
            }
        },

        Demo(
            "Your own emoji",
            code: """
            EmojiReaction(emojis: ["🔥", "💯", "🎉"])
            """
        ) {
            EmojiReactionDemo(emojis: ["\u{1F525}", "\u{1F4AF}", "\u{1F389}", "\u{1F440}"])
        }
    ]
) {
    EmojiReaction(size: .small)
}

private struct EmojiReactionDemo: View {
    var emojis: [String] = EmojiReaction.defaultEmojis

    @State private var reactions: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            Spacer().frame(height: 60)
            HStack(spacing: 16) {
                EmojiReaction(emojis: emojis, align: .leading) { reactions.append($0) }
                Text(reactions.isEmpty ? "No reactions yet" : reactions.suffix(12).joined())
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
