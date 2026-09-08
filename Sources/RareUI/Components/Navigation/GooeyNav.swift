//
//  GooeyNav.swift
//  A port of upstream's `components/ui/gooey-nav.tsx`.
//
//  A segmented bar where the selected tile detaches from its neighbours. The seams either
//  side of it stretch and pinch until they part, which is where the name comes from, but
//  nothing here is a filter: the seam is drawn, in GooeyNeck.
//

import SwiftUI

/// One tile of a ``GooeyNav``.
///
/// A bare string is enough, so a nav can be written as
/// `GooeyNav(items: ["Home", "Docs", "Pricing"], selection: $tab)`.
public struct GooeyNavItem: Identifiable, Hashable, Sendable, ExpressibleByStringLiteral {
    /// The text on the tile.
    public let label: String
    /// An SF Symbol drawn before the label, if there is one.
    public let systemImage: String?

    public var id: String {
        systemImage.map { "\(label)-\($0)" } ?? label
    }

    /// Creates a tile.
    ///
    /// - Parameters:
    ///   - label: The text on the tile.
    ///   - systemImage: An SF Symbol to draw before it.
    public init(_ label: String, systemImage: String? = nil) {
        self.label = label
        self.systemImage = systemImage
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }
}

/// How large a ``GooeyNav`` is drawn.
public enum GooeyNavSize: String, Sendable, CaseIterable {
    /// The smallest, for a dense toolbar.
    case extraSmall
    /// Small.
    case small
    /// The default.
    case medium
    /// The largest.
    case large

    /// The horizontal padding inside a tile, in points.
    var horizontalPadding: Double {
        switch self {
        case .extraSmall: 8
        case .small: 14
        case .medium: 20
        case .large: 24
        }
    }

    /// The vertical padding inside a tile, in points.
    var verticalPadding: Double {
        switch self {
        case .extraSmall: 6
        case .small: 8
        case .medium: 10
        case .large: 12
        }
    }

    /// The space between an icon and its label, in points.
    var iconSpacing: Double {
        switch self {
        case .extraSmall: 4
        case .small: 6
        case .medium: 8
        case .large: 10
        }
    }

    /// The label's point size.
    var fontSize: Double {
        switch self {
        case .extraSmall: 11
        case .small: 12
        case .medium: 14
        case .large: 16
        }
    }

    /// The corner radius of an open corner, in points.
    var radius: Double {
        switch self {
        case .extraSmall: 8
        case .small: 10
        case .medium: 12
        case .large: 14
        }
    }

    /// How far the selected tile pulls away from its neighbours, in points.
    var separation: Double {
        switch self {
        case .extraSmall: 14
        case .small: 16
        case .medium: 20
        case .large: 24
        }
    }
}

/// A segmented bar whose selected tile detaches, stretching the seams either side of it
/// until they part.
///
/// ```swift
/// GooeyNav(items: ["Home", "Docs", "Pricing"], selection: $tab)
/// ```
///
/// Under Reduce Motion the tiles move without springing, which is what upstream does
/// under `prefers-reduced-motion`.
public struct GooeyNav: View {
    private let items: [GooeyNavItem]
    private let selection: Binding<Int>?
    private let size: GooeyNavSize
    private let activeColor: Color?
    private let activeLabelColor: Color
    private let separation: Double?
    private let radius: Double?
    private let onChange: ((Int) -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var uncontrolled: Int

    /// The spring the tiles and the seams both move on.
    ///
    /// Damped hard enough that nothing overshoots: a tile that sprang past its resting
    /// place would pull the seam back through itself.
    private static var spring: Animation {
        .rareUISpring(stiffness: 200, damping: 28, mass: 1)
    }

    /// How long the active colours take to arrive. Leaving is immediate, so the tile that
    /// is being left does not hold its colour while the new one takes it up.
    private static var fadeIn: Double {
        0.4
    }

    /// Creates a nav bound to a selection you hold.
    ///
    /// - Parameters:
    ///   - items: The tiles, in order.
    ///   - selection: The index of the selected tile.
    ///   - size: How large to draw it.
    ///   - activeColor: The selected tile's fill. Defaults to the theme's accent.
    ///   - activeLabelColor: The selected tile's label colour.
    ///   - separation: How far the selected tile pulls away, in points. Defaults to the size's own.
    ///   - radius: The corner radius, in points. Defaults to the size's own.
    public init(
        items: [GooeyNavItem],
        selection: Binding<Int>,
        size: GooeyNavSize = .medium,
        activeColor: Color? = nil,
        activeLabelColor: Color = .white,
        separation: Double? = nil,
        radius: Double? = nil
    ) {
        self.items = items
        self.selection = selection
        self.size = size
        self.activeColor = activeColor
        self.activeLabelColor = activeLabelColor
        self.separation = separation
        self.radius = radius
        onChange = nil
        _uncontrolled = State(initialValue: selection.wrappedValue)
    }

    /// Creates a nav that keeps its own selection.
    ///
    /// - Parameters:
    ///   - items: The tiles, in order.
    ///   - defaultSelection: The tile selected to begin with.
    ///   - size: How large to draw it.
    ///   - activeColor: The selected tile's fill. Defaults to the theme's accent.
    ///   - activeLabelColor: The selected tile's label colour.
    ///   - separation: How far the selected tile pulls away, in points. Defaults to the size's own.
    ///   - radius: The corner radius, in points. Defaults to the size's own.
    ///   - onChange: Called with the index of a newly selected tile.
    public init(
        items: [GooeyNavItem],
        defaultSelection: Int = 0,
        size: GooeyNavSize = .medium,
        activeColor: Color? = nil,
        activeLabelColor: Color = .white,
        separation: Double? = nil,
        radius: Double? = nil,
        onChange: ((Int) -> Void)? = nil
    ) {
        self.items = items
        selection = nil
        self.size = size
        self.activeColor = activeColor
        self.activeLabelColor = activeLabelColor
        self.separation = separation
        self.radius = radius
        self.onChange = onChange
        _uncontrolled = State(initialValue: defaultSelection)
    }

    private var active: Int {
        selection?.wrappedValue ?? uncontrolled
    }

    private var span: Double {
        separation ?? size.separation
    }

    private var corner: Double {
        radius ?? size.radius
    }

    private var fill: Color {
        activeColor ?? theme.accent
    }

    private var animation: Animation? {
        RareUIMotion.settling(Self.spring, reduceMotion: reduceMotion)
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                tile(item, at: index)
            }
        }
        // A nav is its ideal size and never compresses. Without this the row is re-proposed
        // a width on every frame while it opens, the labels re-measure against it, and the
        // tiles visibly drift as their heights disagree from one frame to the next.
        .fixedSize()
        .animation(animation, value: active)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func tile(_ item: GooeyNavItem, at index: Int) -> some View {
        let isActive = index == active

        label(item, isActive: isActive)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background {
                GooeyTile(
                    topLeading: isSeamOpen(index) ? corner : 0,
                    bottomLeading: isSeamOpen(index) ? corner : 0,
                    topTrailing: isSeamOpen(index + 1) ? corner : 0,
                    bottomTrailing: isSeamOpen(index + 1) ? corner : 0
                )
                .fill(isActive ? fill : theme.surface)
                .animation(colourAnimation(isActive: isActive), value: isActive)
            }
            .contentShape(.rect)
            .onTapGesture { select(index) }
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            .accessibilityLabel(item.label)
    }

    private func label(_ item: GooeyNavItem, isActive: Bool) -> some View {
        HStack(spacing: size.iconSpacing) {
            if let systemImage = item.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size.fontSize))
            }
            Text(item.label)
                .font(.system(size: size.fontSize, weight: .medium))
                .fixedSize()
        }
        .foregroundStyle(isActive ? activeLabelColor : theme.glyph)
        .animation(colourAnimation(isActive: isActive), value: isActive)
    }

    /// Arriving at the active colours takes 400ms; leaving them takes none.
    private func colourAnimation(isActive: Bool) -> Animation? {
        guard !reduceMotion else { return nil }
        return isActive ? .linear(duration: Self.fadeIn) : nil
    }

    /// How far tile `index` sits from the one before it.
    ///
    /// A closed seam pulls in by a point rather than sitting flush, so no hairline of the
    /// background shows through between two tiles that are meant to read as one.
    private func gapBefore(_ index: Int) -> Double {
        guard index > 0 else { return 0 }
        return isSeamOpen(index) ? span : -1
    }

    private func isSeamOpen(_ seam: Int) -> Bool {
        gooeyIsSeamOpen(seam, active: active, count: items.count)
    }

    /// The seam takes the colour of the tile on each side of it, so it reads as the two
    /// of them stretching apart rather than as a third thing between them.
    private func seamGradient(before index: Int) -> LinearGradient {
        LinearGradient(
            colors: [
                index - 1 == active ? fill : theme.surface,
                index == active ? fill : theme.surface
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func select(_ index: Int) {
        if let selection {
            selection.wrappedValue = index
        } else {
            uncontrolled = index
        }
        onChange?(index)
    }
}
