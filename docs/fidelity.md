# Fidelity

Every spring, easing curve, delay, threshold and magic number in this library was read out
of `swamimalode07/rare-ui`'s `components/ui/*.tsx` rather than matched by eye. That is the
claim the whole port rests on, and it is only worth anything if the places where it is not
true are written down. This is that list.

Nothing here is an accident. Each entry is a decision, and each says why.

## What could not come across unchanged

**FluidOrb: the shader is compiled by Xcode, not by `swift build`.** The GLSL is
transliterated to Metal and is otherwise identical. But `swift build` on the command line
copies a `.metal` file into the module bundle rather than running the Metal compiler, so
the orb draws in anything Xcode has built and not in a bare command line build. Every
other component works either way.

**AnimatedCounter: the face box is opened out by a quarter.** Upstream draws each digit in
a box `1.5em` tall, which leaves enough air above and below the glyph that the mask's fade
never touches it. SwiftUI's line box is nearer `1.2em`, so the measured height is
multiplied by 1.25 to put the glyph back in the clear. Without it the fade reaches into the
digit and a resting number looks smudged.

**OTPInput: one text field behind the row, not one per box.** Upstream gives every box its
own input, because on the web that is the only way to put a caret in a particular box, and
it then reimplements most of a text field on top. Here the row is backed by a single field
with the boxes drawn over it, which is what makes the platform behave: one time code
autofill offers the code straight from a message, paste works, dictation works. The price
is upstream's arrow key editing in the middle of a code, which has no equivalent on a touch
keyboard anyway.

**EmojiReaction: the emoji are text.** Upstream loads Apple's artwork from a CDN, because a
browser on Windows would otherwise draw something else entirely. On an Apple platform that
artwork is the system font. It removes a network dependency and lets a caller pass any
emoji rather than the five whose file names upstream ships.

**EmojiReaction: the bar is not clamped to the window.** Upstream shifts the bar sideways
to keep it on screen. Reading the screen from inside a component makes it behave wrongly in
a split view or on a Mac, and the alignment parameter is the SwiftUI answer to the same
question. The bar does still flip above or below the trigger depending on the room.

**EmojiReaction: no press-and-drag from the trigger.** Upstream lets you press the trigger,
drag along the bar and release over an emoji. That is a pointer idiom needing a gesture
that spans views.

**HookSidebar and ProximitySidebar: the pointer effects need a pointer.** Both appear on a
Mac or an iPad with a trackpad and never on a phone. Upstream has the same limitation for
the same reason, and both components already carry the fallback upstream wrote: the hook
sidebar shows only the accent rail, and the proximity sidebar swells the dash for whatever
is being read.

**GooeyNav, HookSidebar and BounceSidebar: no route syncing.** Upstream reads Next.js's
pathname to work out which item is current. Selection is a binding here.

**StepPlayer: durations are seconds.** Upstream states them in milliseconds. Every other
duration in this library and in SwiftUI is a number of seconds, and one that is not would
be a trap rather than a faithfulness.

**StepPlayer and DurationPicker: the icon morphs are hand-authored.** Upstream uses flubber
to interpolate between arbitrary paths. For the play triangle and the pause bars there is
no need: split the triangle down its middle and its two halves correspond to the two bars
corner for corner, which is exact rather than approximate. For the pen and the tick there
is no such correspondence, so `PathMorph` does what flubber does, by walking both outlines,
sampling the same number of evenly spaced points along each, and lining the two rings up.
Replay is left out of the morph exactly as upstream leaves it out.

**DurationPicker: the sway is taken from direction rather than from velocity.** Upstream
reads the gap's own velocity and maps it to a three point lean, so the contents lag behind
the opening. There is no velocity to read from a SwiftUI animation, so the lean is taken
from the direction of travel and carried by the same spring. It comes out the same at both
ends and slightly gentler in between.

**GitHubActivity: it takes data, it does not fetch it.** Upstream can fetch a year of
contributions from a public API given a username. A view that makes its own requests cannot
be tested, cannot be previewed offline, and gives an application no say over caching,
failure or timing. Nothing in this library reaches the network.

**GitHubActivity: the year scrolls rather than being trimmed.** Upstream fits the columns
to the card, because a web page is as wide as the window and a year always fits. A
component on a phone is as wide as it is given, and quietly dropping months would change
what the grid says.

**GridReveal: it takes an image, not a URL.** For the same reason.

**ScrollProgress: progress and the current section are supplied.** Upstream listens to the
window's scroll and finds sections by element id. A SwiftUI component cannot reach into
somebody else's scroll view, and one that tried would work in exactly one arrangement.

**FolderComponent: the placeholder lines are level.** Upstream draws every one of them with
a transform matrix carrying a skew of about two thousandths of a degree, the residue of
whatever drew the original artwork. It is a fifth of a pixel across the whole card.

**FolderComponent: the backdrop blur is drawn rather than filtered.** A SwiftUI material
samples the window rather than the sibling underneath it, so over a black folder on a white
page it comes out pale grey and the folder loses its depth. The cards are drawn a second
time, blurred and masked to the flap's outline, which is the same effect by a different
route.

**CodeBlock: the highlighter is not Prism.** Upstream uses a library that knows nearly
three hundred languages. Taking on something comparable would break the rule this library
and its Android twin both hold to, which is that they have no dependencies at all. What a
component gallery shows is a handful of languages, so this covers Swift, Kotlin,
TypeScript, JSON and shell, and falls back to plain text rather than guessing. The palette,
which is the part that makes the component what it is, is ported exactly.

**EmojiReaction: the component is split into named parts to survive a compiler.** Swift
6.1.2 crashes in SILGen lowering this component when its body is one large expression, and
again when a view is stored inside another view as a generic parameter. Neither is a
mistake in the code, but both are worked around, because a library that cannot be compiled
is not a library. Both changes are improvements anyway.

## What is checked rather than trusted

Two hundred and nineteen tests, and none of them assert that an animation looks right.
They assert the things that can be wrong without looking wrong:

- the counter's grouping, padding, rounding and wheel aiming
- the matrix orb's field functions, their ranges, and that its synthesised level has no
  corner in it
- the gooey seam's waist, and which seams open at all
- the bounce dot's arc, and that its swing is the same size at every distance
- the hook rail's geometry
- the bell's ring: its weighting, its cap, and that it pushes the way it is already going
- the emoji burst's keyframe reader, and that a copy leans the way it wanders
- the delete button's bin walls
- the gravity height map: stacking, sliding, walls, and slopes
- the path morph, including that it never pinches through itself
- the step player's proportions and its play to pause morph
- the folder's three states
- the heatmap's levels and week arithmetic
- the grid reveal's subdivision, its ordering, and its pacing
- the code block's tokeniser, including that the tokens joined back together are exactly
  the source that went in
- the SVG path reader, against the real paths this library quotes

Everything else is checked by eye, in the showcase, against rareui.com.
