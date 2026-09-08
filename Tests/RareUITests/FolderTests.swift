//
//  FolderTests.swift
//  Where the cards sit in each of the folder's three states, checked against
//  `components/ui/folder-component.tsx`.
//

@testable import RareUI
import Testing

@Suite("Folder states")
struct FolderStateTests {
    @Test("the flap tips further back at every step")
    func flapOpensProgressively() {
        #expect(FolderState.rest.flapAngle > FolderState.hovering.flapAngle)
        #expect(FolderState.hovering.flapAngle > FolderState.open.flapAngle)
        // All three tip backward, so the folder never leans toward the reader.
        #expect(FolderState.rest.flapAngle < 0)
    }

    @Test("hovering is most of the way to open, so the two do not read as separate ideas")
    func hoverIsAPreview() {
        let travel = FolderState.rest.flapAngle - FolderState.open.flapAngle
        let hovered = FolderState.rest.flapAngle - FolderState.hovering.flapAngle
        #expect(hovered / travel > 0.7)
    }
}

@Suite("Folder cards")
struct FolderCardTests {
    @Test("the cards lift clear of the folder when it opens")
    func lift() {
        for placement in FolderCardPlacement.all {
            let rest = placement.offset(in: .rest).y
            let hovering = placement.offset(in: .hovering).y
            let open = placement.offset(in: .open).y
            #expect(hovering < rest, "hovering should lift them")
            #expect(open < hovering, "opening should lift them further")
            #expect(open < -150, "and clear of the folder entirely")
        }
    }

    @Test("the fan opens outward, so the three do not end up on top of each other")
    func fan() {
        let outer = FolderCardPlacement.all
        // The first leans right and sits right, the last leans left and sits left, and the
        // middle one is nearly straight. Opening exaggerates all of it.
        #expect(outer[0].offset(in: .open).x > outer[1].offset(in: .open).x)
        #expect(outer[1].offset(in: .open).x > outer[2].offset(in: .open).x)
        #expect(outer[0].rotation(in: .open) > outer[1].rotation(in: .open))
        #expect(outer[1].rotation(in: .open) > outer[2].rotation(in: .open))

        for placement in outer {
            #expect(abs(placement.rotation(in: .open)) >= abs(placement.rotation(in: .rest)))
        }
    }

    @Test("the cards leave in turn rather than together")
    func staggered() {
        let delays = FolderCardPlacement.all.map { $0.delay(in: .open) }
        #expect(Set(delays).count > 1, "they should not all leave at once")
        // The one nearest the front leaves last, so the fan opens from the back forward.
        #expect(delays[0] > delays[2])
    }

    @Test("closing happens all at once, with nothing held back")
    func closesTogether() {
        for placement in FolderCardPlacement.all {
            #expect(placement.delay(in: .rest) == 0)
        }
    }
}
