//
//  RowCentres.swift
//  Several components mark one row of a list with something drawn beside it: a dot that
//  travels, a rail that grows, a dash that swells. All of them need to know where each
//  row's middle is, and upstream gets that from `offsetTop + offsetHeight / 2` with a
//  ResizeObserver watching for it to change.
//
//  This is the same thing: each row reports its own middle in a named coordinate space,
//  and reports it again whenever layout moves it.
//

import SwiftUI

/// Where each row of a list sits, keyed by index.
///
/// A reference type so a row can write its own entry without the whole list re-rendering
/// on every measurement, and observable so the marker beside the list does re-render when
/// a position it is drawing against actually changes.
@Observable
@MainActor
public final class RareUIRowCentres {
    private var centres: [Int: Double] = [:]

    /// Creates an empty set of measurements.
    public init() {}

    /// The middle of a row, if it has been measured yet.
    ///
    /// - Parameter index: The row's index.
    /// - Returns: The row's vertical middle, or `nil` before it has been laid out.
    public subscript(index: Int) -> Double? {
        centres[index]
    }

    /// Records a row's middle.
    ///
    /// - Parameters:
    ///   - centre: The row's vertical middle.
    ///   - index: The row's index.
    func record(_ centre: Double, for index: Int) {
        // Writing the same value back would invalidate every reader for nothing, and these
        // are written from a layout pass that runs whenever anything moves.
        guard centres[index] != centre else { return }
        centres[index] = centre
    }

    /// Forgets rows that are no longer there, so a shortened list leaves nothing behind.
    ///
    /// - Parameter count: How many rows there now are.
    func trim(to count: Int) {
        centres = centres.filter { $0.key < count }
    }
}

/// The coordinate space rows are measured in.
///
/// Named rather than local because the measurement happens on the row and is read by a
/// sibling, and the two need to agree on an origin.
let rareUIRowSpaceName = "rareui.rowspace"

public extension View {
    /// Reports this row's vertical middle into a set of measurements.
    ///
    /// The list this row belongs to must carry ``SwiftUICore/View/rareUIRowSpace()``.
    ///
    /// - Parameters:
    ///   - index: The row's index.
    ///   - centres: Where to record the measurement.
    /// - Returns: A view that measures itself.
    func rareUIMeasureRow(_ index: Int, into centres: RareUIRowCentres) -> some View {
        background {
            GeometryReader { proxy in
                let centre = proxy.frame(in: .named(rareUIRowSpaceName)).midY
                Color.clear
                    .onAppear { centres.record(centre, for: index) }
                    .onChange(of: centre) { _, moved in centres.record(moved, for: index) }
            }
        }
    }

    /// Marks this view as the origin the rows inside it measure themselves against.
    ///
    /// - Returns: A view carrying the row coordinate space.
    func rareUIRowSpace() -> some View {
        coordinateSpace(.named(rareUIRowSpaceName))
    }
}
