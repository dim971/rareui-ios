# Getting started

## Requirements

iOS 17 or later, or macOS 14 or later. Swift 6. Xcode 26 or later.

iOS 17 is the floor because `FluidOrb` renders through a Metal shader reached with
SwiftUI's `colorEffect`, which arrived in that release. Every other component would run
happily on iOS 16.

Xcode 26 is the floor for a duller reason: the compiler in Xcode 16.4 crashes lowering one
of these components, which is a defect in that toolchain rather than in this code. It is
recorded in [fidelity.md](fidelity.md).

## Installing

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/dim971/rareui-ios", from: "0.1.0"),
]
```

Or in Xcode: **File > Add Package Dependencies...** and paste the URL.

There are no other dependencies, and there will not be.

## The first component

```swift
import RareUI
import SwiftUI

struct Total: View {
    @State private var value = 1234.0

    var body: some View {
        AnimatedCounter(value: value, prefix: "$")
            .font(.system(size: 40, weight: .semibold))
            .onTapGesture { value += 111 }
    }
}
```

Every component takes its state as a binding or a value and reports changes back. None of
them own a navigation stack, reach the network or read the screen.

## Patterns worth knowing

**Selection is a binding.** The navigation components take `selection: Binding<Int>` or
`Binding<String?>` and call back when something is picked. There is also an uncontrolled
initialiser on most of them, for when the component's own state is all you need.

```swift
GooeyNav(items: ["Home", "Docs", "Pricing"], selection: $tab)
GooeyNav(items: ["Home", "Docs", "Pricing"], defaultSelection: 0) { picked in ... }
```

**Data is given, not fetched.** `GitHubActivity` takes contributions, `GridReveal` takes an
image. Loading them is the application's business, which means it can be cached, retried,
previewed and tested.

**Scrolling is the host's.** `ScrollProgress` takes the progress and the current section
and reports a tap. `ProximitySidebar` is the same. The showcase has a worked example of the
host side of both.

**Colour comes from the theme.** Anything that takes a colour defaults to the theme's, so
one override restyles the set. See [theming.md](theming.md).

**Reduced motion is handled.** Every component degrades under `accessibilityReduceMotion`,
and none of them freeze mid-animation: they settle. See
[Motion and accessibility](../README.md#motion-and-accessibility).

## The showcase

```sh
git clone https://github.com/dim971/rareui-ios
cd rareui-ios
make showcase
```

Every component, with live examples and the code for each. It opens straight to one screen
if you name it:

```sh
xcrun simctl launch booted io.github.dim971.rareui.showcase -component "Gravity Letters"
```
