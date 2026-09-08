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
repository ports them to SwiftUI: every spring, easing curve, delay and
magic number is read out of the upstream React source rather than matched by
eye, so a component here moves the way the same component moves on
rareui.com.

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Components](#components)
- [Contributing](#contributing)
- [Credits](#credits)
- [Licence](#licence)

## Requirements

iOS 17+ or macOS 14+, Swift 6, Xcode 16+. No dependencies.

iOS 17 is the floor because `FluidOrb` renders through a Metal shader reached
with SwiftUI's `colorEffect`, which arrived in that release.

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

## Components

The port is in progress. Components land one at a time, each with its tests,
its showcase screen and its reference entry; this table is filled in as they
arrive.

## Contributing

Issues and pull requests are both welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for how to build, test and what the review
looks for. Everyone taking part is expected to follow the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Credits

**[Rare UI](https://www.rareui.com) is by [Swami Malode](https://github.com/swamimalode07)**.
The components, the motion and the look are his.
[`swamimalode07/rare-ui`](https://github.com/swamimalode07/rare-ui) is the
original, and worth reading: the animation constants in it are unusually
deliberate, which is what makes a faithful port possible at all.

This repository is a port. It contributes a Swift transcription, the fixtures
that keep the numeric parts honest, and the SwiftUI plumbing around them.

## Licence

MIT. See [LICENSE](LICENSE). Upstream Rare UI is (c) 2026 Swami Malode, also
MIT; [NOTICE](NOTICE) records the attribution in full.
