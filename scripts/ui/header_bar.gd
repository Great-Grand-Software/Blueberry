class_name HeaderBar
extends Control
## The score band across the top: points and the year, side by side and big.
##
## These are the two numbers the whole game is about — what you have earned,
## and how far through time you have ripped — so they are set large, weighted,
## and readable at a glance from any of the three views. The smaller detail
## (which calendar, what date, personal best) sits on a line underneath.
##
## The band never scrolls, so the score is visible whichever view is in front.
## It is also the one strip the swipe handler leaves alone, because the pause
## button lives here and is a real `Button`.

## Where the two big readouts sit. The band is split down the middle, with a
## rule between them, so neither number can crowd the other however long it
## gets.
const COLUMN_TOP: float = 12.0
const VALUE_BASELINE: float = 60.0
const CAPTION_BASELINE: float = 80.0
const DETAIL_BASELINE: float = 107.0
const DIVIDER_INSET: float = 16.0
const VALUE_FONT_SIZE: int = 50
const CAPTION_FONT_SIZE: int = 14
const DETAIL_FONT_SIZE: int = 17
## Left edge of the points column, clear of the pause button.
const COLUMN_LEFT: float = 62.0
const COLUMN_RIGHT_MARGIN: float = 18.0

## The three view dots, top right. The chevrons on the edges of the pager do
## the real signposting; these just say which of the three you are on.
const DOT_COUNT: int = 3
const DOT_RADIUS: float = 4.0
const DOT_SPACING: float = 16.0
const DOT_CENTRE: Vector2 = Vector2(676.0, 22.0)

var _view_index: int = 1


func _ready() -> void:
	refresh()


## Repaints the band from GameState. Cheap enough to call on every rip.
func refresh() -> void:
	queue_redraw()


## Lights the dot for the view being shown.
func set_view(view_index: int) -> void:
	if view_index == _view_index:
		return
	_view_index = view_index
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BAND, true)

	var middle: float = size.x * 0.5
	_column(
		font,
		DayCounter.with_separators(GameState.points),
		"POINTS",
		COLUMN_LEFT,
		middle - COLUMN_LEFT
	)
	_column(
		font,
		str(GameState.current_year()),
		"THE YEAR",
		middle,
		size.x - COLUMN_RIGHT_MARGIN - middle
	)

	draw_line(
		Vector2(middle, COLUMN_TOP + DIVIDER_INSET),
		Vector2(middle, CAPTION_BASELINE - DIVIDER_INSET * 0.5),
		Palette.BAND_MUTED,
		1.0
	)
	_draw_detail(font)
	_draw_dots()


## One big number with its caption underneath, centred in its half of the band.
## The number carries the weight; the caption does not, so the two never
## compete for the same glance.
func _column(font: Font, value: String, caption: String, left: float, width: float) -> void:
	Lettering.draw_centred(
		self,
		font,
		left,
		width,
		VALUE_BASELINE,
		value,
		VALUE_FONT_SIZE,
		Palette.BAND_TEXT,
		Lettering.WEIGHT_HEAVY
	)
	Lettering.draw_centred(
		self, font, left, width, CAPTION_BASELINE, caption, CAPTION_FONT_SIZE, Palette.BAND_MUTED
	)


## The smaller line: which calendar is on the wall and what its page reads on
## the left, the personal best on the right.
func _draw_detail(font: Font) -> void:
	(
		Lettering
		. draw_at(
			self,
			font,
			Vector2(COLUMN_LEFT, DETAIL_BASELINE),
			(
				"%s  ·  %s"
				% [
					CalendarTier.tier_name(GameState.tier_index).to_upper(),
					DayCounter.format_date(GameState.elapsed_days),
				]
			),
			DETAIL_FONT_SIZE,
			Palette.BAND_TEXT,
			Lettering.WEIGHT_BOLD
		)
	)
	Lettering.draw_right_of(
		self,
		font,
		size.x - COLUMN_RIGHT_MARGIN,
		DETAIL_BASELINE,
		"BEST %s" % DayCounter.with_separators(GameState.best_points),
		DETAIL_FONT_SIZE,
		Palette.BAND_MUTED
	)


func _draw_dots() -> void:
	for dot: int in DOT_COUNT:
		var centre: Vector2 = DOT_CENTRE + Vector2((dot - 1) * DOT_SPACING, 0.0)
		if dot == _view_index:
			draw_circle(centre, DOT_RADIUS, Palette.BAND_TEXT)
		else:
			draw_circle(centre, DOT_RADIUS, Palette.BAND_MUTED, false, 1.0)
