//
//  BounceSidebar.swift
//  A port of upstream's `components/ui/bounce-sidebar.tsx`.
//
//  A plain list of rows with a dot in the gutter marking the current one. The bounce is
//  not a spring: the dot travels along an arc, so it swings out sideways on its way from
//  one row to the next and comes back in as it arrives.
//

import SwiftUI

/// One row of a ``BounceSidebar``.
public struct BounceSidebarItem: Identifiable, Hashable, Sendable, ExpressibleByStringLiteral {
    /// The row's text.
    public let label: String
    /// Whether the row is a heading rather than something selectable.
    public let isHeading: Bool

    public var id: String {
        isHeading ? "heading-\(label)" : label
    }

    /// Creates a selectable row.
    ///
    /// - Parameter label: The row's text.
    public init(_ label: String) {
        self.label = label
        isHeading = false
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Creates a heading, which is drawn in the dot's colour and cannot be selected.
    ///
    /// - Parameter label: The heading's text.
    /// - Returns: The heading row.
    public static func heading(_ label: String) -> BounceSidebarItem {
        BounceSidebarItem(label: label, isHeading: true)
    }

    private init(label: String, isHeading: Bool) {
        self.label = label
        self.isHeading = isHeading
    }
}

/// A list of rows with a dot in the gutter that arcs from one to the next.
///
/// ```swift
/// BounceSidebar(items: ["Overview", "Install", "Theming"], selection: $section)
/// ```
///
/// Under Reduce Motion the dot moves without the arc and without a duration.
public struct BounceSidebar: View {
    private let items: [BounceSidebarItem]
    private let selection: Binding<Int>?
    private let dotColor: Color?
    private let onChange: ((Int) -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var uncontrolled: Int
    @State private var centres = RareUIRowCentres()

    /// Where the dot is, and the two ends of the arc it is travelling along.
    @State private var dotY = 0.0
    @State private var arcStart = 0.0
    @State private var arcEnd = 0.0
    @State private var dotPlaced = false
    @State private var live = RareUILiveValue()

    /// The dot's diameter, in points.
    private static var dotSize: Double {
        6
    }

    /// How long the dot takes to cross, and on what curve. Upstream animates the arc with
    /// an ease out rather than a spring, which is why it never overshoots the row.
    private static var duration: Double {
        0.25
    }

    /// Creates a sidebar bound to a selection you hold.
    ///
    /// - Parameters:
    ///   - items: The rows, in order. Use ``BounceSidebarItem/heading(_:)`` for a heading.
    ///   - selection: The index of the selected row.
    ///   - dotColor: The dot's colour, which headings also take. Defaults to the theme's accent.
    public init(items: [BounceSidebarItem], selection: Binding<Int>, dotColor: Color? = nil) {
        self.items = items
        self.selection = selection
        self.dotColor = dotColor
        onChange = nil
        _uncontrolled = State(initialValue: selection.wrappedValue)
    }

    /// Creates a sidebar that keeps its own selection.
    ///
    /// - Parameters:
    ///   - items: The rows, in order. Use ``BounceSidebarItem/heading(_:)`` for a heading.
    ///   - defaultSelection: The row selected to begin with.
    ///   - dotColor: The dot's colour, which headings also take. Defaults to the theme's accent.
    ///   - onChange: Called with the index of a newly selected row.
    public init(
        items: [BounceSidebarItem],
        defaultSelection: Int = 0,
        dotColor: Color? = nil,
        onChange: ((Int) -> Void)? = nil
    ) {
        self.items = items
        selection = nil
        self.dotColor = dotColor
        self.onChange = onChange
        _uncontrolled = State(initialValue: defaultSelection)
    }

    private var active: Int {
        selection?.wrappedValue ?? uncontrolled
    }

    private var ink: Color {
        dotColor ?? theme.accent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(item, at: index)
                    .rareUIMeasureRow(index, into: centres)
            }
        }
        .padding(.leading, 24)
        .rareUIRowSpace()
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(ink)
                .frame(width: Self.dotSize, height: Self.dotSize)
                .modifier(DotArc(y: dotY, start: arcStart, end: arcEnd, live: live))
                // Nothing to point at until the rows have been measured, and a dot parked
                // at the top of the list in the meantime would be read as a wrong answer.
                .opacity(dotPlaced ? 1 : 0)
                .animation(.linear(duration: 0.15), value: dotPlaced)
                .padding(.leading, 8)
                .accessibilityHidden(true)
        }
        .onChange(of: active) { _, index in moveDot(to: index, animated: true) }
        .onChange(of: centres[active]) { _, _ in moveDot(to: active, animated: false) }
        .onAppear { moveDot(to: active, animated: false) }
        .onChange(of: items.count) { _, count in centres.trim(to: count) }
    }

    @ViewBuilder
    private func row(_ item: BounceSidebarItem, at index: Int) -> some View {
        if item.isHeading {
            Text(item.label)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.14 * 11)
                .foregroundStyle(ink)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
                // A heading opens a gap above itself, unless it is the first thing in the list.
                .padding(.top, index == 0 ? 0 : 28)
                .accessibilityAddTraits(.isHeader)
        } else {
            Text(item.label)
                .font(.system(size: 14))
                .foregroundStyle(index == active ? theme.foreground : theme.foreground.opacity(0.5))
                .animation(.easeInOut(duration: 0.2), value: active)
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { select(index) }
                .accessibilityAddTraits(index == active ? [.isButton, .isSelected] : .isButton)
        }
    }

    private func moveDot(to index: Int, animated: Bool) {
        guard let centre = centres[index] else { return }
        let destination = centre - Self.dotSize / 2

        guard animated, !reduceMotion else {
            arcStart = destination
            arcEnd = destination
            dotY = destination
            live.value = destination
            dotPlaced = true
            return
        }

        // Aiming from where the dot actually is, rather than from where it was last sent,
        // is what keeps the arc right when a second row is picked mid flight.
        arcStart = live.value
        arcEnd = destination
        withAnimation(.easeOut(duration: Self.duration)) { dotY = destination }
        dotPlaced = true
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
