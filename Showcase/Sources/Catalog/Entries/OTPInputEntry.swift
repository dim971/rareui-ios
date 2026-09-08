import RareUI
import SwiftUI

@MainActor
let otpInputEntry = CatalogEntry(
    "OTP Input",
    summary: "A row of boxes for a one time code, with characters that roll in and a caret that slides.",
    demos: [
        Demo(
            "Type a code",
            note: """
            Characters roll in from below. Deleting one sends it back down the way it came; \
            replacing one pushes it up and out of the top, so the two never look alike.
            """,
            code: """
            OTPInput(code: $code) { code in
                verify(code)
            }
            """
        ) { OTPDemo() },

        Demo(
            "Accepted and refused",
            note: """
            Success draws each box its own outline, a twentieth of a second apart, so the \
            green runs along the row. An error shakes the row once and turns it red.
            """,
            code: """
            OTPInput(code: $code, status: .success)
            OTPInput(code: $code, status: .error)
            """
        ) { OTPStatusDemo() },

        Demo(
            "Sizes and character sets",
            code: """
            OTPInput(code: $code, length: 4, characterSet: .alphanumeric, size: .large)
            OTPInput(code: $code, length: 4, size: .small, mask: true)
            """
        ) { OTPVariantsDemo() }
    ]
) {
    OTPInput(code: .constant("42"), length: 3, size: .small)
}

private struct OTPDemo: View {
    @State private var code = ""
    @State private var completed: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OTPInput(code: $code) { completed = $0 }
            Text(completed.map { "Completed: \($0)" } ?? "Waiting for six digits")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OTPStatusDemo: View {
    @State private var code = "123456"
    @State private var status: OTPStatus = .success

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            OTPInput(code: $code, status: status)
            Picker("Status", selection: $status) {
                ForEach(OTPStatus.allCases, id: \.self) { status in
                    Text(status.rawValue.capitalized).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct OTPVariantsDemo: View {
    @State private var letters = "AB"
    @State private var masked = "12"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OTPInput(code: $letters, length: 4, characterSet: .alphanumeric, size: .large)
            OTPInput(code: $masked, length: 4, size: .small, mask: true)
        }
    }
}
