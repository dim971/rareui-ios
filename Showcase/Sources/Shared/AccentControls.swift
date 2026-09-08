import SwiftUI

/// A row of accent swatches, shown above every list of samples.
struct AccentControls: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 8) {
            Text("Accent")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(ShowcaseSettings.accents, id: \.name) { choice in
                    Button {
                        withAnimation(.snappy) { settings.accent = choice.colour }
                    } label: {
                        Circle()
                            .fill(choice.colour)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .strokeBorder(.primary, lineWidth: 2)
                                    .padding(-3)
                                    .opacity(settings.accent == choice.colour ? 1 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.name)
                }
                Spacer()
            }
        }
        .padding(16)
    }
}
