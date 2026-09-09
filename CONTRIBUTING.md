# Contributing

Thanks for taking a look. Issues and pull requests are both welcome.

## Getting set up

```sh
git clone https://github.com/dim971/rareui-ios
cd rareui-ios
make test          # the numeric goldens
make showcase      # build and run the catalog app in the simulator
```

You need Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`); the showcase project is generated from
`Showcase/project.yml` rather than checked in.

Xcode 26 rather than 16 because the compiler in Xcode 16.4 crashes lowering one
of these components. It is a defect in that toolchain rather than in this code,
and it is recorded in [docs/fidelity.md](docs/fidelity.md).

## Before you open a pull request

```sh
make lint          # swiftformat --lint and swiftlint
make test
```

Three things the review will look for:

**No warnings.** Not in the package, not in the showcase, on the release
toolchain *and* the current Xcode beta. A warning that is tolerated becomes a
warning that is ignored.

**The motion still matches upstream.** Every spring, easing curve, delay and
threshold in this library came out of the upstream React source. If you change
one, say which upstream value you are now following, or say plainly that you
are deliberately departing from it and why. "It felt better" is a reason, but
it has to be written down, because the next person will otherwise read the
difference as a bug.

**Parity with Android.** This library has a
[twin](https://github.com/dim971/rareui-android). A change to shared behaviour
(a component's states, a theme value, an animation constant) should land in
both, or say plainly why it should not.

## Conventions

[docs/coding-style.md](docs/coding-style.md) is the full version: the
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
as they apply here, plus the handful of places this project deliberately
differs. The short version:

- Comments explain *why*, not *what*. A constant that looks arbitrary almost
  certainly came from upstream, so say which file it came from.
- Every public declaration carries a doc comment. SwiftLint enforces it.
- Animation constants live in named properties, not scattered through call
  sites, so the value can be compared against upstream in one place.
- Commit messages describe the change and the reasoning, in prose.

## Reporting a bug

Motion problems are hard to describe in words. A screen recording, or the
exact prop values you passed, turns "the animation looks wrong" into something
anyone can reproduce. Saying what it does on rareui.com instead is even better.

## Code of conduct

Taking part means following the [Code of Conduct](CODE_OF_CONDUCT.md).
