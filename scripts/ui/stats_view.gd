class_name StatsView
extends Control
## The progress view: what you have, what you are on, and how far the calendar
## has been ripped. Read-only — nothing here is tappable.
##
## Drawn in one `_draw()` rather than a label per row, for the same reason the
## calendar pages are: the row list is fixed, and nodes are the scarce thing.

const MARGIN: float = 64.0
const TITLE_BASELINE: float = 96.0
const FIRST_ROW_BASELINE: float = 176.0
const ROW_HEIGHT: float = 58.0
const LABEL_SIZE: int = 14
const VALUE_SIZE: int = 26

## Rows, top to bottom. Filled in by `_row_values` — the shape is fixed here so
## the layout cannot be driven by data.
const ROW_LABELS: PackedStringArray = [
	"POINTS",
	"BEST",
	"THE YEAR ON THE WALL",
	"CALENDAR ON THE WALL",
	"THE PAGE READS",
	"PAGES RIPPED",
	"HOLIDAYS COLLECTED",
	"RIPS PER YEAR",
	"NEXT CALENDAR",
]


## Repaints from GameState. Cheap enough to call on every rip.
func refresh() -> void:
	queue_redraw()


## The current value for each row, in the same order as ROW_LABELS.
func _row_values() -> PackedStringArray:
	return [
		DayCounter.with_separators(GameState.points),
		DayCounter.with_separators(GameState.best_points),
		"%d  (started %d)" % [GameState.current_year(), CalendarData.START_YEAR],
		CalendarTier.tier_name(GameState.tier_index),
		DayCounter.format_date(GameState.elapsed_days),
		DayCounter.with_separators(GameState.total_rips),
		(
			"%s  (%d in every year)"
			% [DayCounter.with_separators(GameState.holiday_count), HolidayData.HOLIDAY_COUNT]
		),
		DayCounter.with_separators(CalendarTier.taps_per_year(GameState.tier_index)),
		_next_calendar_text(),
	]


## What the store has left, said the same way the store says it.
func _next_calendar_text() -> String:
	if not CalendarTier.has_upgrade(GameState.tier_index):
		return "nothing left to buy"
	return (
		"%s, %s points"
		% [
			CalendarTier.tier_name(GameState.tier_index + 1),
			DayCounter.with_separators(GameState.next_tier_cost()),
		]
	)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Palette.WALL, true)
	draw_string(
		font,
		Vector2(MARGIN, TITLE_BASELINE),
		"PROGRESS",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		34,
		Palette.INK
	)
	draw_line(
		Vector2(MARGIN, TITLE_BASELINE + 22.0),
		Vector2(size.x - MARGIN, TITLE_BASELINE + 22.0),
		Palette.INK,
		2.0
	)

	var values: PackedStringArray = _row_values()
	for row: int in ROW_LABELS.size():
		var baseline: float = FIRST_ROW_BASELINE + row * ROW_HEIGHT
		draw_string(
			font,
			Vector2(MARGIN, baseline),
			ROW_LABELS[row],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			LABEL_SIZE,
			Palette.MUTED
		)
		draw_string(
			font,
			Vector2(MARGIN, baseline + 30.0),
			values[row],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			VALUE_SIZE,
			Palette.INK
		)
		draw_line(
			Vector2(MARGIN, baseline + 42.0),
			Vector2(size.x - MARGIN, baseline + 42.0),
			Palette.RULE,
			1.0
		)
