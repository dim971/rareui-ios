//
//  FolderComponent.swift
//  A port of upstream's `components/ui/folder-component.tsx`.
//
//  A folder whose flap tips back and whose contents fan out of it. There are three states
//  rather than two: at rest, under a pointer, and open. On a phone only the first and the
//  last are reachable, which is what a tap toggles between.
//

import SwiftUI

/// How large a ``FolderComponent`` is drawn.
public enum FolderSize: String, Sendable, CaseIterable {
    /// Two thirds of the drawing's own size.
    case small
    /// The size it was drawn at.
    case medium
    /// A third again larger.
    case large

    var scale: Double {
        switch self {
        case .small: 0.65
        case .medium: 1
        case .large: 1.35
        }
    }
}

/// Which of upstream's three folders to draw.
public enum FolderColor: String, Sendable, CaseIterable {
    /// A black folder holding pale cards.
    case black
    /// A white folder holding dark cards.
    case white
    /// A blue folder holding pale cards.
    case blue

    var palette: FolderPalette {
        switch self {
        case .black:
            FolderPalette(
                back: .black,
                backInset: .white.opacity(0.37),
                flapFill: Color(hex: "#292929"),
                flapOpacity: 0.25,
                flapStroke: Color(hex: "#979797"),
                flapInset: .black.opacity(0.08),
                cardFill: Color(hex: "#F1F1F1"),
                cardStroke: Color(hex: "#E0E0E0"),
                cardLine: Color(hex: "#D4D4D4"),
                cardInset: .white
            )
        case .white:
            FolderPalette(
                back: .white,
                backInset: Color(hex: "#B2B2B2").opacity(0.25),
                flapFill: Color(hex: "#F5F5F5"),
                flapOpacity: 0.85,
                flapStroke: Color(hex: "#D4D4D4"),
                flapInset: Color(hex: "#999999").opacity(0.15),
                cardFill: Color(hex: "#262626"),
                cardStroke: Color(hex: "#404040"),
                cardLine: Color(hex: "#737373"),
                cardInset: .white.opacity(0.15)
            )
        case .blue:
            FolderPalette(
                back: Color(hex: "#50B1FD"),
                backInset: .white.opacity(0.35),
                flapFill: Color(hex: "#3A9AE8"),
                flapOpacity: 0.45,
                flapStroke: Color(hex: "#7EC8FF"),
                flapInset: .white.opacity(0.12),
                cardFill: Color(hex: "#F1F1F1"),
                cardStroke: Color(hex: "#E0E0E0"),
                cardLine: Color(hex: "#D4D4D4"),
                cardInset: .white
            )
        }
    }
}

/// A folder whose flap tips back and whose contents fan out of it.
///
/// ```swift
/// FolderComponent(color: .blue, size: .large)
/// ```
///
/// Tapping it opens and closes it. A pointer passing over it lifts the cards part of the
/// way, which is a state a phone never reaches and upstream never reaches either.
///
/// Under Reduce Motion the states change without springing.
public struct FolderComponent: View {
    private let color: FolderColor
    private let size: FolderSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hovering = false
    @State private var open = false

    /// The drawing's own size, which everything else is stated in.
    private static let base = CGSize(width: 321, height: 270)
    /// The flap's size, which is shorter than the folder so the cards show above it.
    private static let flapSize = CGSize(width: 321, height: 241)

    /// The cards' spring, from upstream.
    private static var cardSpring: Animation {
        .rareUISpring(stiffness: 120, damping: 13)
    }

    /// The flap's, which is damped very slightly harder.
    private static var flapSpring: Animation {
        .rareUISpring(stiffness: 120, damping: 14)
    }

    /// Creates a folder.
    ///
    /// - Parameters:
    ///   - color: Which of the three folders to draw.
    ///   - size: How large to draw it.
    public init(color: FolderColor = .black, size: FolderSize = .medium) {
        self.color = color
        self.size = size
    }

    private var palette: FolderPalette {
        color.palette
    }

    private var state: FolderState {
        open ? .open : hovering ? .hovering : .rest
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(palette.back.shadow(.inner(color: palette.backInset, radius: 6)))
                .frame(width: Self.base.width, height: Self.base.height)

            cards
            // Upstream blurs whatever is behind the flap, which is what turns the cards
            // under it into soft shapes while the tips above it stay sharp. A SwiftUI
            // material cannot do this: it samples the window rather than the sibling
            // underneath it. Drawing the cards a second time, blurred and masked to the
            // flap's own outline, is the same effect by a different route.
            cards
                .blur(radius: 6)
                .mask { flapOutline { FolderFlap().fill(.black) } }
            flap
        }
        .frame(width: Self.base.width, height: Self.base.height)
        .scaleEffect(size.scale)
        .frame(width: Self.base.width * size.scale, height: Self.base.height * size.scale)
        .contentShape(.rect)
        .onTapGesture { open.toggle() }
        .onHover { inside in
            hovering = inside
            // Leaving closes it, exactly as upstream's mouse leave does, so a folder never
            // stays open behind the pointer.
            if !inside { open = false }
        }
        .accessibilityElement()
        .accessibilityLabel("Folder")
        .accessibilityValue(open ? "Open" : "Closed")
        .accessibilityAddTraits(.isButton)
    }

    private var cards: some View {
        ZStack {
            ForEach(FolderCardPlacement.all) { placement in
                FolderCard(palette: palette)
                    .offset(
                        x: placement.offset(in: state).x,
                        y: placement.offset(in: state).y
                    )
                    .rotationEffect(.degrees(placement.rotation(in: state)))
                    .animation(cardAnimation(for: placement), value: state)
            }
        }
    }

    private var flap: some View {
        flapOutline {
            FolderFlap()
                .fill(palette.flapFill.opacity(palette.flapOpacity))
                .overlay {
                    FolderFlap()
                        .stroke(palette.flapStroke, lineWidth: 1)
                }
        }
    }

    /// Places something where the flap is, tipped back by however far it is open.
    ///
    /// Both the flap itself and the mask that blurs the cards behind it have to sit in
    /// exactly the same place, so the transform is written once.
    private func flapOutline(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(width: Self.flapSize.width, height: Self.flapSize.height)
            // The flap hangs from its own bottom edge, which is the fold.
            .rotation3DEffect(
                .degrees(state.flapAngle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                // CSS states perspective as a distance and SwiftUI as a fraction of the
                // view, so upstream's 800 pixels against a 321 point flap is this.
                perspective: Self.flapSize.width / 800
            )
            .offset(y: 16)
            .animation(reduceMotion ? nil : Self.flapSpring, value: state)
    }

    private func cardAnimation(for placement: FolderCardPlacement) -> Animation? {
        guard !reduceMotion else { return nil }
        return Self.cardSpring.delay(placement.delay(in: state))
    }
}

/// Which of the three states the folder is in.
enum FolderState: Equatable {
    case rest
    case hovering
    case open

    /// How far the flap has tipped back, in degrees.
    var flapAngle: Double {
        switch self {
        case .rest: -15
        case .hovering: -45
        case .open: -55
        }
    }
}

/// Where one card sits in each state.
///
/// The three fan out rather than stacking: one to the right leaning right, one in the
/// middle almost straight, one to the left leaning left. Opening lifts all three clear of
/// the folder and exaggerates the fan.
struct FolderCardPlacement: Identifiable {
    /// Where a card sits and how far it leans, in one of the three states.
    struct Pose: Equatable {
        let x: Double
        let y: Double
        let rotation: Double
    }

    let id: Int
    private let rest: Pose
    private let hovering: Pose
    private let open: Pose
    private let openDelay: Double
    private let hoverDelay: Double

    /// The three cards, in the order they are drawn: the rightmost first, so the leftmost
    /// ends up on top.
    static let all = [
        FolderCardPlacement(
            id: 1,
            rest: Pose(x: 40, y: -10, rotation: 10),
            hovering: Pose(x: 40, y: -30, rotation: 14),
            open: Pose(x: 70, y: -160, rotation: 18),
            openDelay: 0.1,
            hoverDelay: 0.12
        ),
        FolderCardPlacement(
            id: 2,
            rest: Pose(x: 3, y: -20, rotation: 2),
            hovering: Pose(x: 3, y: -35, rotation: -1),
            open: Pose(x: 0, y: -180, rotation: -3),
            openDelay: 0.05,
            hoverDelay: 0.06
        ),
        FolderCardPlacement(
            id: 3,
            rest: Pose(x: -40, y: -22, rotation: -5),
            hovering: Pose(x: -40, y: -44, rotation: -9),
            open: Pose(x: -65, y: -170, rotation: -14),
            openDelay: 0,
            hoverDelay: 0
        )
    ]

    /// Where the card sits in a given state.
    ///
    /// - Parameter state: The folder's state.
    /// - Returns: The card's pose.
    func pose(in state: FolderState) -> Pose {
        switch state {
        case .rest: rest
        case .hovering: hovering
        case .open: open
        }
    }

    func offset(in state: FolderState) -> Pose {
        pose(in: state)
    }

    func rotation(in state: FolderState) -> Double {
        pose(in: state).rotation
    }

    /// The cards leave in turn rather than together, and the one furthest from the middle
    /// leaves first, so the fan opens outward.
    func delay(in state: FolderState) -> Double {
        switch state {
        case .open: openDelay
        case .hovering: hoverDelay
        case .rest: 0
        }
    }
}

/// The folder's front flap, quoted from upstream's `FLAP_PATH`.
///
/// A rounded rectangle with a step cut into its top edge, which is the tab a paper folder
/// has, drawn as one path rather than assembled from parts.
struct FolderFlap: Shape {
    func path(in rect: CGRect) -> Path {
        SVGShape(
            """
            M0 25C0 11.1929 11.1929 0 25 0H136.084C143.044 0 149.689 2.90139 154.42 \
            8.00608L178.08 33.5343C182.811 38.639 189.456 41.5404 196.416 41.5404H296C309.807 \
            41.5404 321 52.7333 321 66.5404V216C321 229.807 309.807 241 296 241H25C11.1929 \
            241 0 229.807 0 216V25Z
            """,
            viewBox: CGSize(width: 321, height: 241),
            preservesAspectRatio: false
        )
        .path(in: rect)
    }
}
