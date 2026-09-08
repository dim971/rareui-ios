import RareUI
import SwiftUI

@MainActor
let proximitySidebarEntry = CatalogEntry(
    "Proximity Sidebar",
    summary: "A page outline drawn as dashes, which swell as a pointer passes them.",
    demos: [
        Demo(
            "The outline",
            note: """
            A phone has no pointer, so the dash for whatever is being read swells instead. \
            Move a trackpad cursor over it on a Mac or an iPad and the dashes follow it.
            """,
            code: """
            ProximitySidebar(sections: outline, selection: $section) { id in
                proxy.scrollTo(id, anchor: .top)
            }
            """
        ) { ProximityDemo() },

        Demo(
            "On the right",
            note: "The dashes grow from whichever edge they are anchored to.",
            code: """
            ProximitySidebar(sections: outline, side: .trailing, selection: $section)
            """
        ) { ProximityDemo(side: .trailing) }
    ]
) {
    ProximitySidebar(
        sections: [
            ProximitySection(id: "a", label: "Title", kind: .title),
            ProximitySection(id: "b", label: "Body"),
            ProximitySection(id: "c", label: "Body")
        ],
        selection: .constant("a")
    )
    .frame(width: 110)
}

private struct ProximityDemo: View {
    var side: ProximitySidebarSide = .leading

    private let sections = [
        ProximitySection(id: "title", label: "Rare UI", kind: .title),
        ProximitySection(id: "install", label: "Installing", kind: .subtitle),
        ProximitySection(id: "spm", label: "Swift Package Manager", kind: .section),
        ProximitySection(id: "xcode", label: "In Xcode", kind: .body),
        ProximitySection(id: "theme", label: "Theming", kind: .subtitle),
        ProximitySection(id: "colours", label: "Colours", kind: .section),
        ProximitySection(id: "motion", label: "Motion", kind: .body)
    ]

    @State private var selection: String? = "title"

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            if side == .trailing { detail }
            ProximitySidebar(sections: sections, side: side, selection: $selection) { _ in }
            if side == .leading { detail }
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sections.first { $0.id == selection }?.label ?? "")
                .font(.headline)
            Text("Tap a dash to pick a section.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
