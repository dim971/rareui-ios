<div align="center">

# Rare UI for SwiftUI

**A SwiftUI port of [Rare UI](https://www.rareui.com), the animated component
registry by [Swami Malode](https://github.com/swamimalode07), MIT licensed.**

Nineteen components that are worth the frame budget: orbs that drift and
listen, letters that fall and pile up, a bell that swings from its crown and
drags its clapper behind it.

[![CI](https://github.com/dim971/rareui-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/dim971/rareui-ios/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-lightgrey.svg)](#requirements)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](#installation)
[![Licence](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)

</div>

The components, their look and their motion are Swami Malode's work. This
repository ports them to SwiftUI: every spring, easing curve, delay and magic
number is read out of the upstream React source rather than matched by eye, so
a component here moves the way the same component moves on rareui.com. Where
that was not possible, it is written down rather than left to be discovered.
See [Fidelity](#fidelity).

```swift
AnimatedCounter(value: total, prefix: "$")
```

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Components](#components)
- [Theming](#theming)
- [Motion and accessibility](#motion-and-accessibility)
- [Fidelity](#fidelity)
- [Showcase app](#showcase-app)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Credits](#credits)
- [Licence](#licence)

## Requirements

iOS 17+ or macOS 14+, Swift 6, Xcode 26+. No dependencies, and there will not
be any.

iOS 17 is the floor because `FluidOrb` renders through a Metal shader reached
with SwiftUI's `colorEffect`, which arrived in that release. Xcode 26 is the
floor because the compiler in Xcode 16.4 crashes lowering one of these
components, which is a defect in that toolchain rather than in this code.

## Installation

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/dim971/rareui-ios", from: "0.1.0"),
]
```

Or in Xcode: **File > Add Package Dependencies...** and paste the URL.

```swift
import RareUI
```

## Quick start

```swift
import RareUI
import SwiftUI

struct ContentView: View {
    @State private var tab = 0
    @State private var code = ""
    @State private var unread = 3

    var body: some View {
        VStack(spacing: 32) {
            GooeyNav(items: ["Home", "Docs", "Pricing"], selection: $tab)

            OTPInput(code: $code) { code in
                verify(code)
            }

            NotificationBell(count: unread)
        }
        .rareUITheme { theme in
            theme.accent = .indigo
        }
    }
}
```

## Components

All nineteen, grouped as rareui.com groups them.

| Component | What it is |
| --- | --- |
| `AnimatedCounter` | An odometer. Each digit is a wheel of eleven faces, the tenth being a second zero so the wrap from nine forward to zero never travels backward. Direction aware, with places that roll in as the number grows. |
| `CodeBlock` | Source in a framed panel with a gutter and a copy button. The whole syntax theme is eleven shades of one accent, and a light appearance is the same ramp upside down. Knows Swift, Kotlin, TypeScript, JSON and shell. |
| `FolderComponent` | A folder whose flap tips back and whose contents fan out of it, in three states: at rest, under a pointer, and open. |
| `GitHubActivity` | A contribution heatmap that draws itself a column at a time, with a footer that lifts up over the grid and becomes a ranked list. |
| `GravityLetters` | Letters that fall out of your finger and pile up. Hold to pour, drag to steer, tilt the device to make the heap slide. No physics engine: a height map eight points wide. |
| `StepPlayer` | A row of dots where the current one stretches into a bar and fills. Play morphs into pause; every measurement is a fraction of the track's height. |
| `FluidOrb` | A circle of colour being stirred, by a Metal transliteration of upstream's fragment shader. |
| `GridReveal` | A placeholder that becomes a picture by dividing itself into it, busiest parts first. Paces itself when there is nothing to show yet. |
| `MatrixOrb` | A grid of dots that breathes, ripples or thinks. The three states crossfade, so an interruption blends from what is on screen. |
| `BounceSidebar` | A list with a dot in the gutter that arcs between rows, swinging out by the same amount whatever the distance. |
| `GooeyNav` | A segmented bar whose selected tile detaches, stretching the seams until they part. The seam is a drawn pair of curves, not a filter. |
| `HookSidebar` | A rail down the gutter that stops at the current row and hooks into it, with a second rail that follows a pointer. |
| `ProximitySidebar` | A page outline as dashes that swell as a pointer passes. On a phone the dash being read swells instead. |
| `ScrollProgress` | A floating pill of reading progress that opens into the page's sections, with a highlight that travels between them. |
| `DeleteButton` | A bin that opens into its own confirmation. The lid overshoots its open angle and the walls redraw shorter as it lifts. |
| `DurationPicker` | Three touching squircles that separate to be edited, and a pen that morphs into a tick. |
| `OTPInput` | A row of boxes for a one time code, with characters that roll in and a caret that slides. Autofill, paste and dictation all work. |
| `EmojiReaction` | A bar of emoji, and five copies of the one you pick drifting up the screen. Hold to keep sending them. |
| `NotificationBell` | A bell that rings when its count goes up, harder when several arrive at once, with a clapper that trails behind it. |

Full reference: [docs/components.md](docs/components.md).

## Theming

`RareUITheme` collects the palette upstream repeats by hand, and travels through
the environment the way its CSS custom properties cascade.

| Property | Default | What it does |
| --- | --- | --- |
| `surface` | `#F4F4F9` / `#262626` | The raised ground almost every component sits on |
| `surfaceRecessed` | `#E7E7EF` / `#1B1B1B` | The ground a raised control sinks into |
| `foreground` | `#0A0A0A` / `#FAFAFA` | Text and icons at full strength |
| `glyph` | `#868593` / `#9B9AA7` | Inactive glyphs and labels |
| `accent` | `#FC4C01` | What a selection is marked in |
| `track` | `#3C3C43` / `#EBEBF5` | The filled part of a track |
| `red` `orange` `green` `blue` `violet` | Apple's system colours | Semantic ink |

```swift
VStack { ... }
    .rareUITheme { theme in
        theme.accent = .purple
    }
```

More in [docs/theming.md](docs/theming.md).

## Motion and accessibility

Motion for React and SwiftUI describe springs the same way, which is what makes
this port checkable: `{ stiffness, damping, mass }` is
`.interpolatingSpring(mass:stiffness:damping:)`, `{ duration, bounce }` is
`.spring(duration:bounce:)`, and a CSS cubic bezier is `.timingCurve`. Every
constant in this library is upstream's, with a comment saying which file it came
from.

Four components integrate a spring by hand instead, and each has a reason. The
bell is pushed rather than aimed, and SwiftUI cannot be given a starting
velocity. The matrix orb's spring feeds a draw call rather than a view property.
The counter and the bounce sidebar need the value an animation is passing
through, not the one it was aimed at, so a change arriving mid flight continues
from where the thing actually is.

`accessibilityReduceMotion` is honoured everywhere, the way upstream honours
`prefers-reduced-motion`: transitions become instant, the canvas components draw
a single still frame, and nothing freezes mid-animation. A component that stops
where it happens to be rather than settling is a bug.

Every component carries labels, values and traits, and the ones that draw rather
than lay out hide their drawing from VoiceOver and describe themselves instead.

## Fidelity

The claim this library makes is that its motion is upstream's, by value rather
than by eye. That is only worth something if the exceptions are written down,
so [docs/fidelity.md](docs/fidelity.md) lists all of them: what could not come
across, why, and what was done instead.

The parts that can be checked exactly are checked: two hundred and nineteen
tests covering the grouping arithmetic, the field functions, the gooey seam's
waist, the gravity height map, the path morph, the tokeniser and the rest. None
of them assert that an animation looks right. They assert the things that can be
wrong without looking wrong.

## Showcase app

A catalog app listing every component with a live preview, a screen per component
showing its variants with copyable code, and an accent picker that restyles the
whole set at once.

```sh
make showcase      # generate, build and run it in the simulator
```

It opens straight to one screen if you name it, which is what makes the
screenshots reproducible:

```sh
xcrun simctl launch booted io.github.dim971.rareui.showcase -component "Gravity Letters"
```

## Documentation

| Document | What it covers |
| --- | --- |
| [Getting started](docs/getting-started.md) | Installing, the first component, the patterns |
| [Components](docs/components.md) | Every component, its parameters and its behaviour |
| [Theming](docs/theming.md) | The theme, the component colours, the motion vocabulary |
| [Fidelity](docs/fidelity.md) | Every departure from upstream, and why |
| [Architecture](docs/architecture.md) | How a component is put together, and the shared core |
| [Coding style](docs/coding-style.md) | The conventions, and which of them a machine enforces |

## Contributing

Issues and pull requests are both welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
for how to build, test and what the review looks for. Everyone taking part is
expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Credits

**[Rare UI](https://www.rareui.com) is by [Swami Malode](https://github.com/swamimalode07)**.
The components, the motion and the look are his.
[`swamimalode07/rare-ui`](https://github.com/swamimalode07/rare-ui) is the
original, and worth reading: the animation constants in it are unusually
deliberate, which is what makes a faithful port possible at all.

This repository is a port. It contributes a Swift transcription, the tests that
keep the numeric parts honest, and the SwiftUI plumbing around them.

## Licence

MIT. See [LICENSE](LICENSE). Upstream Rare UI is (c) 2026 Swami Malode, also
MIT; [NOTICE](NOTICE) records the attribution in full.
