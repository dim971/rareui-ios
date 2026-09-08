import RareUI
import SwiftUI

@MainActor
let matrixOrbEntry = CatalogEntry(
    "Matrix Orb",
    summary: "A grid of dots that breathes, ripples or thinks, depending on what it is doing.",
    demos: [
        Demo(
            "The three states",
            note: """
            Switching does not cut: the states crossfade, so an interruption blends from \
            whatever is on screen.
            """,
            code: """
            MatrixOrb(state: .listening)
            """
        ) { MatrixOrbStates() },

        Demo(
            "Driven by a level",
            note: """
            With a level of your own the listening ripple follows it. Without one, the orb \
            synthesises a breath.
            """,
            code: """
            MatrixOrb(state: .listening, level: microphone.level)
            """
        ) { MatrixOrbLevel() },

        Demo(
            "Grid and size",
            note: """
            The outline stays round because dots past 1.12 from the middle are dropped, \
            rather than the square's own 1.41 corner.
            """,
            code: """
            MatrixOrb(state: .thinking, size: 140, dots: 7)
            """
        ) {
            HStack(spacing: 20) {
                MatrixOrb(state: .thinking, size: 120, dots: 7)
                MatrixOrb(state: .thinking, size: 120, dots: 15)
            }
        }
    ]
) {
    MatrixOrb(state: .thinking, size: 84, dots: 9, labels: [.thinking: ""])
}

/// The three states behind a picker, which is the only way to see them blend.
private struct MatrixOrbStates: View {
    @State private var state: MatrixOrbState = .idle

    var body: some View {
        VStack(spacing: 16) {
            MatrixOrb(state: state, size: 200)

            Picker("State", selection: $state) {
                ForEach(MatrixOrbState.allCases, id: \.self) { state in
                    Text(state.rawValue.capitalized).tag(state)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// A level under the reader's thumb, standing in for a microphone.
private struct MatrixOrbLevel: View {
    @State private var level = 0.5

    var body: some View {
        VStack(spacing: 16) {
            MatrixOrb(state: .listening, level: level, size: 200)

            HStack {
                Text("Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $level)
            }
        }
    }
}
