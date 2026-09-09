import SwiftUI

/// Every component the library ships, grouped as rareui.com groups them.
///
/// The sections are declared up front and fill in as components land, so the shape of
/// the catalog matches the shape of the website from the first commit rather than
/// being rearranged as the port progresses.
///
/// Main actor isolated because an entry carries a view builder, which is not Sendable
/// and has no business leaving the main actor in the first place.
@MainActor
let catalog: [CatalogSection] = [
    CatalogSection("Display", entries: [
        animatedCounterEntry,
        folderEntry,
        gitHubActivityEntry,
        gravityLettersEntry,
        stepPlayerEntry
    ]),
    CatalogSection("AI Kit", entries: [
        fluidOrbEntry,
        matrixOrbEntry
    ]),
    CatalogSection("Navigation", entries: [
        bounceSidebarEntry,
        hookSidebarEntry,
        gooeyNavEntry,
        proximitySidebarEntry,
        scrollProgressEntry
    ]),
    CatalogSection("Inputs", entries: [
        deleteButtonEntry,
        durationPickerEntry,
        otpInputEntry
    ]),
    CatalogSection("Feedback", entries: [
        emojiReactionEntry,
        notificationBellEntry
    ])
]

/// Every entry in the catalog, flattened, for lookup by identifier.
@MainActor
let catalogEntries: [CatalogEntry] = catalog.flatMap(\.entries)
