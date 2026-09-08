//
//  DeleteButtonTests.swift
//  The bin's walls are redrawn rather than transformed, which is the one part of this
//  component that is geometry rather than animation. Checked against
//  `components/ui/delete-button.tsx`.
//

import CoreGraphics
@testable import RareUI
import Testing

@Suite("Bin walls")
struct BinWallsTests {
    private let box = CGRect(x: 0, y: 0, width: 24, height: 24)

    @Test("a shut bin is taller than an open one")
    func shrinksAsItOpens() {
        // The walls start lower down as the lid lifts, so the bin appears to sink into
        // itself and the lid swings clear of it rather than through it.
        let shut = BinWalls(top: 6).path(in: box).boundingRect
        let open = BinWalls(top: 13.5).path(in: box).boundingRect
        #expect(open.height < shut.height)
        #expect(open.minY > shut.minY)
        #expect(abs(open.maxY - shut.maxY) < 1e-6, "the base does not move")
    }

    @Test("the walls stay inside the icon's own box")
    func withinTheBox() {
        for top in stride(from: 6.0, through: 13.5, by: 0.5) {
            let bounds = BinWalls(top: top).path(in: box).boundingRect
            #expect(bounds.minX >= 0)
            #expect(bounds.maxX <= 24)
            #expect(bounds.maxY <= 24)
        }
    }

    @Test("the base is as wide as upstream draws it")
    func width() {
        // From five to nineteen in the icon's own coordinates, corners included.
        let bounds = BinWalls(top: 6).path(in: box).boundingRect
        #expect(abs(bounds.minX - 5) < 1e-6)
        #expect(abs(bounds.maxX - 19) < 1e-6)
    }

    @Test("the height is the shape's animatable value, so the walls slide rather than jump")
    func animatable() {
        var walls = BinWalls(top: 6)
        #expect(walls.animatableData == 6)
        walls.animatableData = 13.5
        #expect(walls.top == 13.5)
    }

    @Test("the shape scales with the box it is drawn in")
    func scales() {
        let small = BinWalls(top: 6).path(in: CGRect(x: 0, y: 0, width: 24, height: 24)).boundingRect
        let large = BinWalls(top: 6).path(in: CGRect(x: 0, y: 0, width: 48, height: 48)).boundingRect
        #expect(abs(large.width - 2 * small.width) < 1e-6)
        #expect(abs(large.height - 2 * small.height) < 1e-6)
    }
}

@Suite("Bin lid")
struct BinLidTests {
    private let box = CGRect(x: 0, y: 0, width: 24, height: 24)

    @Test("the lid is the rim and the handle above it")
    func shape() {
        let bounds = BinLid().path(in: box).boundingRect
        // The rim runs from three to twenty-one, and the handle reaches up to two.
        #expect(abs(bounds.minX - 3) < 1e-6)
        #expect(abs(bounds.maxX - 21) < 1e-6)
        #expect(abs(bounds.maxY - 6) < 1e-6)
        #expect(bounds.minY < 3, "the handle should stand above the rim")
    }

    @Test("the hinge is at the left end of the rim, not the middle of the icon")
    func hinge() {
        // Turning about the middle would make the lid pivot inside the bin rather than
        // swing off the back of it.
        #expect(BinLid.hinge.x == 3.0 / 24)
        #expect(BinLid.hinge.y == 6.0 / 24)
        #expect(BinLid.hinge.x < 0.5)
    }
}
