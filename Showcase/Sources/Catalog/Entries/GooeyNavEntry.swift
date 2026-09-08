import RareUI
import SwiftUI

@MainActor
let gooeyNavEntry = CatalogEntry(
    "Gooey Nav",
    summary: "A segmented bar whose selected tile detaches, stretching the seams until they part.",
    demos: [
        Demo(
            "Pick a tile",
            note: """
            The seam is a drawn pair of curves, not a blur filter. It pinches to a waist \
            and breaks once the gap passes 22% of the separation.
            """,
            code: """
            GooeyNav(items: ["Home", "Docs", "Pricing"], selection: $tab)
            """
        ) { GooeyNavDemo(items: ["Home", "Docs", "Pricing"]) },

        Demo(
            "With icons",
            code: """
            GooeyNav(
                items: [
                    GooeyNavItem("Inbox", systemImage: "tray"),
                    GooeyNavItem("Sent", systemImage: "paperplane"),
                ],
                selection: $tab
            )
            """
        ) {
            GooeyNavDemo(items: [
                GooeyNavItem("Inbox", systemImage: "tray"),
                GooeyNavItem("Sent", systemImage: "paperplane"),
                GooeyNavItem("Drafts", systemImage: "doc")
            ])
        },

        Demo(
            "Sizes",
            note: "Padding, type size, corner radius and separation all follow the size.",
            code: """
            GooeyNav(items: items, selection: $tab, size: .small)
            """
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(GooeyNavSize.allCases, id: \.self) { size in
                    GooeyNavDemo(items: ["One", "Two", "Three"], size: size)
                }
            }
        },

        Demo(
            "A wider pull",
            note: """
            A larger separation stretches the seam further before it breaks, since the break \
            is a fraction of it.
            """,
            code: """
            GooeyNav(items: items, selection: $tab, separation: 44)
            """
        ) { GooeyNavDemo(items: ["Left", "Middle", "Right"], separation: 44) }
    ]
) {
    GooeyNav(items: ["A", "B"], defaultSelection: 0, size: .extraSmall)
}

private struct GooeyNavDemo: View {
    let items: [GooeyNavItem]
    var size: GooeyNavSize = .medium
    var separation: Double?

    @State private var tab = 0

    var body: some View {
        GooeyNav(items: items, selection: $tab, size: size, separation: separation)
    }
}
