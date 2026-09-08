import RareUI
import SwiftUI

@MainActor
let fluidOrbEntry = CatalogEntry(
    "Fluid Orb",
    summary: "A circle of colour that looks like it is being stirred.",
    demos: [
        Demo(
            "Leave it alone",
            note: """
            There is nothing to interact with. Two drifts of unrelated period stir the \
            noise, so it never settles into a loop you can catch.
            """,
            code: """
            FluidOrb()
            """
        ) { FluidOrb(size: 220) },

        Demo(
            "Any colour",
            note: "The colour is where the fluid settles at its darkest; the light comes from white.",
            code: """
            FluidOrb(size: 120, color: .purple)
            """
        ) {
            HStack(spacing: 16) {
                FluidOrb(size: 110, color: Color(hex: "#FC4C01"))
                FluidOrb(size: 110, color: Color(hex: "#34C759"))
                FluidOrb(size: 110, color: Color(hex: "#AF52DE"))
            }
        }
    ]
) {
    FluidOrb(size: 72)
}
