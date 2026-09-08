import RareUI
import SwiftUI

@MainActor
let scrollProgressEntry = CatalogEntry(
    "Scroll Progress",
    summary: "A floating pill showing how far down you are, which opens into the page's sections.",
    demos: [
        Demo(
            "Scroll the panel",
            note: """
            The ring follows a spring rather than the scroll itself, so a flick does not \
            make it jump. Tapping the pill opens it into the sections, and the highlight \
            travels between them rather than fading in and out.
            """,
            code: """
            ScrollProgress(sections: sections, progress: read, selection: $section) { id in
                proxy.scrollTo(id, anchor: .top)
            }
            """
        ) { ScrollProgressDemo() }
    ]
) {
    ScrollProgress(
        sections: [ScrollProgressSection(id: "a", label: "Reading")],
        progress: 0.4,
        selection: .constant("a")
    )
}

private struct ScrollProgressDemo: View {
    private let sections = [
        ScrollProgressSection(id: "intro", label: "Introduction"),
        ScrollProgressSection(id: "install", label: "Installing"),
        ScrollProgressSection(id: "theming", label: "Theming"),
        ScrollProgressSection(id: "motion", label: "Motion")
    ]

    @State private var progress = 0.0
    @State private var selection: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.label)
                                .font(.headline)
                            Text(String(repeating: "Something to read. ", count: 14))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .id(section.id)
                        .background {
                            GeometryReader { proxy in
                                let top = proxy.frame(in: .named("demo")).minY
                                Color.clear
                                    .onChange(of: top) { _, _ in
                                        if top <= 40 { selection = section.id }
                                    }
                            }
                        }
                    }
                }
                .padding(.bottom, 60)
                .background {
                    GeometryReader { inner in
                        let offset = -inner.frame(in: .named("demo")).minY
                        let span = max(1, inner.size.height - 300)
                        Color.clear
                            .onChange(of: offset) { _, moved in
                                progress = min(1, max(0, moved / span))
                            }
                    }
                }
            }
            .coordinateSpace(.named("demo"))
            .frame(height: 300)
            .overlay(alignment: .bottom) {
                ScrollProgress(sections: sections, progress: progress, selection: $selection) { id in
                    withAnimation { proxy.scrollTo(id, anchor: .top) }
                }
                .padding(.bottom, 12)
            }
            .onAppear { selection = sections.first?.id }
        }
    }
}
