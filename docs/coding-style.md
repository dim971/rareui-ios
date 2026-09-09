# Coding style

The [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
apply, and the places this project deliberately differs are below.

## Prose

British English, in comments, documentation and commit messages.

Comments explain **why**, not what. A constant that looks arbitrary almost certainly came
from upstream, so the comment says which file it came from.

**No em dash.** Not in code, comments, documentation, commit messages or issue and pull
request text. Use a comma, a colon, a semicolon, parentheses or a full stop. CI fails the
build if the character appears anywhere in the repository.

## Naming

Public names read as English: `AnimatedCounter(value:decimals:duration:)`, not
`AnimatedCounter(v:d:dur:)`. Where upstream's prop name is already the right word, it is
kept, so that the two can be read side by side.

Free functions that belong to one component are prefixed with it: `gridRevealSelfPaced`,
`bellClapperLag`, `counterFormat`. They are internal, they are tested, and the prefix is
what keeps a file of them legible.

Short identifiers are allowed where the maths uses them: `uv`, `dt`, `x`, `t`. The linter is
configured for it. Anywhere else, a name is a word.

## Animation

Constants are named properties on the type that uses them, never literals at a call site:

```swift
/// The roll, from upstream's `ROLL_SPRING`.
private static var roll: Animation { .rareUISpring(stiffness: 500, damping: 34) }
```

Two numbers at a call site cannot be checked against anything. A named property with a
citation can.

Motion for React maps to SwiftUI directly, and the mapping is written down in
`Theme/Motion.swift`:

- `{ stiffness, damping, mass }` is `.interpolatingSpring(mass:stiffness:damping:)`
- `{ duration, bounce }` is `.spring(duration:bounce:)`
- `ease: [a, b, c, d]` is `.timingCurve(a, b, c, d)`

## Testing

Tests are named as sentences that state a claim:

```swift
@Test("the bell cannot be made to spin, however many arrive")
```

They test the things that can be wrong without looking wrong. There is no point asserting
that a spring is a spring; there is every point asserting that the grouping is right, that
the arc is the same size at every distance, and that a morph never pinches through itself.

Where a test encodes something subtle, the comment says what would break if it failed.

## Commits

Commit messages describe the change and the reasoning, in prose. The subject is an
imperative sentence with no type or scope prefix; the body says why, what was rejected, and
how it was verified.

## What is enforced mechanically

| Rule | By what |
| --- | --- |
| Formatting, line width, wrapping | `swiftformat --lint` |
| Doc comments on public declarations | SwiftLint's `missing_docs` |
| Line length, file length, complexity | SwiftLint |
| No em dash | A `git grep` at the top of every CI run |
| No warnings | A clean rebuild, with the log checked |
| The maths | The test suite |

Everything else in this document is a review conversation.
