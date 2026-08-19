extends GutTest
## Integration tests for the gameplay screen, including the page cap.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const FOLD_SETTLE_SECONDS: float = 0.6

var _screen: Control


func before_each() -> void:
	GameState.reset_run()
	GameState.best_days = 0
	_screen = GAME_SCENE.instantiate()
	add_child_autofree(_screen)
	await wait_process_frames(2)


func after_each() -> void:
	get_tree().paused = false


func after_all() -> void:
	GameState.reset_run()


func _host() -> Control:
	return _screen.get_node("%PageHost")


## The tappable page is the last child, drawn over the one beneath it.
func _top_page() -> MonthPage:
	var host: Control = _host()
	return host.get_child(host.get_child_count() - 1) as MonthPage


func _live_pages() -> int:
	var count: int = 0
	for child: Node in _host().get_children():
		if is_instance_valid(child) and not (child as MonthPage).is_folding():
			count += 1
	return count


func _tap(day_number: int) -> void:
	_top_page().day_tapped.emit(day_number)


func test_two_pages_exist_the_tapped_one_and_the_next() -> void:
	assert_eq(_live_pages(), 2, "one to tap, one underneath to reveal")


func test_the_page_underneath_shows_next_month() -> void:
	var host: Control = _host()
	var beneath: MonthPage = host.get_child(0) as MonthPage
	assert_eq(_top_page().month_index(), 0, "January on top")
	assert_eq(beneath.month_index(), 1, "February underneath")


func test_tapping_a_day_scores_it() -> void:
	_tap(1)
	await wait_process_frames(1)
	assert_eq(GameState.total_days, 1)
	assert_true(GameState.is_day_marked(1))


func test_tapping_the_same_day_twice_scores_once() -> void:
	_tap(4)
	_tap(4)
	await wait_process_frames(1)
	assert_eq(GameState.total_days, 1)


func test_completing_a_month_folds_and_advances() -> void:
	for day: int in range(1, CalendarData.DAYS_PER_MONTH + 1):
		_tap(day)
	await wait_seconds(FOLD_SETTLE_SECONDS)

	assert_eq(GameState.total_days, 30)
	assert_eq(GameState.month_index, 1, "February is now on top")
	assert_eq(_top_page().month_index(), 1)


func test_the_month_drawing_advances_with_the_fold() -> void:
	var image: MonthImage = _screen.get_node("%MonthImage")
	assert_eq(image.month_index(), 0, "January drawing")

	for day: int in range(1, CalendarData.DAYS_PER_MONTH + 1):
		_tap(day)
	await wait_seconds(FOLD_SETTLE_SECONDS)
	assert_eq(image.month_index(), 1, "February drawing")


func test_page_count_never_exceeds_the_cap() -> void:
	# The core memory guardrail: the calendar runs forever, the node count
	# does not grow. Three months of tapping must not accumulate pages.
	for _month: int in 3:
		for day: int in range(1, CalendarData.DAYS_PER_MONTH + 1):
			_tap(day)
		await wait_seconds(FOLD_SETTLE_SECONDS)
		assert_lte(
			_live_pages(),
			2,
			"live pages must stay within MAX_LIVE_PAGES"
		)


func test_pause_freezes_the_tree_and_shows_the_overlay() -> void:
	var pause_button: Button = _screen.get_node("%PauseButton")
	var overlay: Control = _screen.get_node("%PauseOverlay")
	assert_false(overlay.visible, "the overlay starts hidden")

	pause_button.pressed.emit()
	await wait_process_frames(1)
	assert_true(get_tree().paused)
	assert_true(overlay.visible)


func test_resume_unfreezes_the_tree() -> void:
	var pause_button: Button = _screen.get_node("%PauseButton")
	var resume_button: Button = _screen.get_node("%ResumeButton")
	var overlay: Control = _screen.get_node("%PauseOverlay")

	pause_button.pressed.emit()
	await wait_process_frames(1)
	resume_button.pressed.emit()
	await wait_process_frames(1)

	assert_false(get_tree().paused)
	assert_false(overlay.visible)
