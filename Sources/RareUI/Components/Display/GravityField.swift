//
//  GravityField.swift
//  The simulation behind GravityLetters, ported from the `retarget`, `rebuild` and `step`
//  functions in upstream's `components/ui/gravity-letters.tsx`.
//
//  A glyph does not fall and then discover where it lands. It is told where it will land
//  the moment it is dropped, and it falls under gravity toward that place while its
//  horizontal position and its rotation are interpolated along the way. That is why the
//  pile is stable: the landing spot was reserved in the height map at the start, so nothing
//  can arrive somewhere another glyph has already taken.
//

import Foundation

/// One falling or fallen glyph.
struct GravityBody: Identifiable {
    let id: Int
    /// What is drawn.
    let glyph: String
    /// How big it is drawn.
    let fontSize: Double

    /// The glyph's own size, before it is rotated.
    var naturalWidth: Double
    var naturalHeight: Double
    /// Its size once rotated, which is what the height map deals in.
    var width: Double
    var height: Double
    /// The offset between the two, so the drawing stays centred in its rotated box.
    var offsetX: Double
    var offsetY: Double

    /// Where the current fall started.
    var startX: Double
    var startY: Double
    /// Where it is.
    var x: Double
    var y: Double
    /// Where it is going.
    var targetX: Double
    var targetY: Double

    var velocityY: Double
    /// The rotation it is tumbling through, before it blends into its resting angle.
    var spin: Double
    var spinRate: Double
    /// What is actually drawn.
    var rotation: Double
    /// The angle it will come to rest at, taken from the slope it lands on.
    var restRotation: Double
    /// How far it drifts sideways on the way down, peaking halfway.
    var sway: Double

    var hasBounced: Bool
    var isResting: Bool
}

/// The pile, and everything falling into it.
struct GravityField {
    private(set) var bodies: [GravityBody] = []
    private var map: GravityHeightMap
    private var size: CGSize
    private var nextID = 0

    /// Which way the pile is leaning, from the device being tilted. Zero when it is level.
    var wind: Double = 0

    /// Creates an empty field.
    ///
    /// - Parameter size: The container's size, in points.
    init(size: CGSize) {
        self.size = size
        map = GravityHeightMap(width: size.width, height: size.height)
    }

    /// Whether anything is still moving, which is what decides if the clock needs to run.
    var isSettled: Bool {
        bodies.allSatisfy(\.isResting)
    }

    /// How many glyphs there are.
    var count: Int {
        bodies.count
    }

    /// Drops a glyph in.
    ///
    /// - Parameters:
    ///   - glyph: What to draw.
    ///   - fontSize: How big to draw it.
    ///   - measurement: The glyph's natural size at that font size.
    ///   - x: Where to drop it from, horizontally.
    ///   - limit: The most glyphs to keep. The oldest are dropped past it.
    mutating func drop(
        glyph: String,
        fontSize: Double,
        measurement: CGSize,
        at x: Double,
        limit: Int
    ) {
        // Written out rather than inlined: CGFloat and Double are the same type here and
        // two different types to the compiler, and mixing them inside one expression is
        // ambiguous on some toolchains and not on others.
        let squareness = min(1.0, Double(measurement.height) / max(1.0, Double(measurement.width)))

        var body = GravityBody(
            id: nextID,
            glyph: glyph,
            fontSize: fontSize,
            naturalWidth: measurement.width,
            naturalHeight: measurement.height,
            width: measurement.width,
            height: measurement.height,
            offsetX: 0,
            offsetY: 0,
            startX: x,
            startY: 0,
            x: x,
            y: 0,
            targetX: x,
            targetY: 0,
            velocityY: 0,
            spin: 0,
            // A squarer glyph tumbles faster than a tall thin one, which is upstream's
            // squareness factor: it is the difference between a dropped O and a dropped I.
            spinRate: Double.random(in: -1 ... 1) * (50 + 130 * squareness),
            rotation: 0,
            restRotation: 0,
            sway: 0,
            hasBounced: false,
            isResting: false
        )

        nextID += 1
        retarget(&body)
        // Dropping it just clear of whatever it is going to land on, rather than always
        // from the top, so a deep pile does not make every new glyph fall further.
        body.y = min(body.y, body.targetY - 24)
        body.startY = body.y
        bodies.append(body)

        if bodies.count > limit {
            bodies.removeFirst(bodies.count - limit)
            rebuild()
        }
    }

    /// Steps every falling glyph forward.
    ///
    /// - Parameters:
    ///   - elapsed: How long has passed, in seconds.
    ///   - gravity: The acceleration, in points per second squared.
    mutating func step(by elapsed: Double, gravity: Double) {
        for index in bodies.indices where !bodies[index].isResting {
            // Copied out and back rather than mutated in place: the simulation reads the
            // height map while it writes the body, and Swift will not let one value do both
            // to itself at once.
            var body = bodies[index]
            advance(&body, by: elapsed, gravity: gravity)
            bodies[index] = body
        }
    }

    /// Rebuilds the pile from scratch, which is what a resize or an avalanche needs.
    ///
    /// - Parameter sliding: Whether resting glyphs should look for somewhere lower to go.
    mutating func rebuild(sliding: Bool = false) {
        map = GravityHeightMap(width: size.width, height: size.height)

        // Deepest first, so the bottom of the pile is rebuilt before anything resting on it.
        let order = bodies.indices.sorted { bodies[$0].y > bodies[$1].y }
        for index in order {
            var body = bodies[index]
            body.spin = body.rotation

            guard body.isResting else {
                retarget(&body)
                bodies[index] = body
                continue
            }

            let rest = map.restY(
                x: body.x,
                width: body.width,
                glyphHeight: body.height,
                rotation: body.restRotation
            )
            var falls = body.y < rest - 1

            if !falls, sliding {
                let probe = map.restX(
                    from: body.x,
                    width: body.naturalWidth,
                    glyphHeight: body.naturalHeight,
                    maxX: max(size.width - body.naturalWidth, 0),
                    bias: wind == 0 ? 1 : wind,
                    eager: gravityEagerSlope
                )
                let candidateX = min(max(probe - body.offsetX, 0), max(size.width - body.width, 0))
                let candidateY = map.restY(
                    x: candidateX,
                    width: body.width,
                    glyphHeight: body.height,
                    rotation: body.restRotation
                )
                falls = candidateY > body.y + 2
                if falls { body.spinRate = Double.random(in: -40 ... 40) }
            }

            if falls {
                body.velocityY = 0
                retarget(&body)
            } else {
                map.deposit(
                    x: body.x,
                    width: body.width,
                    glyphHeight: body.height,
                    rotation: body.restRotation,
                    y: body.y
                )
            }
            bodies[index] = body
        }
    }

    /// Notes a new container size and settles the pile into it.
    ///
    /// - Parameter size: The new size.
    mutating func resize(to size: CGSize) {
        guard size != self.size, size.width > 0, size.height > 0 else { return }
        self.size = size
        rebuild()
    }

    /// Empties the field.
    mutating func clear() {
        bodies.removeAll()
        map = GravityHeightMap(width: size.width, height: size.height)
    }

    /// Works out where a glyph is going and reserves the space for it.
    private mutating func retarget(_ body: inout GravityBody) {
        // A tilted device decides which way ties break; a level one tosses a coin.
        let bias = wind != 0 ? wind : (Bool.random() ? -1.0 : 1.0)
        let seekX = map.restX(
            from: body.x,
            width: body.naturalWidth,
            glyphHeight: body.naturalHeight,
            maxX: max(size.width - body.naturalWidth, 0),
            bias: bias,
            eager: wind != 0 ? gravityEagerSlope : 1
        )

        let squareness = min(1, body.naturalHeight / max(1, body.naturalWidth))
        let jitter = Double.random(in: -1 ... 1) * (2 + 8 * squareness)
        let restRotation = min(
            max(map.groundTilt(x: seekX, width: body.naturalWidth) + jitter, -gravityMaxTilt),
            gravityMaxTilt
        )

        // A rotated glyph needs a bigger box, and the height map only deals in boxes.
        let radians = abs(restRotation) * .pi / 180
        body.restRotation = restRotation
        body.width = body.naturalWidth * cos(radians) + body.naturalHeight * sin(radians)
        body.height = body.naturalWidth * sin(radians) + body.naturalHeight * cos(radians)
        body.offsetX = (body.width - body.naturalWidth) / 2
        body.offsetY = (body.height - body.naturalHeight) / 2

        let targetX = min(max(seekX - body.offsetX, 0), max(size.width - body.width, 0))
        let targetY = map.restY(
            x: targetX,
            width: body.width,
            glyphHeight: body.height,
            rotation: restRotation
        )
        map.deposit(
            x: targetX,
            width: body.width,
            glyphHeight: body.height,
            rotation: restRotation,
            y: targetY
        )

        body.startX = body.x
        body.startY = min(body.y, targetY)
        body.targetX = targetX
        body.targetY = targetY
        // The further it falls the more it wanders, up to a point.
        body.sway = Double.random(in: -1 ... 1) * min(12, (targetY - body.startY) * 0.05)
        body.hasBounced = false
        body.isResting = false
    }

    private mutating func advance(_ body: inout GravityBody, by elapsed: Double, gravity: Double) {
        body.velocityY += gravity * elapsed
        body.y += body.velocityY * elapsed
        body.spin += body.spinRate * elapsed

        let total = body.targetY - body.startY
        let progress = total > 0 ? min((body.y - body.startY) / total, 1) : 1

        // The horizontal move eases out while the fall accelerates, so a glyph arrives over
        // its landing spot well before it reaches it rather than sliding in sideways at the
        // last moment.
        body.x = body.startX
            + (body.targetX - body.startX) * progress * (2 - progress)
            + sin(progress * .pi) * body.sway

        // The tumble gives way to the resting angle late, so the glyph is still turning
        // most of the way down and then settles quickly.
        let blend = progress * progress * progress
        body.rotation = body.spin * (1 - blend) + body.restRotation * blend

        guard body.y >= body.targetY else { return }

        body.x = body.targetX
        body.y = body.targetY
        body.rotation = body.restRotation

        let rebound = body.velocityY * gravityBounce
        // One bounce only, and only if it would be worth seeing. Upstream compares the
        // rebound's square against the gravity so the test scales with the setting.
        if !body.hasBounced, rebound * rebound > gravity * 6 {
            body.hasBounced = true
            body.velocityY = -rebound
            body.startX = body.targetX
            body.startY = body.targetY - rebound * rebound / (2 * max(gravity, 1))
            body.sway = 0
            body.spinRate *= 0.4
            return
        }

        body.velocityY = 0
        body.spinRate = 0
        body.isResting = true
    }
}
