class_name MenuCalendar
extends Control
## The blank calendar on the main menu, with the Start button sitting on it.
##
## It is the same object the game is about — tack, backing strip, torn top
## edge, ruled grid — but empty: no month, no numbers, nothing crossed. Putting
## Start on the sheet rather than under it is the whole point. The first thing
## the player does is press a calendar, which is the only thing they will ever
## do, so the menu teaches the gesture instead of describing it.
##
## **The whole calendar is the button.** A play tester tapped the sheet rather
## than the Start printed on it and nothing happened, which is the menu failing
## at the one job it has. Pressing anywhere on the calendar now starts the
## game; the Start panel stays because it is what makes the sheet read as
## pressable in the first place.
##
## Drawn rather than loaded as an image: it costs no bytes, it matches the wall
## in-game exactly because it uses the same palette, and it stays crisp at any
## size the frame is letterboxed to.

signal pressed

## The backing strip the tack goes through, in local coordinates.
const BACKING_RECT: Rect2 = Rect2(10.0, 0.0, 340.0, 40.0)
## The blank sheet hanging off it.
const PAGE_RECT: Rect2 = Rect2(10.0, 34.0, 340.0, 436.0)
## The empty ruled grid on the sheet.
const GRID_RECT: Rect2 = Rect2(44.0, 92.0, 272.0, 224.0)

const TACK_RADIUS: float = 11.0
const TEAR_HEIGHT: float = 14.0
const TEAR_TEETH: int = 22
## Sheets showing under the bottom edge, so the pad reads as having pages left.
const STACK_LAYERS: int = 4
const STACK_STEP: float = 3.0

const GRID_COLUMNS: int = 7
const GRID_ROWS: int = 5
const SHADOW_OFFSET: Vector2 = Vector2(5.0, 5.0)

## Where the caption under the Start button sits.
const HINT_BASELINE: float = 412.0
const HINT_TEXT: String = "tap anywhere on the calendar to start"


func _gui_input(event: InputEvent) -> void:
	# One point of contact, same discipline as the game: finger zero or the
	# left mouse button, and only on release, so a press that slides off the
	# calendar does not start anything.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index == 0 and not touch.pressed:
			_press()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
			_press()


func _press() -> void:
	accept_event()
	pressed.emit()


func _draw() -> void:
	_draw_stack()
	draw_rect(Rect2(BACKING_RECT.position + SHADOW_OFFSET, BACKING_RECT.size), Palette.SHADOW)
	draw_rect(Rect2(PAGE_RECT.position + SHADOW_OFFSET, PAGE_RECT.size), Palette.SHADOW)

	draw_rect(PAGE_RECT, Palette.PAPER)
	_draw_torn_edge()
	draw_rect(PAGE_RECT, Palette.INK, false, 2.0)

	draw_rect(BACKING_RECT, Palette.PAPER)
	draw_rect(BACKING_RECT, Palette.INK, false, 2.0)
	_draw_tack()
	_draw_blank_grid()
	_draw_hint()


## The pages still to come, peeking out below the bottom edge.
func _draw_stack() -> void:
	for layer: int in range(STACK_LAYERS, 0, -1):
		var drop: float = layer * STACK_STEP
		var inset: float = layer * 2.0
		var sheet := Rect2(
			PAGE_RECT.position.x + inset,
			PAGE_RECT.position.y + drop,
			PAGE_RECT.size.x - inset * 2.0,
			PAGE_RECT.size.y
		)
		draw_rect(sheet, Palette.PAPER)
		draw_rect(sheet, Palette.RULE, false, 1.0)


## The same ragged line the pages in the game are torn along.
func _draw_torn_edge() -> void:
	var points: PackedVector2Array = []
	points.append(PAGE_RECT.position)
	for tooth: int in TEAR_TEETH + 1:
		var x: float = PAGE_RECT.position.x + PAGE_RECT.size.x * float(tooth) / float(TEAR_TEETH)
		var drop: float = TEAR_HEIGHT if tooth % 2 == 0 else TEAR_HEIGHT * 0.45
		points.append(Vector2(x, PAGE_RECT.position.y + drop))
	points.append(Vector2(PAGE_RECT.end.x, PAGE_RECT.position.y))
	draw_colored_polygon(points, Palette.PAPER)
	draw_polyline(points.slice(1, points.size() - 1), Palette.RULE, 1.0)


func _draw_tack() -> void:
	var tack := Vector2(size.x * 0.5, BACKING_RECT.position.y + 19.0)
	draw_circle(tack + Vector2(2.0, 2.0), TACK_RADIUS, Palette.SHADOW)
	draw_circle(tack, TACK_RADIUS, Palette.INK)
	draw_circle(tack - Vector2(3.0, 3.0), TACK_RADIUS * 0.34, Palette.PAPER)


## Ruled, and empty. No month, no numbers, nothing crossed off — the calendar
## before anybody has touched it.
func _draw_blank_grid() -> void:
	var cell := Vector2(GRID_RECT.size.x / GRID_COLUMNS, GRID_RECT.size.y / GRID_ROWS)
	for column: int in range(1, GRID_COLUMNS):
		var x: float = GRID_RECT.position.x + column * cell.x
		draw_line(Vector2(x, GRID_RECT.position.y), Vector2(x, GRID_RECT.end.y), Palette.RULE, 1.0)
	for row: int in range(1, GRID_ROWS):
		var y: float = GRID_RECT.position.y + row * cell.y
		draw_line(Vector2(GRID_RECT.position.x, y), Vector2(GRID_RECT.end.x, y), Palette.RULE, 1.0)
	draw_rect(GRID_RECT, Palette.MUTED, false, 1.0)


func _draw_hint() -> void:
	var font: Font = ThemeDB.fallback_font
	Lettering.draw_centred(
		self, font, 0.0, size.x, HINT_BASELINE, HINT_TEXT, 16, Palette.MUTED, Lettering.WEIGHT_BOLD
	)
