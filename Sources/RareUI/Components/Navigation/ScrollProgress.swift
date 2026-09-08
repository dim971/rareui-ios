//
//  ScrollProgress.swift
//  A port of upstream's `components/ui/scroll-progress.tsx`.
//
//  A floating pill that shows how far down a page you are and which part of it you are
//  reading. Tapping it opens into a list of the parts.
//
//  One difference in shape, recorded in docs/fidelity.md. Upstream listens to the window's
//  scroll itself and finds sections by their element id. A SwiftUI component cannot reach
//  into somebody else's scroll view, so this takes the progress and the current section as
//  values and reports a tap back. That is the same division of labour SwiftUI's own
//  scrolling API uses, and it makes the component work over anything that scrolls rather
//  than only over the document.
//

import SwiftUI

/// One part of the page a ``ScrollProgress`` can point at.
public struct ScrollProgressSection: Identifiable, Hashable, Sendable {
    /// The section's identifier, which is what a selection reports back.
    public let id: String
    /// The name shown for it.
    public let label: String

    /// Creates a section.
    ///
    /// - Parameters:
    ///   - id: The section's identifier.
    ///   - label: The name to show.
    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

/// A floating pill showing reading progress, which opens into the page's sections.
///
/// ```swift
/// ScrollProgress(sections: sections, progress: read, selection: $section) { id in
///     proxy.scrollTo(id, anchor: .top)
/// }
/// ```
///
/// Under Reduce Motion the pill changes size and swaps its contents without a duration.
public struct ScrollProgress: View {
    private let sections: [ScrollProgressSection]
    private let progress: Double
    @Binding private var selection: String?
    private let onSelect: ((String) -> Void)?

    @Environment(\.rareUITheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var open = false
    @Namespace private var highlight

    /// The pill's change of size, from upstream's `SIZE_SPRING`.
    private static var sizeSpring: Animation {
        .spring(duration: 0.5, bounce: 0.16)
    }

    /// The corner radius once it has opened into a list.
    private static var openRadius: Double {
        26
    }

    /// A row's corner radius.
    private static var rowRadius: Double {
        14
    }

    /// Creates a progress pill.
    ///
    /// - Parameters:
    ///   - sections: The parts of the page, in order.
    ///   - progress: How far down the page the reader is, in `0...1`.
    ///   - selection: The section being read. Set it as the reader scrolls.
    ///   - onSelect: Called when a section is picked, so the host can scroll to it.
    public init(
        sections: [ScrollProgressSection],
        progress: Double,
        selection: Binding<String?>,
        onSelect: ((String) -> Void)? = nil
    ) {
        self.sections = sections
        self.progress = progress
        _selection = selection
        self.onSelect = onSelect
    }

    public var body: some View {
        Group {
            if open {
                list
            } else {
                pill
            }
        }
        .background {
            // A continuous corner is Apple's own squircle, which is what upstream reaches
            // for CSS's very new `corner-shape` to get.
            RoundedRectangle(cornerRadius: open ? Self.openRadius : 16, style: .continuous)
                .fill(theme.background.opacity(0.7))
                .background(
                    .ultraThinMaterial,
                    in: .rect(cornerRadius: open ? Self.openRadius : 16, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: open ? Self.openRadius : 16, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .animation(reduceMotion ? nil : Self.sizeSpring, value: open)
        .accessibilityElement(children: .contain)
    }

    private var pill: some View {
        Button {
            open = true
        } label: {
            HStack(spacing: 10) {
                ProgressRing(progress: progress, theme: theme, reduceMotion: reduceMotion)
                    .frame(width: 20, height: 20)
                Text(currentLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                    .fixedSize()
                    // A new section's name comes in on its own, rather than the old one
                    // sliding out of the way of it.
                    .id(currentLabel)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.animation(.rareUICurve(RareUIMotion.easeOutQuint, duration: 0.22))
                    )
            }
            .padding(.vertical, 6)
            .padding(.leading, 8)
            .padding(.trailing, 16)
        }
        .buttonStyle(.plain)
        .transition(layerTransition)
        .accessibilityLabel("Show sections")
        .accessibilityValue(currentLabel)
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                row(section, at: index)
            }
        }
        .padding(6)
        .transition(layerTransition)
    }

    private func row(_ section: ScrollProgressSection, at index: Int) -> some View {
        let isActive = section.id == selection

        return Button {
            selection = section.id
            open = false
            onSelect?(section.id)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(isActive ? theme.foreground : theme.foreground.opacity(0.3))
                    .frame(width: 6, height: 6)
                Text(section.label)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 0)
            }
            .foregroundStyle(isActive ? theme.foreground : theme.foreground.opacity(0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isActive {
                    // One highlight that travels between the rows, rather than one per row
                    // fading in and out, which is what upstream's shared layout id gives it.
                    RoundedRectangle(cornerRadius: Self.rowRadius, style: .continuous)
                        .fill(theme.foreground.opacity(0.1))
                        .matchedGeometryEffect(id: "active", in: highlight)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .modifier(RowArrival(
            delay: reduceMotion ? 0 : 0.04 + Double(index) * 0.03,
            reduceMotion: reduceMotion
        ))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    /// The two layers cross under a blur rather than a straight fade, which is what stops
    /// the swap reading as one thing being replaced by another.
    private var layerTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .opacity
            .combined(with: .rareUIBlur(4))
            .animation(.rareUICurve(RareUIMotion.easeInOut, duration: 0.24))
    }

    private var currentLabel: String {
        sections.first { $0.id == selection }?.label ?? sections.first?.label ?? ""
    }
}

/// The ring around the pill's progress.
private struct ProgressRing: View {
    let progress: Double
    let theme: RareUITheme
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(theme.foreground.opacity(0.15), lineWidth: 2.5)
            Circle()
                .inset(by: 1.25)
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(theme.foreground, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                // Starting at the top rather than at three o'clock, as upstream's -90
                // degree rotation on the whole svg does.
                .rotationEffect(.degrees(-90))
        }
        // A spring on the progress rather than a straight follow, so a flick of the scroll
        // does not make the ring jump.
        .animation(
            reduceMotion ? nil : .rareUISpring(stiffness: 120, damping: 30, mass: 0.3),
            value: progress
        )
    }
}

/// A row rising into place as the list opens.
private struct RowArrival: ViewModifier {
    let delay: Double
    let reduceMotion: Bool

    @State private var arrived = false

    func body(content: Content) -> some View {
        content
            .opacity(arrived ? 1 : 0)
            .offset(y: arrived ? 0 : 4)
            .blur(radius: arrived ? 0 : 3)
            .task {
                guard !reduceMotion else {
                    arrived = true
                    return
                }
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.rareUICurve(RareUIMotion.easeInOut, duration: 0.3)) { arrived = true }
            }
    }
}

/// Blurring a view on its way in or out.
///
/// SwiftUI has no blur transition of its own, and several of these components cross one
/// layer under another rather than simply fading between them.
struct RareUIBlurModifier: ViewModifier {
    let radius: Double

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

public extension AnyTransition {
    /// A transition that blurs a view on its way in and out.
    ///
    /// - Parameter radius: How blurred it is at the far end, in points.
    /// - Returns: The transition.
    static func rareUIBlur(_ radius: Double) -> AnyTransition {
        .modifier(
            active: RareUIBlurModifier(radius: radius),
            identity: RareUIBlurModifier(radius: 0)
        )
    }
}
