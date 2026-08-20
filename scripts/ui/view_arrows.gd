class_name ViewArrows
extends Control
## The `<` and `>` on the left and right edges, showing that there is more
## than one screen.
##
## Three dots in the corner turned out to be no signal at all — a play tester
## never found the other two views. A chevron on the edge of the screen is the
## conventional answer, and it doubles as a tap target so the swipe is an
## option rather than the only way through.
##
## It draws on top of the views because it is the pager's last child, and it
## takes no input of its own: `ViewPager` owns every contact below the score
## band and hit-tests `zone()` before anything else. One reader of the finger,
## still.
##
## Deliberately not in the accent colour. Pale blue means points; a navigation
## affordance is not points, and colouring it would dilute the one signal the
## game has.

## Tap zone on each side. The wide calendars are sized to stop short of these,
## so a chevron can never steal a tap meant for the sheet — `test_view_pager`
## asserts it.
const ZONE_WIDTH: float = 58.0
## How tall the tap zone is, centred vertically.
const ZONE_HEIGHT: float = 220.0

const CHEVRON_HALF_WIDTH: float = 9.0
const CHEVRON_HALF_HEIGHT: float = 17.0
const CHEVRON_THICKNESS: float = 4.0
## Chevrons sit quietly until they are the way out of somewhere.
const CHEVRON_ALPHA: float = 0.42

var _view_index: int = 1
var _view_count: int = 3


## Points the arrows at the current position, so the end of the row loses its
## outward-facing chevron rather than offering a move that does nothing.
func set_view(view_index: int, view_count: int) -> void:
	if view_index == _view_index and view_count == _view_count:
		return
	_view_index = view_index
	_view_count = view_count
	queue_redraw()


## The tap zone on one side. `direction` is -1 for the left, +1 for the right.
func zone(direction: int) -> Rect2:
	var top: float = (size.y - ZONE_HEIGHT) * 0.5
	if direction < 0:
		return Rect2(0.0, top, ZONE_WIDTH, ZONE_HEIGHT)
	return Rect2(size.x - ZONE_WIDTH, top, ZONE_WIDTH, ZONE_HEIGHT)


## True if there is a view to move to on that side.
func has_view(direction: int) -> bool:
	var target: int = _view_index + direction
	return target >= 0 and target < _view_count


func _draw() -> void:
	for direction: int in [-1, 1]:
		if has_view(direction):
			_draw_chevron(zone(direction).get_center(), direction)


## A chevron pointing outward: two strokes, like the edge of a page turning.
func _draw_chevron(centre: Vector2, direction: int) -> void:
	var tip := Vector2(centre.x + CHEVRON_HALF_WIDTH * direction, centre.y)
	var back_x: float = centre.x - CHEVRON_HALF_WIDTH * direction
	var ink := Color(Palette.INK, CHEVRON_ALPHA)
	draw_line(Vector2(back_x, centre.y - CHEVRON_HALF_HEIGHT), tip, ink, CHEVRON_THICKNESS, true)
	draw_line(tip, Vector2(back_x, centre.y + CHEVRON_HALF_HEIGHT), ink, CHEVRON_THICKNESS, true)
