class_name StatsView
extends Control
## The progress view: what you have, what you are on, and how far the calendar
## has been ripped. Read-only — nothing here is tappable.
##
## Drawn in one `_draw()` rather than a label per row, for the same reason the
## calendar pages are: the row list is fixed, and nodes are the scarce thing.

const WALL: Color = Color(0.929, 0.925, 0.914)
const INK: Color = Color(0.106, 0.106, 0.106)
const MUTED: Color = Color(0.545, 0.541, 0.529)
const RULE: Color = Color(0.788, 0.784, 0.773)

const MARGIN: float = 64.0
const TITLE_BASELINE: float = 96.0
const FIRST_ROW_BASELINE: float = 190.0
const ROW_HEIGHT: float = 62.0
const LABEL_SIZE: int = 14
const VALUE_SIZE: int = 26

## Rows, top to bottom. Filled in by `_row_values` — the shape is fixed here so
## the layout cannot be driven by data.
const ROW_LABELS: PackedStringArray = [
	"POINTS",
	"BEST",
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
		str(GameState.points),
		str(GameState.best_points),
		CalendarTier.tier_name(GameState.tier_index),
		DayCounter.format_date(GameState.elapsed_days),
		str(GameState.total_rips),
		"%d  (%d in every year)" % [GameState.holiday_count, HolidayData.HOLIDAY_COUNT],
		str(CalendarTier.taps_per_year(GameState.tier_index)),
		_next_calendar_text(),
	]


## What the store has left, said the same way the store says it.
func _next_calendar_text() -> String:
	if not CalendarTier.has_upgrade(GameState.tier_index):
		return "nothing left to buy"
	return (
		"%s, %d points"
		% [
			CalendarTier.tier_name(GameState.tier_index + 1),
			GameState.next_tier_cost(),
		]
	)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), WALL, true)
	draw_string(
		font, Vector2(MARGIN, TITLE_BASELINE), "PROGRESS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, INK
	)
	draw_line(
		Vector2(MARGIN, TITLE_BASELINE + 22.0),
		Vector2(size.x - MARGIN, TITLE_BASELINE + 22.0),
		INK,
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
			MUTED
		)
		draw_string(
			font,
			Vector2(MARGIN, baseline + 30.0),
			values[row],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			VALUE_SIZE,
			INK
		)
		draw_line(
			Vector2(MARGIN, baseline + 42.0), Vector2(size.x - MARGIN, baseline + 42.0), RULE, 1.0
		)
