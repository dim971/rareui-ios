//
//  HookSidebarTests.swift
//  The rail's geometry, checked against `components/ui/hook-sidebar.tsx`.
//

import CoreGraphics
@testable import RareUI
import Testing

@Suite("Hook sidebar rail")
struct HookRailTests {
    @Test("the hook starts in the gutter and ends out by the label")
    func hookShape() {
        let corner = 6.0
        let reach = 12.0
        let path = HookCorner(corner: corner, reach: reach)
            .path(in: CGRect(x: 0, y: 0, width: reach, height: corner))
        let bounds = path.boundingRect

        // It turns through a quarter circle of the corner's radius and then runs out flat.
        // The tolerance is loose because an arc is stored as beziers approximating it, and
        // the approximation is what the bounding box is taken from.
        #expect(abs(bounds.minX) < 1e-6)
        #expect(abs(bounds.maxX - reach) < 1e-6)
        #expect(abs(bounds.minY) < 1e-6)
        #expect(abs(bounds.maxY - corner) < 1e-6)
    }

    @Test("pointing below the selection, the faint rail carries on from where the accent one stops")
    func ghostBelow() {
        // The two together read as one line reaching further, rather than as two lines
        // overlapping each other.
        #expect(hookGhostRailStart(activeY: 40, hoverY: 100, corner: 6) == 40)
    }

    @Test("pointing above the selection, only the hook is drawn")
    func ghostAbove() {
        // The accent rail already covers everything above the selection, so the faint one
        // starts a corner short of its own row and draws nothing but the turn.
        #expect(hookGhostRailStart(activeY: 100, hoverY: 40, corner: 6) == 34)
    }

    @Test("the faint rail never starts above the top of the list")
    func ghostClamped() {
        #expect(hookGhostRailStart(activeY: 100, hoverY: 4, corner: 6) == 0)
    }

    @Test("with nothing to point at there is nothing to start from")
    func ghostMissing() {
        #expect(hookGhostRailStart(activeY: 40, hoverY: nil, corner: 6) == 40)
        #expect(hookGhostRailStart(activeY: nil, hoverY: 40, corner: 6) == 0)
        #expect(hookGhostRailStart(activeY: nil, hoverY: nil, corner: 6) == 0)
    }
}
