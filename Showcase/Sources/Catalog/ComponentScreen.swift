import RareUI
import SwiftUI

/// One component: what it is, every variant of it live, and the code for each.
struct ComponentScreen: View {
    let entry: CatalogEntry

    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(entry.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if reduceMotion {
                    Label(
                        "Reduce Motion is on, so these settle instead of animating.",
                        systemImage: "figure.walk.motion"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                AccentControls()
                    .padding(.horizontal, -16)

                ForEach(entry.demos) { demo in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(demo.title)
                            .font(.subheadline.weight(.semibold))
                        if let note = demo.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        demo.sample()
                            .rareUITheme(settings.theme)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.quaternary)
                            )
                        CodeSnippet(code: demo.code)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}
