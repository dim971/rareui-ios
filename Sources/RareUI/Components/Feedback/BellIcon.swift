//
//  BellIcon.swift
//  The bell itself, quoted from the two SVG paths in upstream's
//  `components/ui/notification-bell.tsx`.
//

import SwiftUI

/// The bell, drawn in two parts so the clapper can lag behind the body.
struct BellIcon: View {
    /// How far the bell has swung, in degrees.
    let swing: Double
    /// How far the clapper has swung relative to it, in degrees.
    let clapper: Double
    /// The ink both parts are drawn in.
    let color: Color

    /// The bell's body. The dome and the rim, at 55% opacity so the clapper reads through it.
    private static let body = SVGShape(
        """
        M3.5 6.5C3.5 3.46279 5.96279 1 9 1C12.0372 1 14.5 3.46279 14.5 6.5V10.75C14.5 \
        11.4408 15.0592 12 15.75 12C16.1642 12 16.5 12.3358 16.5 12.75C16.5 13.1642 \
        16.1642 13.5 15.75 13.5H2.25C1.83579 13.5 1.5 13.1642 1.5 12.75C1.5 12.3358 \
        1.83579 12 2.25 12C2.94079 12 3.5 11.4408 3.5 10.75V6.5Z
        """,
        viewBox: CGSize(width: 18, height: 18)
    )

    /// The clapper, hanging below the rim.
    private static let tongue = SVGShape(
        """
        M10.2 15H7.80099C7.64999 15 7.50799 15.068 7.41299 15.185C7.31799 15.302 \
        7.28099 15.456 7.31199 15.603C7.48499 16.425 8.17999 17 9.00099 17C9.82199 17 \
        10.517 16.425 10.69 15.603C10.721 15.456 10.684 15.302 10.589 15.185C10.494 \
        15.068 10.351 15 10.2 15Z
        """,
        viewBox: CGSize(width: 18, height: 18)
    )

    var body: some View {
        ZStack {
            Self.body
                .fill(color.opacity(0.55))
            Self.tongue
                .fill(color)
                // The clapper turns about its own top edge rather than the bell's, which is
                // upstream's `transformBox: fill-box` with an origin of 50% 0%.
                .rotationEffect(.degrees(clapper), anchor: Self.tongueAnchor)
        }
        // The bell hangs from its crown. Turning it about the middle looks like a spinning
        // object rather than a swinging one, which is why upstream sets 50% 12%.
        .rotationEffect(.degrees(swing), anchor: UnitPoint(x: 0.5, y: 0.12))
        .accessibilityHidden(true)
    }

    /// The top middle of the clapper, in the icon's unit space.
    @MainActor
    private static var tongueAnchor: UnitPoint {
        let bounds = SVGPath.cached(tongue.d).boundingRect
        return tongue.unitPoint(CGPoint(x: bounds.midX, y: bounds.minY))
    }
}
