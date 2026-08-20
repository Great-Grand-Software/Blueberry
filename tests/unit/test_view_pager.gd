extends GutTest
## Tests for the swipe navigation, and for the one rule that makes it work:
## the pager decides what a contact was, so a swipe never also rips a page.
##
## Every event here is one point of contact — pressed, moved, released — which
## is the same contact the rip uses. That is exactly why they cannot both read
## it independently.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
## Comfortably longer than ViewPager.SETTLE_DURATION.
const SETTLE_SECONDS: float = 0.4
## A point over the hanging calendar page, in viewport coordinates: the pager
## starts 96px down, and every calendar hangs centred from the same line.
const ON_THE_PAGE: Vector2 = Vector2(360.0, 396.0)
## Far enough sideways to commit the swipe: over 28% of 720.
const COMMIT_TRAVEL: float = 350.0

var _screen: Control
var _pager: ViewPager


func before_each() -> void:
	GameState.reset_run()
	GameState.best_points = 0
	_screen = GAME_SCENE.instantiate()
	add_child_autofree(_screen)
	_pager = _screen.get_node("%ViewPager")
	await wait_process_frames(2)


func after_all() -> void:
	GameState.reset_run()


func _press(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	_pager._input(event)


func _move_to(point: Vector2, holding: bool = true) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if holding else 0
	event.position = point
	_pager._input(event)


func _release(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = point
	_pager._input(event)


func _touch(point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = point
	_pager._input(event)


func _drag(point: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	_pager._input(event)


## One held contact dragged sideways by `travel`, starting mid-screen.
func _swipe(travel: float) -> void:
	var start := Vector2(360.0, 600.0)
	_press(start)
	_move_to(start + Vector2(travel * 0.5, 0.0))
	_move_to(start + Vector2(travel, 0.0))
	_release(start + Vector2(travel, 0.0))
	await wait_seconds(SETTLE_SECONDS)


func test_the_calendar_is_the_view_you_start_on() -> void:
	assert_eq(_pager.view_index(), ViewPager.CALENDAR_VIEW)
	assert_eq(ViewPager.STATS_VIEW, 0, "stats to the left")
	assert_eq(ViewPager.STORE_VIEW, 2, "store to the right")


func test_a_tap_reaches_the_view_showing() -> void:
	_press(ON_THE_PAGE)
	_release(ON_THE_PAGE)
	assert_eq(GameState.total_rips, 1, "the tap ripped the page")


func test_swiping_left_brings_the_store_in_from_the_right() -> void:
	await _swipe(-COMMIT_TRAVEL)
	assert_eq(_pager.view_index(), ViewPager.STORE_VIEW)


func test_swiping_right_from_the_calendar_reaches_the_stats() -> void:
	await _swipe(COMMIT_TRAVEL)
	assert_eq(_pager.view_index(), ViewPager.STATS_VIEW)


func test_a_swipe_that_does_not_go_far_enough_springs_back() -> void:
	await _swipe(-80.0)
	assert_eq(_pager.view_index(), ViewPager.CALENDAR_VIEW)


func test_a_swipe_never_also_rips_the_page_under_it() -> void:
	# The reason the pager owns the contact rather than the page doing its own
	# hit-testing: both would otherwise claim the same finger.
	_press(ON_THE_PAGE)
	_move_to(ON_THE_PAGE + Vector2(-COMMIT_TRAVEL, 0.0))
	_release(ON_THE_PAGE + Vector2(-COMMIT_TRAVEL, 0.0))
	await wait_seconds(SETTLE_SECONDS)

	assert_eq(GameState.total_rips, 0, "a swipe is not a tap")
	assert_eq(_pager.view_index(), ViewPager.STORE_VIEW)


func test_a_press_that_wanders_a_little_is_still_a_tap() -> void:
	_press(ON_THE_PAGE)
	_move_to(ON_THE_PAGE + Vector2(6.0, 4.0))
	_release(ON_THE_PAGE + Vector2(6.0, 4.0))
	assert_eq(GameState.total_rips, 1, "a shaky finger still rips")


func test_the_edges_do_not_swipe_off_the_end() -> void:
	await _swipe(COMMIT_TRAVEL)
	await _swipe(COMMIT_TRAVEL)
	assert_eq(_pager.view_index(), ViewPager.STATS_VIEW, "there is nothing left of stats")

	await _swipe(-COMMIT_TRAVEL)
	await _swipe(-COMMIT_TRAVEL)
	await _swipe(-COMMIT_TRAVEL)
	assert_eq(_pager.view_index(), ViewPager.STORE_VIEW, "and nothing right of the store")


func test_a_vertical_drag_is_not_a_swipe() -> void:
	_press(Vector2(360.0, 300.0))
	_move_to(Vector2(360.0, 700.0))
	_release(Vector2(360.0, 700.0))
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_pager.view_index(), ViewPager.CALENDAR_VIEW, "up and down goes nowhere")


func test_a_press_on_the_ui_band_above_is_left_alone() -> void:
	# The pause button lives up there, and it is a real Button.
	_press(Vector2(360.0, 40.0))
	_move_to(Vector2(10.0, 40.0))
	_release(Vector2(10.0, 40.0))
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_pager.view_index(), ViewPager.CALENDAR_VIEW)


func test_a_second_finger_is_ignored() -> void:
	_touch(ON_THE_PAGE, true, 1)
	_drag(ON_THE_PAGE + Vector2(-COMMIT_TRAVEL, 0.0), 1)
	_touch(ON_THE_PAGE + Vector2(-COMMIT_TRAVEL, 0.0), false, 1)
	await wait_seconds(SETTLE_SECONDS)

	assert_eq(GameState.total_rips, 0, "no second contact is ever consulted")
	assert_eq(_pager.view_index(), ViewPager.CALENDAR_VIEW)


func test_one_finger_swipes_the_same_way_the_mouse_does() -> void:
	var start := Vector2(360.0, 600.0)
	_touch(start, true)
	_drag(start + Vector2(-COMMIT_TRAVEL, 0.0))
	_touch(start + Vector2(-COMMIT_TRAVEL, 0.0), false)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_pager.view_index(), ViewPager.STORE_VIEW)


func test_movement_without_a_press_does_nothing() -> void:
	_move_to(Vector2(60.0, 600.0), false)
	_move_to(Vector2(660.0, 600.0), false)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_pager.view_index(), ViewPager.CALENDAR_VIEW, "hovering is not a swipe")


func test_the_edges_carry_a_chevron_you_can_tap() -> void:
	# Three dots in a corner told a play tester nothing. A chevron on the edge
	# is the hint, and tapping it moves as well, so the swipe is an option
	# rather than the only way through.
	var arrows: ViewArrows = _screen.get_node("%ViewArrows")
	var right: Vector2 = arrows.zone(1).get_center() + _pager.global_position
	_press(right)
	_release(right)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_pager.view_index(), ViewPager.STORE_VIEW, "tapped through to the store")

	var left: Vector2 = arrows.zone(-1).get_center() + _pager.global_position
	_press(left)
	_release(left)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_pager.view_index(), ViewPager.CALENDAR_VIEW, "and back again")


func test_the_end_of_the_row_has_no_chevron_pointing_off_it() -> void:
	var arrows: ViewArrows = _screen.get_node("%ViewArrows")
	assert_true(arrows.has_view(-1), "the calendar has the stats to its left")
	assert_true(arrows.has_view(1), "and the store to its right")

	_pager.go_to(ViewPager.STATS_VIEW)
	await wait_seconds(SETTLE_SECONDS)
	assert_false(arrows.has_view(-1), "nothing left of the stats")
	assert_true(arrows.has_view(1))

	_pager.go_to(ViewPager.STORE_VIEW)
	await wait_seconds(SETTLE_SECONDS)
	assert_false(arrows.has_view(1), "nothing right of the store")


func test_a_chevron_can_never_steal_a_tap_meant_for_the_calendar() -> void:
	# The guardrail that keeps the two from fighting: every calendar is sized
	# to stop short of both tap zones, so a rip and a page change can never
	# both claim the same point. It is checked here rather than trusted,
	# because it is a relationship between two constants in different files.
	var arrows: ViewArrows = _screen.get_node("%ViewArrows")
	var view: CalendarView = _screen.get_node("%CalendarView")
	for tier: int in CalendarTier.TIER_COUNT:
		GameState.tier_index = tier
		view.rebuild()
		await wait_process_frames(1)

		var page: Rect2 = view.page_rect()
		var label: String = CalendarTier.tier_name(tier)
		assert_false(arrows.zone(-1).intersects(page), "%s must clear the left chevron" % label)
		assert_false(arrows.zone(1).intersects(page), "%s must clear the right chevron" % label)


func test_a_tap_on_the_stats_view_does_nothing_at_all() -> void:
	_pager.go_to(ViewPager.STATS_VIEW)
	await wait_seconds(SETTLE_SECONDS)
	_press(Vector2(360.0, 500.0))
	_release(Vector2(360.0, 500.0))
	assert_eq(GameState.total_rips, 0, "there is nothing to tap on the stats view")
