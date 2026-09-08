//
//  RareUI.swift
//  A SwiftUI port of Rare UI (https://www.rareui.com), by Swami Malode, MIT licensed.
//
//  The port's contract is written down in CLAUDE.md and docs/fidelity.md: every
//  spring, easing curve, delay and threshold in this module is read out of the
//  upstream React source rather than matched by eye, and any deliberate departure
//  is recorded rather than left to be discovered.
//

import Foundation

/// The version of this library, as it appears in the git tag that shipped it.
///
/// It is here so an application can report which build of the components it is
/// running, which is the first thing worth knowing when a motion bug is filed.
public enum RareUI {
    /// The current version, matching the repository's most recent tag.
    public static let version = "0.1.0"
}
