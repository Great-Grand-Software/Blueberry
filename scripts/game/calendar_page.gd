class_name CalendarPage
extends Control
## One page of whichever calendar is on the wall, and the rip that takes it off.
##
## Every tier draws through this one node: a day block, a month grid, a quarter
## of three little months, or a whole year of twelve. All of it is a single
## `_draw()` rather than a cell per node, so a yearly page costs exactly what a
## daily one does — see the spawn guardrail in CLAUDE.md.
##
## The page handles no input. Taps arrive from the pager, which has to see the
## same single contact to tell a rip from a swipe, so routing them through one
## place is what keeps the two from fighting over the same finger.

signal rip_finished(page: CalendarPage)

## Page geometry, in page-local coordinates.
const PAGE_SIZE: Vector2 = Vector2(440.0, 620.0)
## Depth of the torn top edge left behind when the page above came off.
const TEAR_HEIGHT: float = 14.0
## Zig-zags across the torn edge. A named bound, not a data-driven one.
const TEAR_TEETH: int = 22

const ILLUSTRATION_RECT: Rect2 = Rect2(24.0, 24.0, 392.0, 180.0)
const TITLE_BASELINE: float = 244.0
const BODY_RECT: Rect2 = Rect2(24.0, 292.0, 392.0, 252.0)
const HOLIDAY_RECT: Rect2 = Rect2(24.0, 556.0, 392.0, 52.0)

const INK: Color = Color(0.106, 0.106, 0.106)
const PAPER: Color = Color(0.965, 0.961, 0.949)
const RULE: Color = Color(0.788, 0.784, 0.773)
const MUTED: Color = Color(0.545, 0.541, 0.529)

const BORDER_WIDTH: float = 2.0
const RULE_WIDTH: float = 1.0

## Grid shape for the monthly page. Seven across by five down holds 31 days.
const MONTH_COLUMNS: int = 7
const MONTH_ROWS: int = 5
## The yearly page gives each month a row rather than a grid of its own: a
## 7x5 block twelve times over is too small to read at this size, and one
## track per month reads like a year planner.
const YEAR_TICK_HEIGHT: float = 5.0
const YEAR_LABEL_WIDTH: float = 44.0

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


func _ready() -> void:
	custom_minimum_size = PAGE_SIZE
	size = PAGE_SIZE
	# Spin about the top edge as it falls, the way a torn sheet tips over the
	# line it came away from.
	pivot_offset = Vector2(PAGE_SIZE.x * 0.5, 0.0)


## Points the page at a tier and a position in the year. `elapsed_days` is the
## absolute count, so the page can show the year as well as the date.
func configure(tier_index: int, elapsed_days: int) -> void:
	_tier_index = CalendarTier.normalize(tier_index)
	_elapsed_days = maxi(elapsed_days, 0)
	if _illustration != null:
		_illustration.show_month(CalendarData.month_of_year_day(year_day()))
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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, PAGE_SIZE), PAPER, true)
	_draw_torn_edge()
	draw_rect(Rect2(Vector2.ZERO, PAGE_SIZE), INK, false, BORDER_WIDTH)

	_draw_title()
	match _tier_index:
		CalendarTier.MONTHLY:
			_draw_month_body(BODY_RECT, CalendarData.month_of_year_day(year_day()))
		CalendarTier.QUARTERLY:
			_draw_quarter_body()
		CalendarTier.YEARLY:
			_draw_year_body()
		_:
			_draw_day_body()
	_draw_holidays()


## The ragged line across the top, where the page above was torn away. Drawn in
## paper over the border so the top edge reads as torn rather than trimmed.
func _draw_torn_edge() -> void:
	var points: PackedVector2Array = []
	points.append(Vector2(0.0, 0.0))
	for tooth: int in TEAR_TEETH + 1:
		var x: float = PAGE_SIZE.x * float(tooth) / float(TEAR_TEETH)
		var y: float = TEAR_HEIGHT if tooth % 2 == 0 else TEAR_HEIGHT * 0.45
		points.append(Vector2(x, y))
	points.append(Vector2(PAGE_SIZE.x, 0.0))
	draw_colored_polygon(points, PAPER)
	draw_polyline(points.slice(1, points.size() - 1), RULE, RULE_WIDTH)


func _draw_title() -> void:
	var font: Font = ThemeDB.fallback_font
	_draw_centred(font, _title_text(), TITLE_BASELINE, 26, INK)
	_draw_centred(
		font, "YEAR %d" % DayCounter.year_of(_elapsed_days), TITLE_BASELINE + 22.0, 13, MUTED
	)
	draw_line(
		Vector2(BODY_RECT.position.x, TITLE_BASELINE + 34.0),
		Vector2(BODY_RECT.end.x, TITLE_BASELINE + 34.0),
		RULE,
		RULE_WIDTH
	)


## What this page calls itself, which is the clearest signal of which calendar
## is on the wall.
func _title_text() -> String:
	var month: int = CalendarData.month_of_year_day(year_day())
	match _tier_index:
		CalendarTier.MONTHLY:
			return CalendarData.month_name(month).to_upper()
		CalendarTier.QUARTERLY:
			var quarter: int = CalendarData.quarter_of_month(month)
			var first: int = CalendarData.quarter_first_month(quarter)
			return (
				"%s  %s-%s"
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


## Daily: one day, as big as the page can print it.
func _draw_day_body() -> void:
	var font: Font = ThemeDB.fallback_font
	var day: int = CalendarData.day_of_month(year_day())
	_draw_centred(font, str(day), BODY_RECT.position.y + 168.0, 128, INK)
	# Which day of the year it is, rather than the holiday name — the strip
	# along the bottom already says that, on every tier.
	_draw_centred(
		font,
		"DAY %d OF %d" % [year_day() + 1, CalendarData.DAYS_PER_YEAR],
		BODY_RECT.end.y - 8.0,
		15,
		MUTED
	)


## Monthly: every real day of the month, holidays ringed.
func _draw_month_body(rect: Rect2, month_index: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var cell := Vector2(rect.size.x / MONTH_COLUMNS, rect.size.y / MONTH_ROWS)
	var days: int = CalendarData.days_in_month(month_index)
	var month_start: int = CalendarData.month_start_day(month_index)

	for column: int in range(1, MONTH_COLUMNS):
		var x: float = rect.position.x + column * cell.x
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), RULE, RULE_WIDTH)
	for row: int in range(1, MONTH_ROWS):
		var y: float = rect.position.y + row * cell.y
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), RULE, RULE_WIDTH)
	draw_rect(rect, MUTED, false, RULE_WIDTH)

	for day: int in range(1, days + 1):
		var index: int = day - 1
		var origin: Vector2 = (
			rect.position
			+ Vector2((index % MONTH_COLUMNS) * cell.x, (index / MONTH_COLUMNS) * cell.y)
		)
		var is_holiday: bool = HolidayData.is_holiday(month_start + index)
		if is_holiday:
			# A corner dot rather than a ring round the number, which would
			# print straight over the digits in a cell this size.
			draw_circle(origin + cell - Vector2(11.0, 11.0), 4.5, INK, true)
		draw_string(
			font,
			origin + Vector2(6.0, 18.0),
			str(day),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			14,
			INK if is_holiday else MUTED
		)


## Quarterly: the three months of the quarter, side by side.
func _draw_quarter_body() -> void:
	var font: Font = ThemeDB.fallback_font
	var quarter: int = CalendarData.quarter_of_month(CalendarData.month_of_year_day(year_day()))
	var first: int = CalendarData.quarter_first_month(quarter)
	var column_width: float = BODY_RECT.size.x / CalendarData.MONTHS_PER_QUARTER

	for offset: int in CalendarData.MONTHS_PER_QUARTER:
		var month: int = CalendarData.normalize_month(first + offset)
		var left: float = BODY_RECT.position.x + offset * column_width
		_draw_centred(
			font,
			CalendarData.month_abbreviation(month),
			BODY_RECT.position.y + 16.0,
			15,
			INK,
			left,
			column_width
		)
		_draw_day_dots(
			Rect2(
				left + 8.0,
				BODY_RECT.position.y + 28.0,
				column_width - 16.0,
				BODY_RECT.size.y - 40.0
			),
			month
		)


## Yearly: one track per month, twelve rows deep, holidays picked out on it.
## A whole year has to fit the same page a single day gets, so the months trade
## their own grids for a row apiece.
func _draw_year_body() -> void:
	var font: Font = ThemeDB.fallback_font
	var row_height: float = BODY_RECT.size.y / CalendarData.MONTH_COUNT
	for month: int in CalendarData.MONTH_COUNT:
		var baseline: float = BODY_RECT.position.y + (month + 0.62) * row_height
		draw_string(
			font,
			Vector2(BODY_RECT.position.x, baseline),
			CalendarData.month_abbreviation(month),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			MUTED
		)
		_draw_month_track(
			Vector2(BODY_RECT.position.x + YEAR_LABEL_WIDTH, baseline - 4.0),
			BODY_RECT.size.x - YEAR_LABEL_WIDTH,
			month
		)


## One month as a row of day ticks, with its holidays marked. Bounded by the
## month's own length, which is at most 31.
func _draw_month_track(origin: Vector2, track_width: float, month_index: int) -> void:
	var days: int = CalendarData.days_in_month(month_index)
	var month_start: int = CalendarData.month_start_day(month_index)
	var step: float = track_width / float(days)
	for day: int in days:
		var x: float = origin.x + (day + 0.5) * step
		if HolidayData.is_holiday(month_start + day):
			draw_circle(Vector2(x, origin.y), 4.0, INK, true)
		else:
			draw_line(
				Vector2(x, origin.y - YEAR_TICK_HEIGHT * 0.5),
				Vector2(x, origin.y + YEAR_TICK_HEIGHT * 0.5),
				RULE,
				RULE_WIDTH
			)


## A month as a grid of dots: hollow for ordinary days, filled for holidays.
## Bounded by the grid, not by the month, so a short month just leaves blanks.
func _draw_day_dots(rect: Rect2, month_index: int) -> void:
	var cell := Vector2(rect.size.x / MONTH_COLUMNS, rect.size.y / MONTH_ROWS)
	var radius: float = maxf(minf(cell.x, cell.y) * 0.22, 1.0)
	var days: int = CalendarData.days_in_month(month_index)
	var month_start: int = CalendarData.month_start_day(month_index)

	for index: int in MONTH_COLUMNS * MONTH_ROWS:
		if index >= days:
			return
		var centre: Vector2 = (
			rect.position
			+ Vector2(
				(index % MONTH_COLUMNS + 0.5) * cell.x, (index / MONTH_COLUMNS + 0.5) * cell.y
			)
		)
		if HolidayData.is_holiday(month_start + index):
			draw_circle(centre, radius * 1.7, INK, true)
		else:
			draw_circle(centre, radius, RULE, true)


## The strip along the bottom naming what this page is worth. A page with
## nothing on it says so, so an empty strip never reads as a missing feature.
func _draw_holidays() -> void:
	var font: Font = ThemeDB.fallback_font
	var names: PackedStringArray = holidays()
	draw_line(
		HOLIDAY_RECT.position,
		Vector2(HOLIDAY_RECT.end.x, HOLIDAY_RECT.position.y),
		RULE,
		RULE_WIDTH
	)
	if names.is_empty():
		_draw_centred(font, "NO HOLIDAYS", HOLIDAY_RECT.position.y + 30.0, 14, RULE)
		return

	# A yearly page holds all eight names, which is far wider than the strip.
	# Measuring rather than counting means this holds however the table
	# changes, and however long a holiday is named.
	var listed: String = ", ".join(names).to_upper()
	if font.get_string_size(listed, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x > HOLIDAY_RECT.size.x:
		listed = "%d HOLIDAYS ON THIS PAGE" % names.size()
	_draw_centred(font, listed, HOLIDAY_RECT.position.y + 24.0, 13, INK)
	_draw_centred(
		font,
		"+%d POINT%s" % [names.size(), "" if names.size() == 1 else "S"],
		HOLIDAY_RECT.position.y + 44.0,
		13,
		MUTED
	)


## Draws `text` centred inside a horizontal band, defaulting to the whole page.
func _draw_centred(
	font: Font,
	text: String,
	baseline: float,
	font_size: int,
	color: Color,
	left: float = 0.0,
	band_width: float = PAGE_SIZE.x
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
