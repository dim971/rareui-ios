//
//  NotificationBellTests.swift
//  Ringing a bell is a push rather than a destination, and the arithmetic of that push is
//  the component. Checked against `components/ui/notification-bell.tsx`.
//

@testable import RareUI
import Testing

@Suite("Bell ringing")
struct BellRingTests {
    @Test("one notification pushes a bell at rest")
    func fromRest() {
        // At rest the direction is taken as negative, so the first ring swings one way and
        // is not left dependent on a velocity of exactly zero.
        let velocity = bellRingVelocity(from: 0, delta: 1)
        #expect(velocity != 0)
        #expect(abs(velocity) == bellImpulse * (0.7 + 0.6 / bellBurst))
    }

    @Test("more arriving at once pushes harder, up to five")
    func weight() {
        let one = abs(bellRingVelocity(from: 0, delta: 1))
        let three = abs(bellRingVelocity(from: 0, delta: 3))
        let five = abs(bellRingVelocity(from: 0, delta: 5))
        let fifty = abs(bellRingVelocity(from: 0, delta: 50))

        #expect(one < three)
        #expect(three < five)
        #expect(five == fifty, "past five the push stops growing")
        // The weight is 0.7 plus 0.6 of however far along the five the count is, so one
        // notification weighs 0.82 and five weigh the full 1.3. Nothing ever weighs 0.7:
        // that is the limit the formula approaches from below and never reaches, since a
        // ring of no notifications is not a ring.
        #expect(abs(five / one - 1.3 / 0.82) < 1e-9)
    }

    @Test("the push goes the way the bell is already going, so a second ring adds to the first")
    func alongTheSwing() {
        // Moving one way, the push is the same way, and the bell ends up faster than either.
        let moving = 300.0
        #expect(bellRingVelocity(from: moving, delta: 1) > moving)

        let returning = -300.0
        #expect(bellRingVelocity(from: returning, delta: 1) < returning)
    }

    @Test("the bell cannot be made to spin, however many arrive")
    func capped() {
        #expect(bellRingVelocity(from: 800, delta: 5) == bellMaxVelocity)
        #expect(bellRingVelocity(from: -800, delta: 5) == -bellMaxVelocity)
        #expect(abs(bellRingVelocity(from: 0, delta: 5)) <= bellMaxVelocity)
    }
}

@Suite("Bell clapper")
struct BellClapperTests {
    @Test("the clapper hangs straight when the bell is still")
    func atRest() {
        #expect(bellClapperLag(swingVelocity: 0) == 0)
    }

    @Test("it trails the bell, so it leans against the direction of travel")
    func trails() {
        #expect(bellClapperLag(swingVelocity: 200) < 0)
        #expect(bellClapperLag(swingVelocity: -200) > 0)
    }

    @Test("it never leans further than its sweep, however fast the bell goes")
    func clamped() {
        #expect(bellClapperLag(swingVelocity: bellClapperVelocity) == -bellClapperSweep)
        #expect(bellClapperLag(swingVelocity: 100_000) == -bellClapperSweep)
        #expect(bellClapperLag(swingVelocity: -100_000) == bellClapperSweep)
    }

    @Test("it is driven by speed rather than position, which is what makes it lag")
    func drivenBySpeed() {
        // A pendulum is fastest at the bottom of its swing, which is exactly where a real
        // clapper is furthest from centre. Driving it from the angle would put it furthest
        // out at the top instead, which is backwards.
        #expect(abs(bellClapperLag(swingVelocity: 450)) > abs(bellClapperLag(swingVelocity: 50)))
    }
}

@Suite("Bell badge placement")
struct BellBadgeTests {
    @Test("the badge sits just outside the button at upstream's defaults")
    func defaultSize() {
        // A 48 point bell with a count badge: 48 * 0.38 is 18.24 across, and the badge ends
        // up hanging very slightly over the edge.
        let inset = bellBadgeInset(size: 48, side: 48 * 0.38, orbit: 0.9)
        #expect(inset < 0)
        #expect(abs(inset) < 1)
    }

    @Test("the placement is proportional, so it holds at any size")
    func scales() {
        // Doubling everything doubles the inset rather than changing where the badge sits
        // in relation to the bell.
        let small = bellBadgeInset(size: 32, side: 32 * 0.38, orbit: 0.9)
        let large = bellBadgeInset(size: 64, side: 64 * 0.38, orbit: 0.9)
        #expect(abs(large - 2 * small) < 1e-9)
    }

    @Test("a dot sits further out than a number, being smaller")
    func dotVersusCount() {
        let dot = bellBadgeInset(size: 48, side: 48 * 0.22, orbit: 0.9)
        let count = bellBadgeInset(size: 48, side: 48 * 0.38, orbit: 0.9)
        #expect(dot > count)
    }

    @Test("an orbit of one puts the badge exactly on the button's edge")
    func onTheEdge() {
        // The circle the badge is placed on has the button's own radius, scaled by the orbit.
        #expect(bellBadgeInset(size: 48, side: 0, orbit: 1) == 24 - 24 * 0.5.squareRoot())
    }
}

@Suite("Hand integrated spring")
struct SpringStateTests {
    @Test("a spring at its target and standing still stays there")
    func settled() {
        var spring = RareUISpringState()
        spring.advance(to: 0, by: 1.0 / 60, stiffness: 220, damping: 10)
        #expect(spring.value == 0)
        #expect(spring.velocity == 0)
    }

    @Test("a spring given a velocity travels and comes back")
    func swings() {
        var spring = RareUISpringState(velocity: 500)
        var furthest = 0.0
        for _ in 0 ..< 600 {
            spring.advance(to: 0, by: 1.0 / 60, stiffness: 220, damping: 10)
            furthest = max(furthest, abs(spring.value))
        }
        #expect(furthest > 10, "it should have swung somewhere")
        #expect(spring.hasSettled(at: 0), "and come back to rest inside ten seconds")
    }

    @Test("the bell's own spring is underdamped, which is why it keeps swinging")
    func underdamped() {
        // Critical damping for a stiffness of 220 is about 29.7, and upstream uses 10, well
        // under it. That is the whole character of the component.
        var spring = RareUISpringState(velocity: 400)
        var crossings = 0
        var previous = spring.value
        for _ in 0 ..< 300 {
            spring.advance(to: 0, by: 1.0 / 60, stiffness: 220, damping: 10)
            if previous.sign != spring.value.sign, spring.value != 0 { crossings += 1 }
            previous = spring.value
        }
        #expect(crossings > 3, "it should cross the middle several times, not stop dead")
    }

    @Test("a step of no time changes nothing")
    func noTime() {
        var spring = RareUISpringState(value: 5, velocity: 100)
        spring.advance(to: 0, by: 0, stiffness: 220, damping: 10)
        #expect(spring.value == 5)
        #expect(spring.velocity == 100)
    }
}
