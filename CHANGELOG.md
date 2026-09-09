# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]

First release. A SwiftUI port of [Rare UI](https://www.rareui.com), the animated
component registry by Swami Malode.

### Added

- All nineteen components from rareui.com, grouped as it groups them.
  - Display: `AnimatedCounter`, `CodeBlock`, `FolderComponent`, `GitHubActivity`,
    `GravityLetters`, `StepPlayer`.
  - AI Kit: `FluidOrb`, `GridReveal`, `MatrixOrb`.
  - Navigation: `BounceSidebar`, `GooeyNav`, `HookSidebar`, `ProximitySidebar`,
    `ScrollProgress`.
  - Inputs: `DeleteButton`, `DurationPicker`, `OTPInput`.
  - Feedback: `EmojiReaction`, `NotificationBell`.
- `RareUITheme`, carrying the palette upstream repeats by hand through the
  environment, and `RareUIMotion`, carrying the curves it reaches for repeatedly.
- A shared core with no UI in it: colour and HSL arithmetic, a cubic bezier
  solver, an SVG path reader, a path morph standing in for flubber, a spring
  integrated by hand, and the row measurements several components need.
- A showcase catalog app with live examples, copyable code and an accent picker
  that restyles the whole set. It opens straight to one component when named.
- Two hundred and nineteen tests over the parts that can be checked exactly.

### Changed from upstream

The full list is in [docs/fidelity.md](docs/fidelity.md). The ones worth knowing
about before reaching for a component:

- Nothing in this library touches the network. `GitHubActivity` and `GridReveal`
  take their data as values rather than fetching it, so an application decides
  what is loaded and when.
- `OTPInput` is backed by one text field rather than one per box, which is what
  makes one time code autofill, paste and dictation work. Upstream's arrow key
  editing in the middle of a code goes with it.
- `EmojiReaction` draws the system emoji rather than downloading Apple's artwork,
  and takes any emoji rather than the five whose file names upstream ships.
- `ScrollProgress` and `ProximitySidebar` take the scroll progress and the
  current section rather than listening for them, because a SwiftUI component
  cannot reach into somebody else's scroll view.
- `StepPlayer` states durations in seconds rather than milliseconds.
- `CodeBlock` uses an in-house highlighter covering Swift, Kotlin, TypeScript,
  JSON and shell, rather than Prism. Its palette, which is the part that makes
  the component what it is, is ported exactly.
- The pointer effects in `HookSidebar` and `ProximitySidebar` need a pointer, so
  they appear on a Mac or an iPad with a trackpad and never on a phone. Both
  carry the fallback upstream already wrote.

### Known limitations

- `FluidOrb` needs Xcode to build it. `swift build` on the command line copies
  the Metal source into the module bundle rather than compiling it.
- Xcode 26 or later is required. The compiler in Xcode 16.4 crashes lowering
  `EmojiReaction`, which is a defect in that toolchain rather than in this code.

[Unreleased]: https://github.com/dim971/rareui-ios/compare/0.1.0...HEAD
[0.1.0]: https://github.com/dim971/rareui-ios/releases/tag/0.1.0
