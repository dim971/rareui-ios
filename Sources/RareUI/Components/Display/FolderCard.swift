//
//  FolderCard.swift
//  The sheets inside FolderComponent, ported from the `Card` component in upstream's
//  `components/ui/folder-component.tsx`.
//
//  A rounded card with a heading bar and eight rows of two columns of placeholder text.
//  Upstream draws each line as its own SVG rect with a transform matrix carrying a skew of
//  about two thousandths of a degree, which is the residue of whatever drew the original.
//  The lines are level here, which is a difference of a fifth of a pixel across the card.
//

import SwiftUI

/// One sheet of paper inside a folder.
struct FolderCard: View {
    let palette: FolderPalette

    /// The card's own drawing size, from upstream's `viewBox="0 0 164 214"`.
    static let size = CGSize(width: 164, height: 214)

    /// The heading bar: wider than the body lines and twice their height.
    private static let heading = CGRect(x: 14.1193, y: 31.2091, width: 134.84, height: 11.8892)
    /// Where the body lines start, and how far apart they are.
    private static let firstLine = 60.9939
    private static let lineSpacing = 14.1183
    private static let lineCount = 9
    private static let lineWidth = 64.5183
    private static let lineHeight = 5.88276
    private static let leftColumn = 14.8253
    private static let rightColumn = 84.4303

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    palette.cardFill.shadow(
                        // The inner shadow upstream builds out of a blur and a composite,
                        // offset down and to the right so the card looks lit from above.
                        .inner(color: palette.cardInset, radius: 3.05, x: 3, y: 5)
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(palette.cardStroke, lineWidth: 1)
                }

            Capsule()
                .fill(palette.cardLine)
                .frame(width: Self.heading.width, height: Self.heading.height)
                .offset(x: Self.heading.minX, y: Self.heading.minY)

            ForEach(0 ..< Self.lineCount, id: \.self) { row in
                let y = Self.firstLine + Double(row) * Self.lineSpacing
                Group {
                    line.offset(x: Self.leftColumn, y: y)
                    line.offset(x: Self.rightColumn, y: y)
                }
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var line: some View {
        Capsule()
            .fill(palette.cardLine)
            .frame(width: Self.lineWidth, height: Self.lineHeight)
    }
}

/// The colours one folder is drawn in.
///
/// Upstream carries three of these, and each is a complete set rather than a tint: the
/// black folder holds pale cards, the white one holds dark cards, and the blue one holds
/// pale cards again.
struct FolderPalette {
    let back: Color
    let backInset: Color
    let flapFill: Color
    let flapOpacity: Double
    let flapStroke: Color
    let flapInset: Color
    let cardFill: Color
    let cardStroke: Color
    let cardLine: Color
    let cardInset: Color
}
