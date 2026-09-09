# Theming

Upstream hardcodes its palette inside each component, as Tailwind classes: the same
`bg-[#F4F4F9] dark:bg-[#262626]` appears in a dozen files, along with the same `#868593`
grey and the same iOS system colours. Those values are collected here once, and they travel
down the environment the way upstream's CSS custom properties cascade.

Every default is the value the matching upstream component actually uses, so a view left
untouched looks like its counterpart on rareui.com.

## The theme

| Property | Default | What it is |
| --- | --- | --- |
| `surface` | `#F4F4F9` / `#262626` | The raised ground almost every component sits on |
| `surfaceRecessed` | `#E7E7EF` / `#1B1B1B` | The ground a raised control sinks into |
| `background` | white / `#0A0A0A` | The page behind the components |
| `foreground` | `#0A0A0A` / `#FAFAFA` | Text and icons at full strength |
| `glyph` | `#868593` / `#9B9AA7` | Inactive glyphs and labels |
| `border` | black and white at 8% | Hairlines |
| `accent` | `#FC4C01` | What a selection is marked in |
| `track` | `#3C3C43` / `#EBEBF5` | The filled part of a track |
| `red` `orange` `green` `blue` `violet` | Apple's system colours | Semantic ink |

Each is a single `Color` that resolves itself from the current appearance, so a component
inside a `Canvas` gets the right one without branching on the colour scheme.

## Changing it

```swift
VStack { ... }
    .rareUITheme { theme in
        theme.accent = .purple
    }
```

The closure receives the theme inherited from above, so an override is additive and a view
nested inside another override keeps the outer one's changes. To replace it outright:

```swift
VStack { ... }
    .rareUITheme(RareUITheme(accent: .purple, glyph: .secondary))
```

## Component colours

Most components also take a colour directly, which wins over the theme:

```swift
MatrixOrb(state: .listening, color: .mint)
GooeyNav(items: items, selection: $tab, activeColor: .indigo)
BounceSidebar(items: items, selection: $section, dotColor: .pink)
```

`CodeBlock` is the interesting one: it takes a single accent and derives an entire syntax
theme from it, keeping the hue and the saturation and replacing the lightness once per
token kind. A light appearance is the same ramp upside down. Eleven colours out of one, and
no table to drift.

```swift
CodeBlock(code: source, language: .swift, accent: .teal)
```

## Motion

`RareUIMotion` holds the curves upstream reaches for repeatedly, and the mapping between
Motion for React's spring spec and SwiftUI's:

```swift
.animation(.rareUISpring(stiffness: 520, damping: 30), value: open)
.animation(.rareUICurve(RareUIMotion.easeOutQuint, duration: 0.22), value: label)
```

Component specific constants deliberately do not live there. They live next to the
component that uses them, with a comment naming the upstream file, so a number can be
checked against the original in one place instead of two.
