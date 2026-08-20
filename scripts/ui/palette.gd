class_name Palette
extends RefCounted
## Every colour in the game, in one place.
##
## The game is greyscale apart from a single accent. Keeping the values here
## rather than re-declaring them per script is what makes that checkable:
## `scripts/check-constraints.sh` fails on any colour literal anywhere in the
## project that is neither grey nor exactly `ACCENT`.
##
## If you need a new shade, add it here and say why. If you need a new *hue*,
## you are proposing a second accent — see DESIGN.md §9 before you do.

## Ink on paper.
const INK: Color = Color(0.106, 0.106, 0.106)
const PAPER: Color = Color(0.965, 0.961, 0.949)
const RULE: Color = Color(0.788, 0.784, 0.773)
const MUTED: Color = Color(0.545, 0.541, 0.529)

## The cubicle wall the calendar hangs on.
const WALL: Color = Color(0.929, 0.925, 0.914)
const WALL_GRAIN: Color = Color(0.882, 0.878, 0.867)
const WALL_SEAM: Color = Color(0.839, 0.835, 0.824)

## The UI band across the top, and text on it.
const BAND: Color = Color(0.106, 0.106, 0.106)
const BAND_TEXT: Color = Color(0.965, 0.961, 0.949)
const BAND_MUTED: Color = Color(0.549, 0.545, 0.533)

const SHADOW: Color = Color(0, 0, 0, 0.18)

## The one accent: pale blue. It means **points** — everywhere they come from,
## everything they cost, and the two buttons that spend them. A holiday on a
## page, the note that pops up when one is collected, a price in the store,
## Start and Buy It. Nothing that is not about points may wear it.
##
## It is pale by design, which makes it a poor colour for small text on paper:
## against PAPER it is about 1.6:1, well under readable. Small holiday numbers
## therefore get a pale blue *cell* with ink on top, while the big display
## numbers — a day 128px tall, a price at 32 — are set in it directly, where
## size carries the legibility that contrast does not.
const ACCENT: Color = Color(0.647, 0.784, 0.855)
