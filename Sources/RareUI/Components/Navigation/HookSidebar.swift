//
//  HookSidebar.swift
//  A port of upstream's `components/ui/hook-sidebar.tsx`.
//
//  A list with a rail down its left edge that stops at the current row and turns into it
//  with a small quarter-round hook. Hovering or focusing another row runs a second, fainter
//  rail out to that one, so the list shows both where you are and where you are about to be.
//

import SwiftUI

/// One row of a ``HookSidebar``.
public struct HookSidebarItem: Identifiable, Hashable, Sendable, ExpressibleByStringLiteral {
    /// The row's text.
    public let label: String

    public var id: String {
        label
    }

    /// Creates a row.
    ///
    /// - Parameter label: The row's text.
    public init(_ label: String) {
        self.label = label
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }
}

/// A list marked by a rail that hooks into the current row.
///
/// ```swift
/// HookSidebar(items: ["Overview", "Install", "Theming"], selection: $section)
/// ```
///
/// The second rail follows a pointer or the keyboard focus, so it appears on a Mac, an
/// iPad with a trackpad or anything with a hardware keyboard, and simply never appears on
/// a phone. Upstream has the same behaviour for the same reason.
///
/// Under Reduce Motion the rails move without springing.
public struct HookSidebar: View {
    private let items: [HookSidebarItem]
    private let label: String?
    private let selection: Binding<Int>?
    private let color: Color?
    private let dashed: Bool
    private let onChange: ((Int) -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var uncontrolled: Int
    @State private var centres = RareUIRowCentres()
    @State private var hovered: Int?

    /// The radius of the hook, which is also how far above a row's middle the rail stops.
    static var corner: Double {
        6
    }

    /// The spring both rails travel on.
    private static var travel: Animation {
        .rareUISpring(stiffness: 420, damping: 34, mass: 0.7)
    }

    /// Creates a sidebar bound to a selection you hold.
    ///
    /// - Parameters:
    ///   - items: The rows, in order.
    ///   - selection: The index of the selected row.
    ///   - label: A heading above the list.
    ///   - color: The active rail's colour. Defaults to the theme's accent.
    ///   - dashed: Whether the rails are drawn as dashes. Defaults to `true`.
    public init(
        items: [HookSidebarItem],
        selection: Binding<Int>,
        label: String? = nil,
        color: Color? = nil,
        dashed: Bool = true
    ) {
        self.items = items
        self.selection = selection
        self.label = label
        self.color = color
        self.dashed = dashed
        onChange = nil
        _uncontrolled = State(initialValue: selection.wrappedValue)
    }

    /// Creates a sidebar that keeps its own selection.
    ///
    /// - Parameters:
    ///   - items: The rows, in order.
    ///   - defaultSelection: The row selected to begin with.
    ///   - label: A heading above the list.
    ///   - color: The active rail's colour. Defaults to the theme's accent.
    ///   - dashed: Whether the rails are drawn as dashes. Defaults to `true`.
    ///   - onChange: Called with the index of a newly selected row.
    public init(
        items: [HookSidebarItem],
        defaultSelection: Int = 0,
        label: String? = nil,
        color: Color? = nil,
        dashed: Bool = true,
        onChange: ((Int) -> Void)? = nil
    ) {
        self.items = items
        selection = nil
        self.label = label
        self.color = color
        self.dashed = dashed
        self.onChange = onChange
        _uncontrolled = State(initialValue: defaultSelection)
    }

    private var active: Int {
        selection?.wrappedValue ?? uncontrolled
    }

    private var ink: Color {
        color ?? theme.accent
    }

    private var animation: Animation? {
        RareUIMotion.settling(Self.travel, reduceMotion: reduceMotion)
    }

    private var activeY: Double? {
        centres[active]
    }

    private var hoverY: Double? {
        hovered.flatMap { centres[$0] }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(theme.foreground)
                    .padding(.bottom, 12)
                    .padding(.leading, 2)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(item, at: index)
                        .rareUIMeasureRow(index, into: centres)
                }
            }
            .rareUIRowSpace()
            .overlay(alignment: .topLeading) { rails }
        }
        .onChange(of: items.count) { _, count in centres.trim(to: count) }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var rails: some View {
        let ghostFrom = hookGhostRailStart(activeY: activeY, hoverY: hoverY, corner: Self.corner)

        HookRail(
            from: ghostFrom,
            to: hoverY,
            visible: hovered != nil && hovered != active,
            color: theme.foreground.opacity(0.3),
            dashed: dashed,
            animation: animation
        )

        HookRail(
            from: 0,
            to: activeY,
            visible: activeY != nil,
            color: ink,
            dashed: dashed,
            animation: animation
        )
    }

    private func row(_ item: HookSidebarItem, at index: Int) -> some View {
        Text(item.label)
            .font(.system(size: 14))
            .foregroundStyle(index == active ? theme.foreground : theme.foreground.opacity(0.5))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: active)
            .padding(.vertical, 6)
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { select(index) }
            .onHover { inside in hovered = inside ? index : (hovered == index ? nil : hovered) }
            .accessibilityAddTraits(index == active ? [.isButton, .isSelected] : .isButton)
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
