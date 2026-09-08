//
//  FluidOrb.swift
//  A port of upstream's `components/ui/fluid-orb.tsx`.
//
//  A circle filled with something that looks like it is being stirred. Upstream renders it
//  with a WebGL fragment shader; this renders the same shader in Metal, reached through
//  SwiftUI's `colorEffect`. The maths is unchanged, so this is the closest thing in the
//  library to a byte for byte port: see Sources/RareUI/Shaders/FluidOrb.metal.
//

import SwiftUI

/// A circle of slowly drifting colour.
///
/// ```swift
/// FluidOrb()
/// FluidOrb(size: 160, color: .purple)
/// ```
///
/// Under Reduce Motion it renders a single still frame, taken at the moment the shader
/// would have started, which is what upstream does under `prefers-reduced-motion`.
///
/// - Note: The shader is compiled into the package's own bundle by Xcode. Building the
///   package with `swift build` on the command line copies the Metal source rather than
///   compiling it, so the orb only draws in something Xcode has built. Every other
///   component in this library works either way.
public struct FluidOrb: View {
    private let size: Double
    private let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    /// Creates an orb.
    ///
    /// - Parameters:
    ///   - size: The orb's diameter, in points. Defaults to `240`.
    ///   - color: The colour the fluid settles to at its darkest. Defaults to upstream's blue.
    public init(size: Double = 240, color: Color = Color(hex: "#1A73F2")) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        Group {
            if reduceMotion {
                orb(at: 0)
            } else {
                TimelineView(.animation) { timeline in
                    orb(at: timeline.date.timeIntervalSince(start))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func orb(at time: TimeInterval) -> some View {
        // The shader replaces every pixel, including deciding where the orb ends, so what
        // is underneath it only has to be something the whole frame's worth of.
        Rectangle()
            .fill(.white)
            .colorEffect(
                ShaderLibrary.bundle(.module).rareUIFluidOrb(
                    .float2(Float(size), Float(size)),
                    .float(Float(time)),
                    .color(color)
                )
            )
    }
}
