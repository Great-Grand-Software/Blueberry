class_name Lettering
extends RefCounted
## Text drawing, in one place, so every readout in the game weighs the same.
##
## The engine's fallback font ships one weight, so "bolder" has to be faked:
## `draw_string_outline` in the same colour thickens every stroke before the
## glyph is drawn over it. That is what `weight` is — outline pixels, not a
## font family. It is used on the numbers the player is actually reading (the
## score, the year, a price) and left off body text, where it would just look
## muddy.
##
## Everything here is static and takes the canvas it draws into, so a Control
## calls it from its own `_draw()` without owning any state.

## Outline pixels for the standard "slightly bolder" readout weight.
const WEIGHT_BOLD: int = 1
## For the big display numbers, which can carry more.
const WEIGHT_HEAVY: int = 2


## Draws `text` with its left edge at `origin`, optionally thickened.
static func draw_at(
	canvas: CanvasItem,
	font: Font,
	origin: Vector2,
	text: String,
	font_size: int,
	color: Color,
	weight: int = 0
) -> void:
	if weight > 0:
		canvas.draw_string_outline(
			font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, weight, color
		)
	canvas.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


## Draws `text` centred inside a horizontal band.
static func draw_centred(
	canvas: CanvasItem,
	font: Font,
	band_left: float,
	band_width: float,
	baseline: float,
	text: String,
	font_size: int,
	color: Color,
	weight: int = 0
) -> void:
	var origin := Vector2(
		band_left + (band_width - width_of(font, text, font_size)) * 0.5, baseline
	)
	draw_at(canvas, font, origin, text, font_size, color, weight)


## Draws `text` with its right edge at `right`.
static func draw_right_of(
	canvas: CanvasItem,
	font: Font,
	right: float,
	baseline: float,
	text: String,
	font_size: int,
	color: Color,
	weight: int = 0
) -> void:
	var origin := Vector2(right - width_of(font, text, font_size), baseline)
	draw_at(canvas, font, origin, text, font_size, color, weight)


## How wide `text` renders at `font_size`. Kept here so callers measuring for
## layout and callers drawing agree on the answer.
static func width_of(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
