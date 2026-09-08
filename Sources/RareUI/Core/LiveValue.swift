//
//  LiveValue.swift
//  A place to write down the value an animation is currently passing through.
//
//  SwiftUI's `@State` holds the value a spring was aimed at, not the value it is
//  interpolating through, and several of these components need the latter: upstream reads
//  a live motion value when it re-aims something mid flight, so that a change arriving
//  during an animation continues from where the thing actually is rather than from where
//  it was last sent. An `Animatable` modifier can write each frame's value here as it
//  renders, which makes it readable again from an event handler.
//

import Foundation

/// A single number, written by an animation as it passes through and read back later.
///
/// It holds no observable state, so writing to it during a layout pass invalidates
/// nothing and cannot loop.
///
/// The unchecked conformance is safe rather than convenient: this is only ever read and
/// written from a view's layout and body, which SwiftUI runs on the main actor. It cannot
/// be main actor isolated instead, because `Animatable.animatableData` is not, and a
/// modifier holding an isolated reference would carry that isolation into the conformance.
final class RareUILiveValue: @unchecked Sendable {
    /// The value the animation last rendered.
    var value: Double

    /// Creates a live value.
    ///
    /// - Parameter value: The value to start at.
    init(_ value: Double = 0) {
        self.value = value
    }
}
