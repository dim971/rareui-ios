import RareUI
import SwiftUI

/// Every component, each row showing the real thing rather than a screenshot.
struct CatalogHomeScreen: View {
    @Environment(ShowcaseSettings.self) private var settings

    @State private var path = ShowcaseLaunch.initialPath

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    AccentControls()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                ForEach(catalog) { section in
                    if !section.entries.isEmpty {
                        Section(section.name) {
                            ForEach(section.entries) { entry in
                                NavigationLink(value: entry.id) {
                                    row(entry)
                                }
                            }
                        }
                    }
                }

                if catalogEntries.isEmpty {
                    Section {
                        Text("No components yet. They land one at a time.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Rare UI")
            .navigationDestination(for: String.self) { id in
                if let entry = catalogEntries.first(where: { $0.id == id }) {
                    ComponentScreen(entry: entry)
                }
            }
        }
    }

    private func row(_ entry: CatalogEntry) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body.weight(.medium))
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            entry.preview()
                .rareUITheme(settings.theme)
                .frame(maxWidth: 110, alignment: .trailing)
                // A row is a navigation target, not a playground. The live preview is
                // there to be recognised, and a component that swallowed the tap would
                // make the row unreachable.
                .allowsHitTesting(false)
        }
        .padding(.vertical, 6)
    }
}
