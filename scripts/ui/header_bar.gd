class_name HeaderBar
extends Control
## The score band across the top: points and the year, side by side and big.
##
## These are the two numbers the whole game is about — what you have earned,
## and how far through time you have ripped — so they are set large enough to
## read at a glance from any of the three views, with the smaller detail
## (which calendar, what date, personal best) on a line underneath.
##
## The band never scrolls, so the score is visible whichever view is in front.
## It is also the one strip the swipe handler leaves alone, because the pause
## button lives here and is a real `Button`.

## Where the two big readouts sit. The band is split down the middle, with a
## rule between them, so neither number can crowd the other however long it
## gets.
const COLUMN_TOP: float = 12.0
const VALUE_BASELINE: float = 58.0
const CAPTION_BASELINE: float = 78.0
const DETAIL_BASELINE: float = 106.0
const DIVIDER_INSET: float = 16.0
const VALUE_FONT_SIZE: int = 46
const CAPTION_FONT_SIZE: int = 13
const DETAIL_FONT_SIZE: int = 16
## Left edge of the points column, clear of the pause button.
const COLUMN_LEFT: float = 62.0
const COLUMN_RIGHT_MARGIN: float = 18.0

## The three view dots, top right.
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
	var left_width: float = middle - COLUMN_LEFT
	var right_width: float = size.x - COLUMN_RIGHT_MARGIN - middle

	_column(font, DayCounter.with_separators(GameState.points), "POINTS", COLUMN_LEFT, left_width)
	_column(font, str(GameState.current_year()), "THE YEAR", middle, right_width)

	draw_line(
		Vector2(middle, COLUMN_TOP + DIVIDER_INSET),
		Vector2(middle, CAPTION_BASELINE - DIVIDER_INSET * 0.5),
		Palette.BAND_MUTED,
		1.0
	)
	_draw_detail(font)
	_draw_dots()


## One big number with its caption underneath, centred in its half of the band.
func _column(font: Font, value: String, caption: String, left: float, width: float) -> void:
	_centred(font, value, VALUE_BASELINE, VALUE_FONT_SIZE, Palette.BAND_TEXT, left, width)
	_centred(font, caption, CAPTION_BASELINE, CAPTION_FONT_SIZE, Palette.BAND_MUTED, left, width)


## The smaller line: which calendar is on the wall and what its page reads on
## the left, the personal best on the right.
func _draw_detail(font: Font) -> void:
	var calendar: String = CalendarTier.tier_name(GameState.tier_index).to_upper()
	draw_string(
		font,
		Vector2(COLUMN_LEFT, DETAIL_BASELINE),
		"%s  ·  %s" % [calendar, DayCounter.format_date(GameState.elapsed_days)],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		DETAIL_FONT_SIZE,
		Palette.BAND_TEXT
	)
	var best: String = "BEST %s" % DayCounter.with_separators(GameState.best_points)
	var best_width: float = (
		font.get_string_size(best, HORIZONTAL_ALIGNMENT_LEFT, -1.0, DETAIL_FONT_SIZE).x
	)
	draw_string(
		font,
		Vector2(size.x - COLUMN_RIGHT_MARGIN - best_width, DETAIL_BASELINE),
		best,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
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


func _centred(
	font: Font,
	text: String,
	baseline: float,
	font_size: int,
	color: Color,
	left: float,
	width: float
) -> void:
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(
		font,
		Vector2(left + (width - text_width) * 0.5, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)
