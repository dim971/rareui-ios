import RareUI
import SwiftUI

@MainActor
let durationPickerEntry = CatalogEntry(
    "Duration Picker",
    summary: "Three touching squircles that separate to be edited, and a pen that becomes a tick.",
    demos: [
        Demo(
            "Set a duration",
            note: """
            Pressing the pen opens the fields and morphs it into a tick. The morph is a \
            real one: both outlines are walked, sampled to the same number of points, and \
            slid across.
            """,
            code: """
            DurationPicker(value: $duration) { confirmed in
                schedule(for: confirmed)
            }
            """
        ) { DurationPickerDemo() },

        Demo(
            "Its own limits",
            note: """
            Typing past the limit clamps the field and gives it a nudge, so the refusal is \
            felt rather than read.
            """,
            code: """
            DurationPicker(value: $duration, maxHours: 8, maxMinutes: 59)
            """
        ) { DurationPickerDemo(maxHours: 8, maxMinutes: 59, hours: 2, minutes: 30) }
    ]
) {
    DurationPickerPreview()
}

private struct DurationPickerDemo: View {
    var maxHours = 24
    var maxMinutes = 60
    var hours = 1
    var minutes = 15

    @State private var duration = DurationValue()
    @State private var confirmed: DurationValue?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DurationPicker(value: $duration, maxHours: maxHours, maxMinutes: maxMinutes) {
                confirmed = $0
            }
            Text(confirmed.map { "Confirmed \($0.hours)h \($0.minutes)m" } ?? "Not set yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { duration = DurationValue(hours: hours, minutes: minutes) }
    }
}

private struct DurationPickerPreview: View {
    @State private var duration = DurationValue(hours: 1, minutes: 30)

    var body: some View {
        DurationPicker(value: $duration)
            .scaleEffect(0.6)
            .frame(width: 110, height: 30)
    }
}
