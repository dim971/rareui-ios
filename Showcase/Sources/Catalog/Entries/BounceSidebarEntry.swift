import RareUI
import SwiftUI

@MainActor
let bounceSidebarEntry = CatalogEntry(
    "Bounce Sidebar",
    summary: "A list with a dot in the gutter that arcs from one row to the next.",
    demos: [
        Demo(
            "Pick a row",
            note: """
            The dot does not travel in a straight line. It swings out to the left and back \
            in, by about the same amount whatever the distance.
            """,
            code: """
            BounceSidebar(items: ["Overview", "Install", "Theming"], selection: $section)
            """
        ) {
            BounceSidebarDemo(items: ["Overview", "Installation", "Theming", "Motion", "Licence"])
        },

        Demo(
            "With headings",
            note: "A heading takes the dot's colour and opens a gap above itself.",
            code: """
            BounceSidebar(
                items: [
                    .heading("Getting started"),
                    "Overview",
                    .heading("Reference"),
                    "Components",
                ],
                selection: $section
            )
            """
        ) {
            BounceSidebarDemo(items: [
                .heading("Getting started"),
                "Overview",
                "Installation",
                .heading("Reference"),
                "Components",
                "Theming"
            ])
        }
    ]
) {
    BounceSidebar(items: ["One", "Two"], defaultSelection: 0)
        .frame(width: 100)
}

private struct BounceSidebarDemo: View {
    let items: [BounceSidebarItem]
    @State private var section = 0

    var body: some View {
        BounceSidebar(items: items, selection: $section)
            .frame(maxWidth: 260, alignment: .leading)
    }
}
