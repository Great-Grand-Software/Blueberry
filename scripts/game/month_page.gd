class_name MonthPage
extends Control
## One month's calendar page: a grid of days the player crosses off.
##
## The entire grid — rules, day numbers and X marks — is drawn by a single
## `_draw()` call on this one node, rather than by thirty child nodes. That
## keeps the node count flat no matter how many days a month has (see the
## spawn guardrail in CLAUDE.md), and it keeps the line work crisp and
## monochrome.
##
## Input is one tap hit-tested against the grid, so it satisfies the
## single-point-of-contact rule without any gesture handling.

signal day_tapped(day_number: int)
signal fold_finished(page: MonthPage)

## 7 across by 5 down = 35 cells, of which the first 30 are days. The five
## trailing blanks are what makes it read as a wall calendar rather than a
## bare grid.
const COLUMNS: int = 7
const ROWS: int = 5

const INK: Color = Color(0.106, 0.106, 0.106)
const PAPER: Color = Color(0.965, 0.961, 0.949)
const RULE: Color = Color(0.788, 0.784, 0.773)
const MUTED: Color = Color(0.545, 0.541, 0.529)

const RULE_WIDTH: float = 1.0
const BORDER_WIDTH: float = 2.0
const X_WIDTH: float = 3.0
## Inset of the X from its cell edges, as a fraction of the cell.
const X_INSET: float = 0.26
## Seconds for the fold-down. Short enough that a fast tapper is never stalled.
const FOLD_DURATION: float = 0.38

var _month_index: int = 0
var _marked: Dictionary = {}
var _is_folding: bool = false


func _ready() -> void:
	# Hinge the fold at the bottom edge, so the page collapses downward and
	# reveals the next month from the top down.
	pivot_offset = Vector2(size.x * 0.5, size.y)


## Points this page at a month and the set of days already crossed off.
func configure(month_index: int, marked_days: Dictionary) -> void:
	_month_index = month_index
	_marked = marked_days.duplicate()
	queue_redraw()


## Crosses off one day and redraws. Does not touch game state.
func mark_day(day_number: int) -> void:
	_marked[day_number] = true
	queue_redraw()


## True once the fold has begun; further taps are ignored.
func is_folding() -> bool:
	return _is_folding


## The month this page is showing.
func month_index() -> int:
	return _month_index


## Plays the fold-down and frees the page when it finishes. Safe to call more
## than once; only the first call has an effect.
func fold_down() -> void:
	if _is_folding:
		return
	_is_folding = true
	mouse_filter = MOUSE_FILTER_IGNORE

	# One finite tween: it always completes, and always frees.
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale:y", 0.0, FOLD_DURATION)
	tween.tween_callback(_finish_fold)


func _finish_fold() -> void:
	fold_finished.emit(self)
	queue_free()


func _cell_size() -> Vector2:
	return Vector2(size.x / float(COLUMNS), size.y / float(ROWS))


## Top-left corner of the cell holding `day_number` (1-based).
func _cell_origin(day_number: int) -> Vector2:
	var index: int = day_number - 1
	var cell: Vector2 = _cell_size()
	return Vector2((index % COLUMNS) * cell.x, (index / COLUMNS) * cell.y)


## The day number under a local point, or 0 if the point is not on a day.
func day_at_position(point: Vector2) -> int:
	if point.x < 0.0 or point.y < 0.0 or point.x >= size.x or point.y >= size.y:
		return 0
	var cell: Vector2 = _cell_size()
	var column: int = int(point.x / cell.x)
	var row: int = int(point.y / cell.y)
	var day_number: int = row * COLUMNS + column + 1
	if day_number < 1 or day_number > CalendarData.DAYS_PER_MONTH:
		return 0
	return day_number


func _gui_input(event: InputEvent) -> void:
	if _is_folding:
		return

	# One point of contact only: a single touch, or a single left click.
	var point := Vector2.ZERO
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed or touch.index != 0:
			return
		point = touch.position
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
			return
		point = click.position
	else:
		return

	var day_number: int = day_at_position(point)
	if day_number > 0 and not _marked.has(day_number):
		accept_event()
		day_tapped.emit(day_number)


func _draw() -> void:
	var cell: Vector2 = _cell_size()
	var font: Font = ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, size), PAPER, true)

	# Rules. Drawn before the numbers so the ink sits on top of the grid.
	for column: int in range(1, COLUMNS):
		var x: float = column * cell.x
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), RULE, RULE_WIDTH)
	for row: int in range(1, ROWS):
		var y: float = row * cell.y
		draw_line(Vector2(0.0, y), Vector2(size.x, y), RULE, RULE_WIDTH)

	draw_rect(Rect2(Vector2.ZERO, size), INK, false, BORDER_WIDTH)

	for day_number: int in range(1, CalendarData.DAYS_PER_MONTH + 1):
		var origin: Vector2 = _cell_origin(day_number)
		draw_string(
			font,
			origin + Vector2(7.0, 20.0),
			str(day_number),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			15,
			MUTED
		)
		if _marked.has(day_number):
			_draw_cross(origin, cell)


## The crossing-off mark: two strokes, like a pen through a wall calendar.
func _draw_cross(origin: Vector2, cell: Vector2) -> void:
	var inset := Vector2(cell.x * X_INSET, cell.y * X_INSET)
	var top_left: Vector2 = origin + inset
	var bottom_right: Vector2 = origin + cell - inset
	var top_right := Vector2(bottom_right.x, top_left.y)
	var bottom_left := Vector2(top_left.x, bottom_right.y)
	draw_line(top_left, bottom_right, INK, X_WIDTH)
	draw_line(top_right, bottom_left, INK, X_WIDTH)
