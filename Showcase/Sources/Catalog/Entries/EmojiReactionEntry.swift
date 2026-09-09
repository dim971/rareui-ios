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
        ) { EmojiReactionSizes() },

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

/// Three of them across a row.
///
/// A named view rather than an inline HStack, because Swift 6.1.2 crashes lowering three
/// of these inside one view builder closure. It is a compiler bug rather than a mistake
/// here, and giving the closure a name is enough to walk around it.
private struct EmojiReactionSizes: View {
    var body: some View {
        HStack {
            EmojiReaction(size: .small, align: .leading)
            Spacer()
            EmojiReaction(size: .medium)
            Spacer()
            EmojiReaction(size: .large, align: .trailing)
        }
    }
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
