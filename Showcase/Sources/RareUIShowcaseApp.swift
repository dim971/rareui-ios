import SwiftUI

@main
struct RareUIShowcaseApp: App {
    @State private var settings = ShowcaseSettings()

    var body: some Scene {
        WindowGroup {
            TabView {
                CatalogHomeScreen()
                    .tabItem { Label("Catalog", systemImage: "square.grid.2x2") }
                AboutScreen()
                    .tabItem { Label("About", systemImage: "info.circle") }
            }
            .environment(settings)
        }
    }
}
