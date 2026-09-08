//
//  ProximitySidebar.swift
//  A port of upstream's `components/ui/proximity-sidebar.tsx`.
//
//  A minimap of a page, drawn as a column of dashes, where the dash nearest the pointer
//  swells and its neighbours swell a little less. It is a document outline you read with
//  the cursor rather than with your eyes.
//
//  A phone has no pointer, and upstream already knows it: alongside the proximity effect
//  it swells the dash for whichever section is being read. That is the behaviour on touch,
//  and the proximity effect appears when a pointer does, on a Mac or an iPad with a
//  trackpad. Recorded in docs/fidelity.md.
//

import SwiftUI

/// How prominent a section is in the outline.
public enum ProximitySectionKind: String, Sendable, CaseIterable {
    /// The page's own title.
    case title
    /// A heading under it.
    case subtitle
    /// A heading under that.
    case section
    /// Anything below.
    case body

    /// The dash's width at rest, in points.
    var base: Double {
        switch self {
        case .title: 40
        case .subtitle: 36
        case .section: 30
        case .body: 24
        }
    }

    /// How much wider it gets when the pointer is on it.
    var bump: Double {
        switch self {
        case .title: 70
        case .subtitle: 64
        case .section: 56
        case .body: 50
        }
    }

    /// Whether the dash is drawn at full strength or muted.
    var isProminent: Bool {
        self == .title || self == .subtitle
    }
}

/// One entry in a ``ProximitySidebar``.
public struct ProximitySection: Identifiable, Hashable, Sendable {
    /// The section's identifier, which is what a selection reports back.
    public let id: String
    /// The name, read out by VoiceOver since the dash itself carries no text.
    public let label: String
    /// How prominent it is.
    public let kind: ProximitySectionKind

    /// Creates a section.
    ///
    /// - Parameters:
    ///   - id: The section's identifier.
    ///   - label: The name for VoiceOver.
    ///   - kind: How prominent it is. Defaults to ``ProximitySectionKind/body``.
    public init(id: String, label: String, kind: ProximitySectionKind = .body) {
        self.id = id
        self.label = label
        self.kind = kind
    }
}

/// Which side of the page the outline sits on.
public enum ProximitySidebarSide: String, Sendable, CaseIterable {
    /// On the left, growing rightward.
    case leading
    /// On the right, growing leftward.
    case trailing
}

/// How far from a dash the pointer still reaches it, in points.
let proximityRadius = 40.0
/// The width every dash is measured against, so they scale rather than resize.
let proximityMaxDashWidth = 110.0

/// How wide a dash should be, given how far the pointer is from it.
///
/// Upstream maps the distance over `[-radius, 0, radius]` to `[base, base + bump, base]`
/// and clamps outside that, so a dash is at rest until the pointer comes within reach and
/// then swells smoothly to its full width as the pointer arrives on it.
///
/// - Parameters:
///   - distance: How far the pointer is from the dash's middle. Sign does not matter.
///   - kind: The dash's kind, which sets both ends of the range.
/// - Returns: The width, in points.
func proximityDashWidth(distance: Double, kind: ProximitySectionKind) -> Double {
    let reach = min(1, abs(distance) / proximityRadius)
    return kind.base + kind.bump * (1 - reach)
}

/// A page outline drawn as dashes, which swell as the pointer passes them.
///
/// ```swift
/// ProximitySidebar(sections: outline, selection: $section) { id in
///     proxy.scrollTo(id, anchor: .top)
/// }
/// ```
///
/// Under Reduce Motion the dashes change width without springing.
public struct ProximitySidebar: View {
    private let sections: [ProximitySection]
    private let side: ProximitySidebarSide
    @Binding private var selection: String?
    private let onSelect: ((String) -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var centres = RareUIRowCentres()
    @State private var pointerY: Double?

    /// The space between two dashes, in points.
    private static var spacing: Double {
        8
    }

    /// The spring that smooths the swelling, from upstream's own.
    private static var settle: Animation {
        .rareUISpring(stiffness: 320, damping: 34, mass: 0.7)
    }

    /// Creates an outline.
    ///
    /// - Parameters:
    ///   - sections: The page's sections, in order.
    ///   - side: Which side of the page it sits on.
    ///   - selection: The section being read, which is the one that swells when there is
    ///     no pointer.
    ///   - onSelect: Called when a dash is tapped, so the host can scroll to it.
    public init(
        sections: [ProximitySection],
        side: ProximitySidebarSide = .leading,
        selection: Binding<String?> = .constant(nil),
        onSelect: ((String) -> Void)? = nil
    ) {
        self.sections = sections
        self.side = side
        _selection = selection
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: Self.spacing) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                dash(section, at: index)
                    .rareUIMeasureRow(index, into: centres)
            }
        }
        .frame(width: proximityMaxDashWidth, alignment: frameAlignment)
        .rareUIRowSpace()
        .contentShape(.rect)
        .onContinuousHover(coordinateSpace: .named(rareUIRowSpaceName)) { phase in
            switch phase {
            case let .active(location): pointerY = location.y
            case .ended: pointerY = nil
            }
        }
        .onChange(of: sections.count) { _, count in centres.trim(to: count) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Page outline")
    }

    private func dash(_ section: ProximitySection, at index: Int) -> some View {
        Rectangle()
            .fill(section.kind.isProminent ? theme.foreground : theme.glyph.opacity(0.4))
            .frame(width: width(for: section, at: index), height: 1)
            .frame(height: 8, alignment: .center)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .contentShape(.rect)
            .onTapGesture {
                selection = section.id
                onSelect?(section.id)
            }
            .animation(reduceMotion ? nil : Self.settle, value: pointerY)
            .animation(reduceMotion ? nil : Self.settle, value: selection)
            .accessibilityLabel(section.label)
            .accessibilityAddTraits(section.id == selection ? [.isButton, .isSelected] : .isButton)
    }

    private func width(for section: ProximitySection, at index: Int) -> Double {
        guard let pointerY else {
            // No pointer to follow, so the dash for whatever is being read swells instead.
            // A phone never sees the proximity effect at all, and upstream is the same.
            return section.id == selection
                ? section.kind.base + section.kind.bump
                : section.kind.base
        }
        guard let centre = centres[index] else { return section.kind.base }
        return proximityDashWidth(distance: pointerY - centre, kind: section.kind)
    }

    private var alignment: HorizontalAlignment {
        side == .leading ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        side == .leading ? .leading : .trailing
    }
}
