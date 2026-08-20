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
## you are proposing a second accent — see DESIGN.md §8 before you do.

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

## The one accent: pale blue, and only on the store's buy button. It marks the
## single action in the game that spends something, which is the one place
## worth pulling the eye to.
const ACCENT: Color = Color(0.647, 0.784, 0.855)
