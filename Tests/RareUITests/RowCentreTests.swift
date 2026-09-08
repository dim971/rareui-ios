//
//  RowCentreTests.swift
//  The measurements a list keeps of where its own rows are.
//

@testable import RareUI
import Testing

@Suite("Row measurements")
@MainActor
struct RowCentreTests {
    @Test("a row that has not been laid out yet has no position")
    func unmeasured() {
        let centres = RareUIRowCentres()
        #expect(centres[0] == nil)
    }

    @Test("a measurement is kept and can be read back")
    func recorded() {
        let centres = RareUIRowCentres()
        centres.record(42, for: 1)
        #expect(centres[1] == 42)
    }

    @Test("shortening the list forgets the rows that went with it")
    func trimmed() {
        let centres = RareUIRowCentres()
        for index in 0 ..< 5 {
            centres.record(Double(index) * 10, for: index)
        }
        centres.trim(to: 2)
        #expect(centres[1] == 10)
        #expect(centres[2] == nil)
        #expect(centres[4] == nil)
    }
}
