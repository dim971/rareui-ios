import Foundation

/// Where the catalog should open.
///
/// Nineteen components have to be looked at one at a time, and a simulator cannot be
/// tapped from a script. Passing the component's name at launch opens straight to its
/// screen, which is what makes the screenshots in `docs/` reproducible:
///
/// ```sh
/// xcrun simctl launch booted io.github.dim971.rareui.showcase -component "Animated Counter"
/// ```
enum ShowcaseLaunch {
    /// The navigation path the catalog starts on, empty unless a component was named.
    static var initialPath: [String] {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let flag = arguments.firstIndex(of: "-component"),
            arguments.index(after: flag) < arguments.endIndex
        else { return [] }
        return [arguments[arguments.index(after: flag)]]
    }
}
