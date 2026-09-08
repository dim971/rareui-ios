//
//  HookRail.swift
//  One of HookSidebar's two rails, ported from the `Rail` component in upstream's
//  `components/ui/hook-sidebar.tsx`.
//
//  A hairline running down the gutter, stopping a corner's radius short of the row it is
//  pointing at, and a quarter-round hook turning out of it toward that row.
//

import SwiftUI

/// The hook the rail turns into at the row it points at.
///
/// It is upstream's `M0.5 0a6 6 0 0 0 6 6H12` at its natural size: down the gutter, round
/// a quarter circle of the corner's radius, then out toward the label.
struct HookCorner: Shape {
    /// The radius of the quarter circle.
    let corner: Double
    /// How far the hook reaches out toward the label after it has turned.
    let reach: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.minX + corner, y: rect.minY),
            radius: corner,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.minX + reach, y: rect.minY + corner))
        return path
    }
}

/// A rail running from `from` down to `to`, ending in a hook.
struct HookRail: View {
    /// Where the rail starts, measured from the top of the list.
    let from: Double
    /// The middle of the row it points at, or `nil` when there is nothing to point at.
    let to: Double?
    /// Whether the rail is showing at all.
    let visible: Bool
    /// The rail's colour.
    let color: Color
    /// Whether it is drawn as dashes.
    let dashed: Bool
    /// The animation the rail travels on, or `nil` to move without one.
    let animation: Animation?

    /// The gutter the rail runs down, in points from the leading edge.
    private static var gutter: Double {
        2
    }

    /// The hook's width, from upstream's `width="12"`.
    private static var reach: Double {
        12
    }

    /// The dash pattern, from upstream's `transparent 0 2px, currentColor 2px 4px`.
    private static var dashPattern: [CGFloat] {
        [2, 2]
    }

    private var target: Double {
        to ?? 0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The rail stops a corner short of the row, because the hook covers that last
            // stretch on its way round.
            RailLine()
                .stroke(color, style: StrokeStyle(lineWidth: 1, dash: dashed ? Self.dashPattern : []))
                .frame(width: 1, height: max(0, target - HookSidebar.corner - from))
                .offset(x: Self.gutter, y: from)

            HookCorner(corner: HookSidebar.corner, reach: Self.reach)
                .stroke(color, style: StrokeStyle(lineWidth: 1, dash: dashed ? Self.dashPattern : []))
                .frame(width: Self.reach, height: HookSidebar.corner)
                .offset(x: Self.gutter, y: target - HookSidebar.corner)
        }
        // No greedy frame here. An overlay is already sized and placed by its host, and
        // asking for infinite height inside a scroll view makes the whole page collapse.
        .animation(animation, value: from)
        .animation(animation, value: target)
        .opacity(visible && to != nil ? 1 : 0)
        .animation(animation == nil ? nil : .linear(duration: 0.2), value: visible && to != nil)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The hairline itself, as a path so it can be dashed.
///
/// Upstream draws this as a repeating gradient rather than a stroke, which comes to the
/// same thing: two points of ink, two points of nothing, all the way up.
struct RailLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// Where the fainter rail starts.
///
/// Below the active row the two rails read as one line reaching further, so the faint one
/// starts where the accent one stops. Above it the accent rail already covers the whole
/// span, so there is nothing to draw but the hook itself, and the faint rail starts a
/// corner short of the row it is pointing at.
///
/// - Parameters:
///   - activeY: The middle of the selected row, or `nil` if there is not one.
///   - hoverY: The middle of the row being pointed at, or `nil` if none is.
///   - corner: The hook's radius.
/// - Returns: Where the faint rail starts, measured from the top of the list.
func hookGhostRailStart(activeY: Double?, hoverY: Double?, corner: Double) -> Double {
    guard let activeY, let hoverY else { return activeY ?? 0 }
    return hoverY <= activeY ? max(0, hoverY - corner) : activeY
}
