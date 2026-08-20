class_name CalendarPage
extends Control
## One page of whichever calendar is on the wall, and the rip that takes it off.
##
## The four calendars are four different objects, so they are four different
## shapes, not one shape with different contents:
##
##   Daily      a small thick square block — one day, and the stack it sits on
##   Monthly    the classic two squares — a picture over a month grid
##   Quarterly  a landscape rectangle with its three months laid out side by side
##   Yearly     a large block rectangle with every day of the year lined up
##
## All of it is a single `_draw()` rather than a cell per node, so a yearly page
## costs exactly what a daily one does — see the spawn guardrail in CLAUDE.md.
##
## The page handles no input. Taps arrive from the pager, which has to see the
## same single contact to tell a rip from a swipe, so routing them through one
## place is what keeps the two from fighting over the same finger.

signal rip_finished(page: CalendarPage)

## Page size per tier, indexed by CalendarTier. Read through `page_size()`.
const PAGE_SIZES: Array[Vector2] = [
	Vector2(320.0, 320.0),
	Vector2(340.0, 660.0),
	Vector2(620.0, 400.0),
	Vector2(640.0, 560.0),
]

## Depth of the torn top edge left behind when the page above came off.
const TEAR_HEIGHT: float = 14.0
## Zig-zags across the torn edge. A named bound, not a data-driven one.
const TEAR_TEETH: int = 22

## Sheets drawn under the daily block to give it its thickness. It is the one
## calendar you see the stack of, because it is the one small enough to.
const BLOCK_LAYERS: int = 7
const BLOCK_LAYER_STEP: float = 2.6

const BORDER_WIDTH: float = 2.0
const RULE_WIDTH: float = 1.0

## Grid shape for the monthly and quarterly faces. Seven across by five down
## holds 31 days.
const MONTH_COLUMNS: int = 7
const MONTH_ROWS: int = 5
## The yearly page gives each month a row rather than a grid of its own: a 7x5
## block twelve times over is too small to read, and one track per month is
## what "every day lined up" actually looks like.
const YEAR_TICK_HEIGHT: float = 6.0
const YEAR_LABEL_WIDTH: float = 46.0

## The tear off the tack, then the fall. Both finite, both self-terminating.
const TEAR_DURATION: float = 0.09
const FALL_DURATION: float = 0.52
## How far the page slips before it lets go, and how far it drifts as it falls.
const TEAR_SLIP: Vector2 = Vector2(7.0, 12.0)
const FALL_DRIFT_X: float = 54.0
const FALL_SPIN: float = 0.42

var _tier_index: int = 0
var _elapsed_days: int = 0
var _is_ripping: bool = false

@onready var _illustration: MonthImage = %Illustration


## How big a page is on the given tier.
static func page_size(tier_index: int) -> Vector2:
	return PAGE_SIZES[CalendarTier.normalize(tier_index)]


func _ready() -> void:
	_apply_size()


## Points the page at a tier and a position in the year. `elapsed_days` is the
## absolute count, so the page can show the year as well as the date.
func configure(tier_index: int, elapsed_days: int) -> void:
	_tier_index = CalendarTier.normalize(tier_index)
	_elapsed_days = maxi(elapsed_days, 0)
	_apply_size()
	_place_illustration()
	queue_redraw()


## True once the rip has begun; the page is on its way out and takes no more.
func is_ripping() -> bool:
	return _is_ripping


## The tier this page belongs to.
func tier_index() -> int:
	return _tier_index


## Day-of-year (0-based) this page opens on.
func year_day() -> int:
	return DayCounter.year_day_of(_elapsed_days)


## How many days this page covers.
func span_days() -> int:
	return CalendarTier.span_days(_tier_index, year_day())


## The holidays printed on this page, in date order.
func holidays() -> PackedStringArray:
	return HolidayData.names_in_span(year_day(), span_days())


## Tears the page off the tack and drops it out of frame, then frees it. Safe
## to call more than once; only the first call has an effect.
func rip_off(fall_distance: float) -> void:
	if _is_ripping:
		return
	_is_ripping = true
	mouse_filter = MOUSE_FILTER_IGNORE

	var rest: Vector2 = position
	var landing := Vector2(rest.x + FALL_DRIFT_X, rest.y + fall_distance)

	# One finite tween: it always completes, and always frees.
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", rest + TEAR_SLIP, TEAR_DURATION)

	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", landing, FALL_DURATION)
	tween.parallel().tween_property(self, "rotation", FALL_SPIN, FALL_DURATION)
	tween.parallel().tween_property(self, "modulate:a", 0.0, FALL_DURATION)
	tween.tween_callback(_finish_rip)


func _finish_rip() -> void:
	rip_finished.emit(self)
	queue_free()


func _apply_size() -> void:
	var wanted: Vector2 = page_size(_tier_index)
	custom_minimum_size = wanted
	size = wanted
	# Spin about the top edge as it falls, the way a torn sheet tips over the
	# line it came away from.
	pivot_offset = Vector2(wanted.x * 0.5, 0.0)


## The drawing sits differently on each calendar: a big square on the monthly
## page, a small header mark on the wider two, and nothing at all on the daily
## block, which has no room for anything but the day.
func _place_illustration() -> void:
	if _illustration == null:
		return
	var slot: Rect2 = _illustration_rect()
	_illustration.visible = slot.size.x > 0.0
	if not _illustration.visible:
		return
	_illustration.position = slot.position
	_illustration.size = slot.size
	_illustration.show_month(CalendarData.month_of_year_day(year_day()))


func _illustration_rect() -> Rect2:
	match _tier_index:
		CalendarTier.MONTHLY:
			return Rect2(42.0, 74.0, 255.0, 255.0)
		CalendarTier.QUARTERLY:
			return Rect2(18.0, 22.0, 78.0, 78.0)
		CalendarTier.YEARLY:
			return Rect2(24.0, 24.0, 100.0, 100.0)
		_:
			return Rect2()


func _draw() -> void:
	var face: Vector2 = page_size(_tier_index)
	if _tier_index == CalendarTier.DAILY:
		_draw_block_thickness(face)
	draw_rect(Rect2(Vector2.ZERO, face), Palette.PAPER, true)
	_draw_torn_edge(face)
	draw_rect(Rect2(Vector2.ZERO, face), Palette.INK, false, BORDER_WIDTH)

	match _tier_index:
		CalendarTier.MONTHLY:
			_draw_monthly_face(face)
		CalendarTier.QUARTERLY:
			_draw_quarterly_face(face)
		CalendarTier.YEARLY:
			_draw_yearly_face(face)
		_:
			_draw_daily_face(face)


## The stack under the daily block. Drawn before the page itself, offset down
## and in, so the block reads as a wad of paper rather than a single sheet.
func _draw_block_thickness(face: Vector2) -> void:
	for layer: int in range(BLOCK_LAYERS, 0, -1):
		var drop: float = layer * BLOCK_LAYER_STEP
		var inset: float = layer * 1.4
		draw_rect(
			Rect2(inset, drop, face.x - inset * 2.0, face.y),
			Palette.PAPER if layer % 2 == 0 else Palette.RULE,
			true
		)
		draw_rect(Rect2(inset, drop, face.x - inset * 2.0, face.y), Palette.RULE, false, 1.0)


## The ragged line across the top, where the page above was torn away.
func _draw_torn_edge(face: Vector2) -> void:
	var points: PackedVector2Array = []
	points.append(Vector2(0.0, 0.0))
	for tooth: int in TEAR_TEETH + 1:
		var x: float = face.x * float(tooth) / float(TEAR_TEETH)
		var y: float = TEAR_HEIGHT if tooth % 2 == 0 else TEAR_HEIGHT * 0.45
		points.append(Vector2(x, y))
	points.append(Vector2(face.x, 0.0))
	draw_colored_polygon(points, Palette.PAPER)
	draw_polyline(points.slice(1, points.size() - 1), Palette.RULE, RULE_WIDTH)


## Daily: one day, as big as a small square block can print it. No picture and
## no grid — a block calendar shows you the day and nothing else.
func _draw_daily_face(face: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var month: int = CalendarData.month_of_year_day(year_day())
	_centred(font, CalendarData.month_name(month).to_upper(), 52.0, 20, Palette.INK, 0.0, face.x)
	_centred(font, _year_text(), 72.0, 15, Palette.MUTED, 0.0, face.x)
	_centred(font, str(CalendarData.day_of_month(year_day())), 208.0, 122, Palette.INK, 0.0, face.x)
	_centred(
		font,
		"DAY %d OF %d" % [year_day() + 1, CalendarData.DAYS_PER_YEAR],
		236.0,
		13,
		Palette.MUTED,
		0.0,
		face.x
	)
	_draw_holiday_strip(font, Rect2(18.0, 252.0, face.x - 36.0, face.y - 252.0))


## Monthly: the classic two squares, a picture over the month's own days.
func _draw_monthly_face(face: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var month: int = CalendarData.month_of_year_day(year_day())
	_centred(font, CalendarData.month_name(month).to_upper(), 44.0, 26, Palette.INK, 0.0, face.x)
	_centred(font, _year_text(), 64.0, 16, Palette.MUTED, 0.0, face.x)
	# The picture square is the illustration node; this is the grid square
	# directly beneath it, the same size, which is what makes it read as two.
	_draw_month_grid(Rect2(42.0, 341.0, 255.0, 255.0), month, 13)
	_draw_holiday_strip(font, Rect2(24.0, 604.0, face.x - 48.0, face.y - 604.0))


## Quarterly: a landscape sheet with its three months laid out side by side.
func _draw_quarterly_face(face: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var quarter: int = CalendarData.quarter_of_month(CalendarData.month_of_year_day(year_day()))
	var first: int = CalendarData.quarter_first_month(quarter)
	_centred(font, _title_text(), 50.0, 26, Palette.INK, 0.0, face.x)
	_centred(font, _year_text(), 72.0, 16, Palette.MUTED, 0.0, face.x)

	var band := Rect2(26.0, 100.0, face.x - 52.0, 226.0)
	var column: float = band.size.x / CalendarData.MONTHS_PER_QUARTER
	for offset: int in CalendarData.MONTHS_PER_QUARTER:
		var month: int = CalendarData.normalize_month(first + offset)
		var left: float = band.position.x + offset * column
		_centred(
			font,
			CalendarData.month_name(month).to_upper(),
			band.position.y + 14.0,
			15,
			Palette.INK,
			left,
			column
		)
		_draw_month_grid(
			Rect2(left + 10.0, band.position.y + 26.0, column - 20.0, band.size.y - 34.0), month, 11
		)
	_draw_holiday_strip(font, Rect2(26.0, 336.0, face.x - 52.0, face.y - 336.0))


## Yearly: one large block with every day of the year lined up, month by month.
func _draw_yearly_face(face: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	_centred(font, _title_text(), 58.0, 26, Palette.INK, 0.0, face.x)
	_centred(font, _year_text(), 80.0, 16, Palette.MUTED, 0.0, face.x)

	var band := Rect2(26.0, 126.0, face.x - 52.0, 358.0)
	var row_height: float = band.size.y / CalendarData.MONTH_COUNT
	for month: int in CalendarData.MONTH_COUNT:
		var baseline: float = band.position.y + (month + 0.66) * row_height
		draw_string(
			font,
			Vector2(band.position.x, baseline),
			CalendarData.month_abbreviation(month),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Palette.MUTED
		)
		_draw_month_track(
			Vector2(band.position.x + YEAR_LABEL_WIDTH, baseline - 4.0),
			band.size.x - YEAR_LABEL_WIDTH,
			month
		)
	_draw_holiday_strip(font, Rect2(26.0, 494.0, face.x - 52.0, face.y - 494.0))


## A month as a real grid of its own days, ruled like a wall calendar.
## Holidays get a corner dot; a ring round the number would print over it.
func _draw_month_grid(rect: Rect2, month_index: int, font_size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var cell := Vector2(rect.size.x / MONTH_COLUMNS, rect.size.y / MONTH_ROWS)
	var days: int = CalendarData.days_in_month(month_index)
	var month_start: int = CalendarData.month_start_day(month_index)

	for column: int in range(1, MONTH_COLUMNS):
		var x: float = rect.position.x + column * cell.x
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Palette.RULE, RULE_WIDTH)
	for row: int in range(1, MONTH_ROWS):
		var y: float = rect.position.y + row * cell.y
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Palette.RULE, RULE_WIDTH)
	draw_rect(rect, Palette.MUTED, false, RULE_WIDTH)

	for day: int in range(1, days + 1):
		var index: int = day - 1
		var origin: Vector2 = (
			rect.position
			+ Vector2((index % MONTH_COLUMNS) * cell.x, (index / MONTH_COLUMNS) * cell.y)
		)
		var is_holiday: bool = HolidayData.is_holiday(month_start + index)
		if is_holiday:
			draw_circle(origin + cell - Vector2(cell.x * 0.22, cell.y * 0.24), 4.0, Palette.INK)
		draw_string(
			font,
			origin + Vector2(5.0, font_size + 4.0),
			str(day),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			Palette.INK if is_holiday else Palette.MUTED
		)


## One month as a row of day ticks, with its holidays picked out. Bounded by
## the month's own length, which is at most 31.
func _draw_month_track(origin: Vector2, track_width: float, month_index: int) -> void:
	var days: int = CalendarData.days_in_month(month_index)
	var month_start: int = CalendarData.month_start_day(month_index)
	var step: float = track_width / float(days)
	for day: int in days:
		var x: float = origin.x + (day + 0.5) * step
		if HolidayData.is_holiday(month_start + day):
			draw_circle(Vector2(x, origin.y), 4.5, Palette.INK)
		else:
			draw_line(
				Vector2(x, origin.y - YEAR_TICK_HEIGHT * 0.5),
				Vector2(x, origin.y + YEAR_TICK_HEIGHT * 0.5),
				Palette.RULE,
				RULE_WIDTH
			)


## The strip along the bottom naming what this page is worth. A page with
## nothing on it says so, so an empty strip never reads as a missing feature.
func _draw_holiday_strip(font: Font, rect: Rect2) -> void:
	var names: PackedStringArray = holidays()
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Palette.RULE, RULE_WIDTH)
	if names.is_empty():
		_centred(
			font,
			"NO HOLIDAYS",
			rect.position.y + 26.0,
			13,
			Palette.RULE,
			rect.position.x,
			rect.size.x
		)
		return

	# A yearly page holds all eight names, which is wider than any strip.
	# Measuring rather than counting means this holds however the table changes,
	# and however long a holiday is named.
	var listed: String = ", ".join(names).to_upper()
	if font.get_string_size(listed, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x > rect.size.x:
		listed = "%d HOLIDAYS ON THIS PAGE" % names.size()
	_centred(font, listed, rect.position.y + 24.0, 13, Palette.INK, rect.position.x, rect.size.x)
	_centred(
		font,
		"+%d POINT%s" % [names.size(), "" if names.size() == 1 else "S"],
		rect.position.y + 44.0,
		13,
		Palette.MUTED,
		rect.position.x,
		rect.size.x
	)


## What this page calls itself, which is the clearest signal of which calendar
## is on the wall.
func _title_text() -> String:
	var month: int = CalendarData.month_of_year_day(year_day())
	match _tier_index:
		CalendarTier.QUARTERLY:
			var quarter: int = CalendarData.quarter_of_month(month)
			var first: int = CalendarData.quarter_first_month(quarter)
			return (
				"%s   %s-%s"
				% [
					CalendarData.QUARTER_NAMES[quarter],
					CalendarData.month_abbreviation(first),
					CalendarData.month_abbreviation(first + CalendarData.MONTHS_PER_QUARTER - 1),
				]
			)
		CalendarTier.YEARLY:
			return "THE WHOLE YEAR"
		_:
			return CalendarData.month_name(month).to_upper()


## The year printed on the sheet. It is the run's progress bar — it starts at
## 2026 and a long game really does reach 6782 — so every calendar prints it,
## and prints it larger than the caption it replaced.
func _year_text() -> String:
	return str(DayCounter.year_of(_elapsed_days))


## Draws `text` centred inside a horizontal band.
func _centred(
	font: Font,
	text: String,
	baseline: float,
	font_size: int,
	color: Color,
	left: float,
	band_width: float
) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(
		font,
		Vector2(left + (band_width - width) * 0.5, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)
