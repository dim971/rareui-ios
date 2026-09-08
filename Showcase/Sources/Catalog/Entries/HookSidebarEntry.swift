import RareUI
import SwiftUI

@MainActor
let hookSidebarEntry = CatalogEntry(
    "Hook Sidebar",
    summary: "A rail down the gutter that stops at the current row and hooks into it.",
    demos: [
        Demo(
            "Pick a row",
            note: """
            The rail stops a corner short of the row and the hook covers the last stretch, \
            turning out toward the label.
            """,
            code: """
            HookSidebar(items: ["Overview", "Install", "Theming"], selection: $section)
            """
        ) {
            HookSidebarDemo(items: ["Overview", "Installation", "Theming", "Motion", "Licence"])
        },

        Demo(
            "Solid rather than dashed",
            code: """
            HookSidebar(items: items, selection: $section, dashed: false)
            """
        ) {
            HookSidebarDemo(items: ["Overview", "Installation", "Theming"], dashed: false)
        },

        Demo(
            "With a heading",
            note: """
            A second, fainter rail follows a pointer or the keyboard focus. It appears on a \
            Mac or an iPad with a trackpad, and never on a phone, which has no pointer to \
            follow. Upstream behaves the same way.
            """,
            code: """
            HookSidebar(items: items, selection: $section, label: "Docs")
            """
        ) {
            HookSidebarDemo(items: ["Overview", "Installation", "Theming"], label: "Docs")
        }
    ]
) {
    HookSidebar(items: ["One", "Two"], defaultSelection: 1)
        .frame(width: 100)
}

private struct HookSidebarDemo: View {
    let items: [HookSidebarItem]
    var dashed = true
    var label: String?

    @State private var section = 0

    var body: some View {
        HookSidebar(items: items, selection: $section, label: label, dashed: dashed)
            .frame(maxWidth: 260, alignment: .leading)
    }
}
