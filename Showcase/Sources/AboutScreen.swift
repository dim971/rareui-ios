import RareUI
import SwiftUI

/// Where this came from, and who it belongs to.
struct AboutScreen: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Rare UI for SwiftUI")
                            .font(.title2.weight(.semibold))
                        Text(
                            """
                            A SwiftUI port of Rare UI, the animated component registry \
                            by Swami Malode. The components, their look and their motion \
                            are his work; this is a transcription of them.
                            """
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("Links") {
                    Link("rareui.com", destination: URL(string: "https://www.rareui.com")!)
                    Link(
                        "swamimalode07/rare-ui",
                        destination: URL(string: "https://github.com/swamimalode07/rare-ui")!
                    )
                    Link(
                        "dim971/rareui-ios",
                        destination: URL(string: "https://github.com/dim971/rareui-ios")!
                    )
                    Link(
                        "dim971/rareui-android",
                        destination: URL(string: "https://github.com/dim971/rareui-android")!
                    )
                }

                Section("Licence") {
                    Text("Both this port and upstream Rare UI are MIT licensed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Library", value: RareUI.version)
                }
            }
            .navigationTitle("About")
        }
    }
}
