//
//  OTPInputTests.swift
//  What a code field will accept, checked against the `PATTERNS` table and the paste and
//  autofill handling in `components/ui/otp-input.tsx`.
//

@testable import RareUI
import Testing

@Suite("OTP character sets")
struct OTPCharacterSetTests {
    @Test("digits take digits and nothing else")
    func numbers() {
        #expect(OTPCharacterSet.numbers.accepts("0"))
        #expect(OTPCharacterSet.numbers.accepts("9"))
        #expect(!OTPCharacterSet.numbers.accepts("a"))
        #expect(!OTPCharacterSet.numbers.accepts("-"))
    }

    @Test("letters take either case and no digits")
    func letters() {
        #expect(OTPCharacterSet.letters.accepts("a"))
        #expect(OTPCharacterSet.letters.accepts("Z"))
        #expect(!OTPCharacterSet.letters.accepts("4"))
    }

    @Test("the mixed set takes both")
    func alphanumeric() {
        #expect(OTPCharacterSet.alphanumeric.accepts("a"))
        #expect(OTPCharacterSet.alphanumeric.accepts("7"))
        #expect(!OTPCharacterSet.alphanumeric.accepts("_"))
    }

    @Test("only plain ASCII counts, so a digit from another script is not a digit here")
    func ascii() {
        // Upstream's patterns are [0-9] and [a-zA-Z], which these are. Accepting an Arabic
        // Indic digit would put a character in the box that the code will never match.
        #expect(!OTPCharacterSet.numbers.accepts("\u{0660}"))
        #expect(!OTPCharacterSet.letters.accepts("é"))
    }
}

@Suite("What a code field accepts")
struct OTPAcceptanceTests {
    @Test("anything that does not belong is dropped rather than refused")
    func filters() {
        // This is what lets a pasted or autofilled code arrive with its own punctuation
        // and still land in the boxes.
        #expect(otpAccepted("123-456", length: 6, characterSet: .numbers) == "123456")
        #expect(otpAccepted("Code: 4821", length: 6, characterSet: .numbers) == "4821")
        #expect(otpAccepted("a1b2", length: 6, characterSet: .letters) == "ab")
    }

    @Test("the code is cut to the length of the row")
    func truncates() {
        #expect(otpAccepted("123456789", length: 6, characterSet: .numbers) == "123456")
        #expect(otpAccepted("12", length: 6, characterSet: .numbers) == "12")
    }

    @Test("nothing usable leaves nothing")
    func empty() {
        #expect(otpAccepted("", length: 6, characterSet: .numbers).isEmpty)
        #expect(otpAccepted("hello", length: 6, characterSet: .numbers).isEmpty)
    }

    @Test("a nonsensical length yields nothing rather than trapping")
    func guardedLength() {
        #expect(otpAccepted("123", length: 0, characterSet: .numbers).isEmpty)
        #expect(otpAccepted("123", length: -4, characterSet: .numbers).isEmpty)
    }
}

@Suite("OTP sizes")
struct OTPSizeTests {
    @Test("everything about a box grows together")
    func proportions() {
        var previous: OTPSize?
        for size in [OTPSize.small, .medium, .large] {
            if let previous {
                #expect(size.box > previous.box)
                #expect(size.radius > previous.radius)
                #expect(size.fontSize > previous.fontSize)
                #expect(size.caretHeight > previous.caretHeight)
                #expect(size.gap > previous.gap)
            }
            previous = size
        }
    }

    @Test("the caret is shorter than the box it sits in")
    func caretFits() {
        for size in OTPSize.allCases {
            #expect(size.caretHeight < size.box)
        }
    }
}
