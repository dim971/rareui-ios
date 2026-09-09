import RareUI
import SwiftUI

@MainActor
let gridRevealEntry = CatalogEntry(
    "Grid Reveal",
    summary: "A placeholder that becomes a picture by dividing itself into it.",
    demos: [
        Demo(
            "Waiting, then arriving",
            note: """
            With no picture yet the grid creeps to nine tenths and holds, so a wait that \
            runs long still looks like work. When one arrives the busiest parts of it come \
            apart first.
            """,
            code: """
            GridReveal(image: photo, caption: "Generating")
            """
        ) { GridRevealDemo() },

        Demo(
            "Driven by progress",
            note: "Give it a progress and it follows that instead of pacing itself.",
            code: """
            GridReveal(image: photo, progress: job.progress)
            """
        ) { GridRevealProgressDemo() }
    ]
) {
    GridReveal(image: SampleImage.stripes, progress: 0.55)
        .frame(width: 74, height: 74)
}

private struct GridRevealDemo: View {
    @State private var image: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GridReveal(image: image, caption: image == nil ? "Generating" : nil)
                .frame(maxWidth: 280)

            Button(image == nil ? "Finish it" : "Start again") {
                image = image == nil ? SampleImage.stripes : nil
            }
            .buttonStyle(.bordered)
            .font(.subheadline)
        }
    }
}

private struct GridRevealProgressDemo: View {
    @State private var progress = 0.4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GridReveal(image: SampleImage.stripes, progress: progress)
                .frame(maxWidth: 280)
            Slider(value: $progress)
        }
    }
}

/// Something to reveal, drawn rather than shipped, so the showcase carries no assets.
private enum SampleImage {
    static let stripes: CGImage? = {
        let size = 512
        guard
            let context = CGContext(
                data: nil,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        // A gradient with a bright, busy band across the middle, so the ordering pass has
        // something to prefer and the reveal visibly starts there.
        for y in 0 ..< size {
            let t = Double(y) / Double(size)
            context.setFillColor(
                red: 0.15 + 0.7 * t,
                green: 0.25 + 0.3 * (1 - t),
                blue: 0.65 - 0.4 * t,
                alpha: 1
            )
            context.fill(CGRect(x: 0, y: y, width: size, height: 1))
        }
        for band in stride(from: 180, to: 320, by: 14) {
            context.setFillColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
            context.fill(CGRect(x: 0, y: band, width: size, height: 6))
        }
        return context.makeImage()
    }()
}
