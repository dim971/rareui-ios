//
//  RareUITests.swift
//  The suites in this target cover the parts of the port that are pure maths and
//  therefore checkable exactly: colour ramps, easing, layout arithmetic and the
//  physics solvers. Motion that can only be judged by eye is checked in the
//  showcase against rareui.com, not here.
//

@testable import RareUI
import Testing

@Suite("Package")
struct PackageTests {
    @Test("the reported version matches the tag this library ships under")
    func version() {
        #expect(RareUI.version == "0.1.0")
    }
}
