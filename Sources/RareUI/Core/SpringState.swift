//
//  SpringState.swift
//  A spring integrated by hand.
//
//  SwiftUI's springs are excellent and are used everywhere in this library that they fit.
//  They do not fit in two places: when the spring's output feeds a draw call rather than a
//  view property, and when it has to be given a starting velocity. The bell needs both,
//  because ringing it is a push rather than a new destination, and the harder the push the
//  further it swings.
//

import Foundation

/// A damped spring, stepped one frame at a time.
public struct RareUISpringState: Equatable, Sendable {
    /// Where the spring is.
    public var value: Double
    /// How fast it is moving, in units per second.
    public var velocity: Double

    /// Creates a spring at rest.
    ///
    /// - Parameters:
    ///   - value: Where it starts.
    ///   - velocity: How fast it is already moving.
    public init(value: Double = 0, velocity: Double = 0) {
        self.value = value
        self.velocity = velocity
    }

    /// Steps the spring toward a target.
    ///
    /// - Parameters:
    ///   - target: Where it is heading.
    ///   - elapsed: How long has passed, in seconds.
    ///   - stiffness: The spring constant, as Motion states it.
    ///   - damping: The damping coefficient, as Motion states it.
    ///   - mass: The mass of the body on the spring.
    public mutating func advance(
        to target: Double,
        by elapsed: Double,
        stiffness: Double,
        damping: Double,
        mass: Double = 1
    ) {
        guard elapsed > 0, mass > 0 else { return }
        velocity += (-stiffness * (value - target) - damping * velocity) / mass * elapsed
        value += velocity * elapsed
    }

    /// Whether the spring has stopped moving in any way worth drawing.
    ///
    /// - Parameters:
    ///   - target: Where it was heading.
    ///   - restDelta: How close counts as arrived.
    /// - Returns: Whether it has settled.
    public func hasSettled(at target: Double, restDelta: Double = 0.01) -> Bool {
        abs(value - target) < restDelta && abs(velocity) < restDelta * 10
    }
}
