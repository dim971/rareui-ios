import SwiftUI

/// One demo on a component's screen: a live sample and the code behind it.
struct Demo: Identifiable {
    let id: String
    let title: String
    var note: String?
    let sample: () -> AnyView
    let code: String

    init(
        _ title: String,
        note: String? = nil,
        code: String,
        @ViewBuilder sample: @escaping () -> some View
    ) {
        id = title
        self.title = title
        self.note = note
        self.code = code
        self.sample = { AnyView(sample()) }
    }
}

/// One component in the catalog.
///
/// Adding a component means adding one of these under `Catalog/Entries` and listing it
/// in `catalog`. The home list, the detail screen and the screenshots all read from
/// that one place.
struct CatalogEntry: Identifiable {
    let id: String
    let name: String
    let summary: String
    let preview: () -> AnyView
    let demos: [Demo]

    init(
        _ name: String,
        summary: String,
        demos: [Demo],
        @ViewBuilder preview: @escaping () -> some View
    ) {
        id = name
        self.name = name
        self.summary = summary
        self.demos = demos
        self.preview = { AnyView(preview()) }
    }
}

/// A group of components, named the way rareui.com groups them.
///
/// Keeping upstream's grouping means someone arriving from the website finds a
/// component where they expect it to be, rather than where a Swift author would
/// have filed it.
struct CatalogSection: Identifiable {
    let id: String
    let name: String
    let entries: [CatalogEntry]

    init(_ name: String, entries: [CatalogEntry]) {
        id = name
        self.name = name
        self.entries = entries
    }
}
