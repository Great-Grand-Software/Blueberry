extends GutTest
## Unit tests for the swipe stroke: press, hold, move, release.
##
## Crossing off a month is thirty separate contacts if every day needs its own
## tap, which is what made it tiring to play. A stroke is the *same* single
## point of contact, held and moved, so it needs the same coverage the tap
## path has — including the cases where it must not mark: hovering, a second
## finger, blanks, days already crossed off, and a page that is folding away.
##
## Split from `test_month_page.gd` only because that file is at gdlint's
## public-method ceiling; these exercise the same node.

const PAGE_SCENE: PackedScene = preload("res://scenes/month_page.tscn")
const PAGE_SIZE: float = 420.0
## Comfortably longer than MonthPage.FOLD_DURATION.
const FOLD_SETTLE_SECONDS: float = 0.55

var _page: MonthPage
## Every day the page reported, in the order it reported them.
var _reported: Array[int] = []


func before_each() -> void:
	_page = PAGE_SCENE.instantiate()
	add_child_autofree(_page)
	_page.size = Vector2(PAGE_SIZE, PAGE_SIZE)
	_page.configure(0, {})
	_reported = []
	# Mirrors what CalendarScreen does with the signal. Marking the day back
	# onto the page is what stops one stroke from reporting it twice.
	_page.day_tapped.connect(_on_page_day_tapped)
	await wait_process_frames(1)


func _on_page_day_tapped(day_number: int) -> void:
	_reported.append(day_number)
	_page.mark_day(day_number)


## Centre of the cell holding `day_number`.
func _centre_of(day_number: int) -> Vector2:
	var cell := Vector2(PAGE_SIZE / MonthPage.COLUMNS, PAGE_SIZE / MonthPage.ROWS)
	var index: int = day_number - 1
	var column: float = float(index % MonthPage.COLUMNS) + 0.5
	var row: float = float(index / MonthPage.COLUMNS) + 0.5
	return Vector2(column * cell.x, row * cell.y)


func _press(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	_page._gui_input(event)


func _move_to(point: Vector2, holding: bool = true) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if holding else 0
	event.position = point
	_page._gui_input(event)


func _release(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = point
	_page._gui_input(event)


func _touch(point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = point
	_page._gui_input(event)


func _drag(point: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	_page._gui_input(event)


func test_a_press_that_never_moves_is_still_one_tap() -> void:
	_press(_centre_of(3))
	_release(_centre_of(3))
	assert_eq(_reported, [3] as Array[int], "a plain tap marks exactly its own day")


func test_a_stroke_across_a_row_marks_every_day_in_it() -> void:
	_press(_centre_of(1))
	_move_to(_centre_of(7))
	_release(_centre_of(7))
	assert_eq(_reported, [1, 2, 3, 4, 5, 6, 7] as Array[int], "the whole row, in order")


func test_a_stroke_reported_as_one_long_jump_skips_nothing() -> void:
	# A fast swipe arrives as few positions, far apart — a whole row can pass
	# between two of them. The gap is walked, so this must not degrade into
	# marking only the two endpoints.
	_press(_centre_of(8))
	_move_to(_centre_of(14))
	assert_eq(_reported.size(), 7, "every cell the point crossed")
	assert_eq(_reported.front(), 8)
	assert_eq(_reported.back(), 14)


func test_a_stroke_down_a_column_marks_every_day_in_it() -> void:
	_press(_centre_of(1))
	_move_to(_centre_of(29))
	assert_eq(_reported, [1, 8, 15, 22, 29] as Array[int], "column one, top to bottom")


func test_a_stroke_reports_each_day_once() -> void:
	_press(_centre_of(1))
	_move_to(_centre_of(4))
	_move_to(_centre_of(1))
	_move_to(_centre_of(4))
	assert_eq(_reported, [1, 2, 3, 4] as Array[int], "doubling back cannot re-score")


func test_a_stroke_over_an_already_marked_day_leaves_it_alone() -> void:
	_page.configure(0, {2: true, 3: true})
	_press(_centre_of(1))
	_move_to(_centre_of(4))
	assert_eq(_reported, [1, 4] as Array[int], "days crossed off earlier are skipped")


func test_movement_without_a_press_marks_nothing() -> void:
	_move_to(_centre_of(1), false)
	_move_to(_centre_of(7), false)
	assert_eq(_reported.size(), 0, "hovering is not a stroke")


func test_a_stroke_ends_at_the_release() -> void:
	_press(_centre_of(1))
	_release(_centre_of(1))
	_move_to(_centre_of(7))
	assert_eq(_reported, [1] as Array[int], "movement after the lift is not the stroke")


func test_a_stroke_leaving_the_page_marks_only_real_days() -> void:
	_press(_centre_of(1))
	_move_to(Vector2(-PAGE_SIZE, _centre_of(1).y))
	assert_eq(_reported, [1] as Array[int], "nothing off the page")


func test_a_stroke_over_the_trailing_blanks_marks_only_days() -> void:
	# Cells 31-35 are the blanks that make it read as a wall calendar.
	_press(_centre_of(29))
	_move_to(Vector2(PAGE_SIZE - 5.0, _centre_of(30).y))
	assert_eq(_reported, [29, 30] as Array[int], "the blanks are not days")


func test_a_touch_stroke_marks_a_row() -> void:
	# The touch path, independent of the mouse the engine emulates from it.
	_touch(_centre_of(15), true)
	_drag(_centre_of(21))
	assert_eq(_reported, [15, 16, 17, 18, 19, 20, 21] as Array[int], "one finger, one row")


func test_a_touch_stroke_ends_when_the_finger_lifts() -> void:
	_touch(_centre_of(15), true)
	_touch(_centre_of(15), false)
	_drag(_centre_of(21))
	assert_eq(_reported, [15] as Array[int], "the lift ends the stroke")


func test_a_second_finger_is_ignored() -> void:
	# Single point of contact: index 0 and nothing else, pressing or dragging.
	_touch(_centre_of(5), true, 1)
	_drag(_centre_of(12), 1)
	assert_eq(_reported.size(), 0, "no second contact is ever consulted")


func test_a_folding_page_takes_no_more_marks() -> void:
	_page.fold_down()
	_press(_centre_of(1))
	_move_to(_centre_of(7))
	assert_eq(_reported.size(), 0, "a page on its way out is finished")
	await wait_seconds(FOLD_SETTLE_SECONDS)


func test_one_stroke_can_cross_off_a_whole_month() -> void:
	# The point of the feature: thirty days without thirty separate contacts.
	_press(_centre_of(1))
	for row: int in MonthPage.ROWS:
		var y: float = (float(row) + 0.5) * (PAGE_SIZE / MonthPage.ROWS)
		_move_to(Vector2(5.0, y))
		_move_to(Vector2(PAGE_SIZE - 5.0, y))
	_release(Vector2(PAGE_SIZE - 5.0, PAGE_SIZE - 5.0))
	assert_eq(_reported.size(), CalendarData.DAYS_PER_MONTH, "all thirty, one stroke")
