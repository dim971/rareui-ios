import RareUI
import SwiftUI

@MainActor
let folderEntry = CatalogEntry(
    "Folder Component",
    summary: "A folder whose flap tips back and whose contents fan out of it.",
    demos: [
        Demo(
            "Open it",
            note: """
            There are three states, not two: at rest, under a pointer, and open. A phone \
            only ever reaches the first and the last, which is what a tap toggles between.
            """,
            code: """
            FolderComponent(color: .black)
            """
        ) { FolderComponent(color: .black, size: .small) },

        Demo(
            "Three folders",
            note: """
            Each colour is a complete set rather than a tint: the black folder holds pale \
            cards, the white one holds dark cards.
            """,
            code: """
            FolderComponent(color: .white)
            FolderComponent(color: .blue)
            """
        ) {
            VStack(spacing: 20) {
                FolderComponent(color: .white, size: .small)
                FolderComponent(color: .blue, size: .small)
            }
        }
    ]
) {
    FolderComponent(color: .black, size: .small)
        .scaleEffect(0.32)
        .frame(width: 70, height: 58)
}
