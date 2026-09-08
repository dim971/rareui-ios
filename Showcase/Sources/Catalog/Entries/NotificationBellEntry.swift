import RareUI
import SwiftUI

@MainActor
let notificationBellEntry = CatalogEntry(
    "Notification Bell",
    summary: "A bell that swings when its count goes up, with a clapper that trails behind it.",
    demos: [
        Demo(
            "Ring it",
            note: """
            Nothing is tapped: the arrival of a notification is the event. The bell is \
            pushed the way it is already moving, so several arriving at once make it swing \
            harder rather than starting the swing again.
            """,
            code: """
            NotificationBell(count: unread)
            """
        ) { BellDemo() },

        Demo(
            "A dot instead of a number",
            code: """
            NotificationBell(count: unread, variant: .dot, color: .blue)
            """
        ) { BellDemo(variant: .dot, color: .blue) },

        Demo(
            "Colours and sizes",
            note: "Everything about the bell is a fraction of its size, so it holds together at any of them.",
            code: """
            NotificationBell(count: 3, size: 64, color: .violet)
            """
        ) {
            HStack(spacing: 18) {
                NotificationBell(count: 3, size: 36, color: .green)
                NotificationBell(count: 12, size: 48, color: .orange)
                NotificationBell(count: 128, size: 64, color: .violet)
            }
        }
    ]
) {
    NotificationBell(count: 3, size: 40)
}

private struct BellDemo: View {
    var variant: NotificationBellVariant = .count
    var color: NotificationBellColor = .red

    @State private var unread = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NotificationBell(count: unread, variant: variant, color: color)

            HStack(spacing: 10) {
                Button("One more") { unread += 1 }
                Button("Five at once") { unread += 5 }
                Button("Read them") { unread = 0 }
                Spacer()
            }
            .buttonStyle(.bordered)
            .font(.subheadline)
        }
    }
}
