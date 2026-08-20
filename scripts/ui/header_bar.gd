class_name HeaderBar
extends Control
## The UI band across the top: the running point total, which calendar is on
## the wall, the date it reads, and which of the three views is showing.
##
## The point total is always visible, whichever view the player has swiped to.
## The band sits above the pager, so the pause button in it is the one control
## the swipe handler deliberately leaves alone.

## The three view dots, bottom right of the band.
const DOT_COUNT: int = 3
const DOT_RADIUS: float = 4.0
const DOT_SPACING: float = 16.0
const DOT_CENTRE: Vector2 = Vector2(664.0, 78.0)
## Where the small "PTS" caption sits, just right of the running total.
const CAPTION_ORIGIN: Vector2 = Vector2(198.0, 52.0)

var _view_index: int = 1

@onready var _points_label: Label = %PointsLabel
@onready var _tier_label: Label = %TierLabel
@onready var _date_label: Label = %DateLabel


func _ready() -> void:
	refresh()


## Repaints the band from GameState. Cheap enough to call on every rip.
func refresh() -> void:
	_points_label.text = "%d" % GameState.points
	_tier_label.text = "%s CALENDAR" % CalendarTier.tier_name(GameState.tier_index).to_upper()
	_date_label.text = DayCounter.format_date(GameState.elapsed_days)


## Lights the dot for the view being shown.
func set_view(view_index: int) -> void:
	if view_index == _view_index:
		return
	_view_index = view_index
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BAND, true)
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font, CAPTION_ORIGIN, "PTS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Palette.BAND_MUTED
	)

	for dot: int in DOT_COUNT:
		var centre: Vector2 = DOT_CENTRE + Vector2((dot - 1) * DOT_SPACING, 0.0)
		if dot == _view_index:
			draw_circle(centre, DOT_RADIUS, Palette.BAND_TEXT, true)
		else:
			draw_circle(centre, DOT_RADIUS, Palette.BAND_MUTED, false, 1.0)
