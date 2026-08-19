extends Control

## The starter screen: a grid you tap, and a count of every tap so far.
##
## It exists to prove the pipeline end to end — it boots headless, exports to
## Web, and draws with one _draw() rather than a node per cell. Replace it with
## your game; keep the shape.

## Side length of the grid, in pixels. A named constant, so the node count and
## the draw cost cannot grow with data.
const GRID_PIXELS: float = 500.0

var _grid: TapGrid = TapGrid.new(GRID_PIXELS)
var _marked: Dictionary = {}

@onready var _counter: Label = %Counter


func _ready() -> void:
	GameState.taps_changed.connect(_on_game_state_taps_changed)
	_refresh_counter(GameState.total_taps())


## Draws every cell in one pass. Prefer this over spawning a node per cell for
## anything gridded or repeated — see CLAUDE.md §4.
func _draw() -> void:
	var ink := Color(0.92, 0.92, 0.90)
	var side: float = _grid.cell_size()
	for index: int in range(_grid.cell_count()):
		var origin: Vector2 = _grid.cell_origin(index) + _grid_offset()
		draw_rect(Rect2(origin, Vector2(side, side)), ink, false, 2.0)
		if _marked.has(index):
			draw_line(origin, origin + Vector2(side, side), ink, 2.0)
			draw_line(origin + Vector2(side, 0.0), origin + Vector2(0.0, side), ink, 2.0)


func _gui_input(event: InputEvent) -> void:
	# One point of contact only: a single left click, or touch index 0.
	var point: Vector2 = Vector2.INF
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			point = mouse.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch.index == 0:
			point = touch.position
	if point == Vector2.INF:
		return

	var index: int = _grid.cell_at(point - _grid_offset())
	if index < 0 or _marked.has(index):
		return
	_marked[index] = true
	GameState.register_tap()
	queue_redraw()


func _grid_offset() -> Vector2:
	return (size - Vector2(GRID_PIXELS, GRID_PIXELS)) * 0.5


func _refresh_counter(total: int) -> void:
	if _counter != null:
		_counter.text = "TAPS  %d" % total


func _on_game_state_taps_changed(total: int) -> void:
	_refresh_counter(total)
