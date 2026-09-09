# Components

All nineteen, grouped as [rareui.com](https://www.rareui.com/components) groups them. Every
default is upstream's own.

Anywhere a colour is not given, the component takes it from the theme; see
[theming.md](theming.md).

## Display

### AnimatedCounter

An odometer. Each digit is a wheel of eleven faces that turns to the digit it should show:
ten digits and a repeat of zero, so the wrap from nine back to zero continues forward onto
an identical face rather than travelling the long way round.

```swift
AnimatedCounter(value: total)
AnimatedCounter(value: revenue, decimals: 2, prefix: "$")
AnimatedCounter(value: population, grouping: .indian)
```

The roll is direction aware. Places that appear as the number grows roll in from zero;
places that disappear fade out. `padStart` sets a floor on the width, which is what stops a
timer jittering.

### CodeBlock

Source code in a framed panel, with a header, a line-number gutter and a copy button. The
entire syntax theme is built from one accent: the hue and saturation are kept, the lightness
is replaced per token kind, and a light appearance is the same ramp upside down.

```swift
CodeBlock(code: source, language: .swift, filename: "ContentView.swift")
CodeBlock(code: json, language: .json, accent: .teal, highlightedLines: [3, 4])
```

Knows Swift, Kotlin, TypeScript, JSON and shell, and falls back to plain text.

### FolderComponent

A folder whose flap tips back and whose contents fan out of it. Three states: at rest, under
a pointer, and open. A phone reaches the first and the last.

```swift
FolderComponent(color: .blue, size: .large)
```

### GitHubActivity

A contribution heatmap with a footer that lifts up over the grid and turns into a ranked
list of repositories. The grid draws itself a column at a time and the month labels resolve
out of a blur once it has finished.

```swift
GitHubActivity(contributions: days, repos: repositories, showsMonths: true)
```

It takes its data rather than fetching it.

### GravityLetters

Letters that fall out of your finger and pile up. Touch drops one, holding for a third of a
second pours them, dragging steers the pour, and tilting the device past ten degrees makes
the heap slide.

```swift
GravityLetters()
GravityLetters(items: ["★", "●", "▲"], gravity: 1400, size: 34)
```

### StepPlayer

A row of dots where the current one stretches into a bar and fills as it plays, with a
control beside it. Every measurement is a fraction of the track's height.

```swift
StepPlayer(steps: 5, index: $step, playing: $playing, duration: 3, seekable: true)
```

## AI Kit

### FluidOrb

A circle of colour that looks like it is being stirred, rendered by a Metal transliteration
of upstream's fragment shader. Nothing to interact with.

```swift
FluidOrb(size: 160, color: .purple)
```

### GridReveal

A placeholder that becomes a picture by dividing itself into it. The busiest parts of the
picture come apart first. Given no picture it paces itself, creeping toward nine tenths and
holding there.

```swift
GridReveal(image: photo, caption: "Generating")
GridReveal(image: photo, progress: job.progress)
```

### MatrixOrb

A grid of dots that breathes, ripples or thinks. Give it a level and the listening state
follows it; leave the level out and it synthesises one.

```swift
MatrixOrb(state: .listening, level: microphone.level)
MatrixOrb(state: .thinking, size: 140, dots: 7)
```

The three states crossfade rather than switching, so interrupting a change blends from
whatever is on screen.

## Navigation

### BounceSidebar

A list with a dot in the gutter that arcs from one row to the next, swinging out sideways
and back in by the same amount whatever the distance.

```swift
BounceSidebar(items: ["Overview", .heading("Reference"), "Components"], selection: $section)
```

### GooeyNav

A segmented bar whose selected tile detaches, stretching the seams either side of it until
they part. The seam is a drawn pair of curves rather than a blur filter.

```swift
GooeyNav(items: ["Home", "Docs", "Pricing"], selection: $tab)
GooeyNav(items: [GooeyNavItem("Inbox", systemImage: "tray")], selection: $tab, size: .large)
```

### HookSidebar

A rail down the gutter that stops at the current row and turns into it with a quarter-round
hook. A second, fainter rail follows a pointer where there is one.

```swift
HookSidebar(items: ["Overview", "Install"], selection: $section, label: "Docs")
```

### ProximitySidebar

A page outline drawn as dashes, which swell as a pointer passes them. On a phone the dash
for whatever is being read swells instead.

```swift
ProximitySidebar(sections: outline, side: .trailing, selection: $section) { id in
    proxy.scrollTo(id, anchor: .top)
}
```

### ScrollProgress

A floating pill showing how far down the reader is, which opens into the page's sections.
Takes the progress and reports a tap.

```swift
ScrollProgress(sections: sections, progress: read, selection: $section) { id in
    proxy.scrollTo(id, anchor: .top)
}
```

## Inputs

### DeleteButton

A bin that opens into its own confirmation rather than into a dialogue. The lid swings past
its open angle before settling, and the walls redraw shorter as it goes.

```swift
DeleteButton(onCancel: { keep() }, onConfirm: { remove() })
```

### DurationPicker

Three touching squircles that separate to be edited, and a pen that morphs into a tick.
Typing past a field's limit clamps it and gives it a nudge.

```swift
DurationPicker(value: $duration, maxHours: 8) { confirmed in schedule(for: confirmed) }
```

### OTPInput

A row of boxes for a one time code. Characters roll in from below, a caret slides from box
to box, and the row either shakes red or draws itself a green outline.

```swift
OTPInput(code: $code, status: status) { code in verify(code) }
OTPInput(code: $code, length: 4, characterSet: .alphanumeric, size: .large, mask: true)
```

One time code autofill, paste and dictation all work.

## Feedback

### EmojiReaction

A button that opens a bar of emoji. Picking one sends five copies drifting up the screen;
holding it keeps sending them.

```swift
EmojiReaction { emoji in post(reaction: emoji) }
EmojiReaction(emojis: ["🔥", "💯", "🎉"], size: .large, align: .leading)
```

### NotificationBell

A bell that rings when its count goes up. Nothing is tapped: the arrival is the event, and
several arriving at once make it swing harder rather than starting the swing again.

```swift
NotificationBell(count: unread)
NotificationBell(count: unread, variant: .dot, color: .blue, size: 64)
```
