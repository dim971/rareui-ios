//
//  GravityTests.swift
//  The height map is the whole model, so the height map is what is tested. Checked against
//  the `spanOf`, `restY`, `deposit`, `windowTop`, `groundTilt` and `findRestX` functions in
//  `components/ui/gravity-letters.tsx`.
//

import CoreGraphics
@testable import RareUI
import Testing

@Suite("Gravity height map")
struct GravityHeightMapTests {
    private func emptyMap() -> GravityHeightMap {
        GravityHeightMap(width: 320, height: 200)
    }

    @Test("a glyph covers the columns it overlaps and no others")
    func span() {
        let map = emptyMap()
        // Columns are eight points wide, so a glyph from ten to thirty covers one to three.
        let bounds = map.span(x: 10, width: 20)
        #expect(bounds.from == 1)
        #expect(bounds.to == 3)
    }

    @Test("a glyph at the very edge is clamped into the map rather than running off it")
    func spanClamped() {
        let map = emptyMap()
        #expect(map.span(x: -50, width: 20).from == 0)
        #expect(map.span(x: 1000, width: 20).to == map.heights.count - 1)
    }

    @Test("on an empty floor a glyph rests on the bottom")
    func restsOnTheFloor() {
        let map = emptyMap()
        let rest = map.restY(x: 40, width: 20, glyphHeight: 30, rotation: 0)
        // Two hundred tall, a thirty point glyph, so its top edge sits at one seventy.
        #expect(abs(rest - 170) < 1e-9)
    }

    @Test("a glyph landing on another rests on top of it")
    func stacks() {
        var map = emptyMap()
        map.deposit(x: 40, width: 20, glyphHeight: 30, rotation: 0, y: 170)
        let rest = map.restY(x: 40, width: 20, glyphHeight: 30, rotation: 0)
        #expect(abs(rest - 140) < 1e-9, "the second should sit exactly on the first")
    }

    @Test("a glyph beside the pile is unaffected by it")
    func independentColumns() {
        var map = emptyMap()
        map.deposit(x: 40, width: 20, glyphHeight: 30, rotation: 0, y: 170)
        let beside = map.restY(x: 120, width: 20, glyphHeight: 30, rotation: 0)
        #expect(abs(beside - 170) < 1e-9)
    }

    @Test("beyond the walls the heap reads as infinitely high, so nothing slides out")
    func wallsAreInfinite() {
        let map = emptyMap()
        #expect(map.top(from: -3, to: 1) == .infinity)
        #expect(map.top(from: 0, to: map.heights.count) == .infinity)
        #expect(map.top(from: 0, to: 3).isFinite)
    }

    @Test("a glyph slides off a ridge and stops in a hollow")
    func slidesDownhill() {
        var map = emptyMap()
        // A tower on the left, nothing to the right.
        for _ in 0 ..< 4 {
            map.deposit(x: 0, width: 24, glyphHeight: 30, rotation: 0, y: 0)
        }
        let landed = map.restX(from: 4, width: 24, glyphHeight: 30, maxX: 296, bias: 1)
        #expect(landed > 4, "it should have moved off the tower")
    }

    @Test("a glyph on level ground stays where it is")
    func staysOnTheLevel() {
        let map = emptyMap()
        #expect(map.restX(from: 100, width: 24, glyphHeight: 30, maxX: 296, bias: 1) == 100)
    }

    @Test("sliding never leaves the container")
    func staysInside() {
        let map = emptyMap()
        for bias in [-1.0, 1.0] {
            let landed = map.restX(from: 400, width: 24, glyphHeight: 30, maxX: 296, bias: bias)
            #expect(landed >= 0 && landed <= 296)
        }
    }

    @Test("the ground's slope is read from the difference between the two halves")
    func groundTilt() {
        var map = emptyMap()
        // Building up the left half only, so the ground under a wide glyph slopes down
        // to the right and the glyph should lean that way.
        for _ in 0 ..< 3 {
            map.deposit(x: 0, width: 40, glyphHeight: 30, rotation: 0, y: 0)
        }
        #expect(map.groundTilt(x: 0, width: 80) > 0, "higher on the left reads as positive")
        #expect(map.groundTilt(x: 200, width: 80) == 0, "level ground has no slope")
    }

    @Test("a leaning glyph touches down on one corner rather than along its base")
    func leaningRests() {
        let map = emptyMap()
        let level = map.restY(x: 40, width: 30, glyphHeight: 30, rotation: 0)
        let leaning = map.restY(x: 40, width: 30, glyphHeight: 30, rotation: 20)
        // Leaning puts one corner lower than the base would be, so the box sits higher.
        #expect(leaning > level)
    }

    @Test("an eager slide gives way sooner than a reluctant one")
    func eagerness() {
        var map = emptyMap()
        for _ in 0 ..< 2 {
            map.deposit(x: 0, width: 24, glyphHeight: 30, rotation: 0, y: 0)
        }
        let reluctant = map.restX(from: 4, width: 24, glyphHeight: 30, maxX: 296, bias: 1, eager: 1)
        let eager = map.restX(
            from: 4, width: 24, glyphHeight: 30, maxX: 296, bias: 1, eager: gravityEagerSlope
        )
        #expect(eager >= reluctant)
    }
}

@Suite("Gravity field")
struct GravityFieldTests {
    @Test("an empty field has settled")
    func emptyIsSettled() {
        #expect(GravityField(size: CGSize(width: 320, height: 200)).isSettled)
    }

    @Test("a dropped glyph is in motion until it lands")
    func fallsThenSettles() {
        var field = GravityField(size: CGSize(width: 320, height: 200))
        field.drop(
            glyph: "A",
            fontSize: 28,
            measurement: CGSize(width: 20, height: 28),
            at: 100,
            limit: 50
        )
        #expect(!field.isSettled)

        // Two seconds at sixty frames is far more than a two hundred point fall needs.
        for _ in 0 ..< 120 {
            field.step(by: 1.0 / 60, gravity: 800)
        }
        #expect(field.isSettled)
        #expect(field.bodies.count == 1)
    }

    @Test("a glyph comes to rest inside the container")
    func landsInside() {
        var field = GravityField(size: CGSize(width: 320, height: 200))
        for _ in 0 ..< 12 {
            field.drop(
                glyph: "M",
                fontSize: 28,
                measurement: CGSize(width: 24, height: 28),
                at: Double.random(in: 0 ... 290),
                limit: 50
            )
        }
        for _ in 0 ..< 240 {
            field.step(by: 1.0 / 60, gravity: 800)
        }

        for body in field.bodies {
            #expect(body.x >= -1)
            #expect(body.x + body.width <= 321)
            #expect(body.y + body.height <= 201)
        }
    }

    @Test("the oldest glyphs are forgotten past the limit")
    func forgetsTheOldest() {
        var field = GravityField(size: CGSize(width: 320, height: 200))
        for _ in 0 ..< 20 {
            field.drop(
                glyph: "X",
                fontSize: 20,
                measurement: CGSize(width: 16, height: 20),
                at: 100,
                limit: 5
            )
        }
        #expect(field.count == 5)
        // And the five kept are the five most recent, which is what the identifiers say.
        #expect(field.bodies.map(\.id) == [15, 16, 17, 18, 19])
    }
}
