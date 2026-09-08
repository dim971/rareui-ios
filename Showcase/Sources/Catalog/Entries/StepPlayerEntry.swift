import RareUI
import SwiftUI

@MainActor
let stepPlayerEntry = CatalogEntry(
    "Step Player",
    summary: "A row of dots where the current one stretches into a bar and fills as it plays.",
    demos: [
        Demo(
            "Play it",
            note: """
            Play turns into pause by morphing rather than by swapping: the two bars slide \
            together and shear into the triangle. Replay crossfades, because there is no \
            sensible way to morph a curled arrow into either of the others.
            """,
            code: """
            StepPlayer(steps: 5, index: $step, playing: $playing, duration: 3)
            """
        ) { StepPlayerDemo(steps: 5, duration: 3) },

        Demo(
            "Seekable",
            note: "Each step gets a hit target at least forty-four points tall, however small the track is.",
            code: """
            StepPlayer(steps: 6, index: $step, playing: $playing, seekable: true)
            """
        ) { StepPlayerDemo(steps: 6, duration: 2, seekable: true) },

        Demo(
            "Sizes and sides",
            note: "Every measurement is a fraction of the track's height, so the proportions hold.",
            code: """
            StepPlayer(steps: 4, index: $step, playing: $playing, size: 28)
            StepPlayer(steps: 4, index: $step, playing: $playing, controlPosition: .leading)
            """
        ) {
            VStack(alignment: .leading, spacing: 16) {
                StepPlayerDemo(steps: 4, duration: 3, size: 28)
                StepPlayerDemo(steps: 4, duration: 3, size: 40, controlPosition: .leading)
            }
        }
    ]
) {
    StepPlayerPreview()
}

private struct StepPlayerDemo: View {
    let steps: Int
    let duration: Double
    var size: Double = 48
    var seekable = false
    var controlPosition: StepPlayerControlPosition = .trailing

    @State private var step = 0
    @State private var playing = false

    var body: some View {
        StepPlayer(
            steps: steps,
            index: $step,
            playing: $playing,
            duration: duration,
            loop: true,
            size: size,
            controlPosition: controlPosition,
            seekable: seekable
        )
    }
}

private struct StepPlayerPreview: View {
    @State private var step = 1
    @State private var playing = false

    var body: some View {
        StepPlayer(steps: 4, index: $step, playing: $playing, size: 22, showsControl: false)
    }
}
