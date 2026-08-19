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
## Input is one point of contact hit-tested against the grid. Pressing marks
## the day under the point; holding and moving keeps marking each new day the
## point crosses, so a row can be struck through in one stroke instead of
## seven separate taps. That is still a single finger or a single button — no
## second contact is ever consulted — so the single-point-of-contact rule
## holds.

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

## How finely a swipe is sampled between two reported positions, as a fraction
## of the smaller cell dimension. Below 0.5 no whole cell can fall between two
## samples, which is what stops a fast swipe from skipping days.
const SWIPE_SAMPLE_FRACTION: float = 0.4
## Hard cap on samples taken for one movement event. A pointer can jump an
## arbitrary distance in one frame, so the walk needs a bound that does not
## come from the data — see the loop guardrail in CLAUDE.md.
const MAX_SWIPE_SAMPLES: int = 32

var _month_index: int = 0
var _marked: Dictionary = {}
var _is_folding: bool = false
## True between the press that starts a stroke and the release that ends it.
var _stroke_active: bool = false
## Where the stroke was last sampled, so the gap to the next position can be
## walked rather than jumped.
var _stroke_point: Vector2 = Vector2.ZERO


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
	_stroke_active = false
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

	# One point of contact only: finger zero, or the left mouse button. A
	# swipe is that same one contact held down and moved, so nothing here
	# needs a second index or a gesture event.
	#
	# Touch is read both as touch/drag and, because the engine emulates a
	# mouse from touch by default, as button/motion. Marking is idempotent
	# and the stroke helpers are re-entrant, so handling both is harmless and
	# means the swipe works even where only one of the pairs arrives.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return
		if touch.pressed:
			_begin_stroke(touch.position)
		else:
			_end_stroke()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != 0:
			return
		_continue_stroke(drag.position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_begin_stroke(click.position)
		else:
			_end_stroke()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# Movement with nothing held is just the cursor passing over the page.
		# This is the gate that makes a missed release harmless: the stroke
		# flag may go stale, but nothing can be marked without the button.
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		_continue_stroke(motion.position)


## Starts a stroke and marks the day under the press, so a stroke that never
## moves is exactly the old single tap.
func _begin_stroke(point: Vector2) -> void:
	accept_event()
	_stroke_active = true
	_stroke_point = point
	_mark_at(point)


func _end_stroke() -> void:
	_stroke_active = false


## Extends a stroke to `point`, marking every day between there and where the
## stroke was last seen.
func _continue_stroke(point: Vector2) -> void:
	if not _stroke_active:
		return
	accept_event()

	# A fast swipe reports few positions, far apart — a whole row can pass
	# between two of them. Walking the gap in sub-cell steps marks the days
	# the point actually crossed instead of only the two it was sampled on.
	var cell: Vector2 = _cell_size()
	var step: float = maxf(minf(cell.x, cell.y) * SWIPE_SAMPLE_FRACTION, 1.0)
	var distance: float = _stroke_point.distance_to(point)
	var samples: int = clampi(int(ceilf(distance / step)), 1, MAX_SWIPE_SAMPLES)
	for index: int in range(1, samples + 1):
		# The last mark of a stroke can complete the month and start the fold;
		# everything after it belongs to a page that is on its way out.
		if _is_folding:
			break
		_mark_at(_stroke_point.lerp(point, float(index) / float(samples)))
	_stroke_point = point


## Reports the day under `point` if it is one and is not already crossed off.
## The owner marks it back through `mark_day`, so by the next sample this page
## already knows about it and cannot report the same day twice.
func _mark_at(point: Vector2) -> void:
	var day_number: int = day_at_position(point)
	if day_number > 0 and not _marked.has(day_number):
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
