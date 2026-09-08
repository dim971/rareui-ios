import RareUI
import SwiftUI

@MainActor
let deleteButtonEntry = CatalogEntry(
    "Delete Button",
    summary: "A bin that opens into its own confirmation rather than into a dialogue.",
    demos: [
        Demo(
            "Ask first",
            note: """
            The lid swings back past its open angle before settling, and the walls redraw \
            shorter as it goes, so the bin appears to sink while the lid lifts clear of it.
            """,
            code: """
            DeleteButton {
                remove(item)
            }
            """
        ) { DeleteButtonDemo() },

        Demo(
            "In a row",
            note: "The button widens in place, so whatever is beside it moves out of the way.",
            code: """
            HStack {
                Text("Draft")
                Spacer()
                DeleteButton { remove(draft) }
            }
            """
        ) {
            VStack(spacing: 12) {
                ForEach(["Draft", "Archive", "Backup"], id: \.self) { name in
                    HStack {
                        Text(name)
                        Spacer()
                        DeleteButton()
                    }
                }
            }
        }
    ]
) {
    DeleteButton()
}

private struct DeleteButtonDemo: View {
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeleteButton {
                log.append("kept")
            } onConfirm: {
                log.append("deleted")
            }

            Text(log.isEmpty ? "Nothing yet" : log.suffix(6).joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
