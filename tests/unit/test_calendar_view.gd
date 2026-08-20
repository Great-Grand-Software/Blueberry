extends GutTest
## Integration tests for the wall: tapping, ripping, and the page cap.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
## Comfortably longer than the tear plus the fall.
const RIP_SETTLE_SECONDS: float = 0.8
## A point on the hanging page, in view-local coordinates. Every calendar
## hangs from the same line and is centred, so one point lands on all four.
const ON_THE_PAGE: Vector2 = Vector2(360.0, 300.0)
## A point on the bare wall below the longest of them.
const ON_THE_WALL: Vector2 = Vector2(360.0, 830.0)

var _screen: Control
var _view: CalendarView


func before_each() -> void:
	GameState.reset_run()
	GameState.best_points = 0
	_screen = GAME_SCENE.instantiate()
	add_child_autofree(_screen)
	_view = _screen.get_node("%CalendarView")
	await wait_process_frames(2)


func after_each() -> void:
	get_tree().paused = false


func after_all() -> void:
	GameState.reset_run()


func test_two_pages_hang_the_one_on_top_and_the_next() -> void:
	assert_eq(_view.live_page_count(), 2, "one to rip, one underneath to reveal")


func test_the_page_underneath_shows_what_the_rip_reveals() -> void:
	var pages: Array[CalendarPage] = _pinned_pages()
	assert_eq(pages[0].year_day(), 0, "1 January on top")
	assert_eq(pages[1].year_day(), 1, "2 January underneath")


func test_a_tap_on_the_page_rips_it() -> void:
	_view.handle_tap(ON_THE_PAGE)
	assert_eq(GameState.elapsed_days, 1)
	assert_eq(GameState.total_rips, 1)


func test_a_tap_on_the_bare_wall_does_nothing() -> void:
	_view.handle_tap(ON_THE_WALL)
	assert_eq(GameState.elapsed_days, 0, "only the calendar is tappable")
	assert_eq(GameState.total_rips, 0)


func test_a_rip_reports_what_it_collected() -> void:
	watch_signals(_view)
	_view.handle_tap(ON_THE_PAGE)
	assert_signal_emitted_with_parameters(
		_view, "page_ripped", [PackedStringArray(["New Year's Day"])]
	)
	assert_eq(GameState.points, 1)


func test_an_ordinary_page_is_ripped_for_nothing() -> void:
	_view.handle_tap(ON_THE_PAGE)
	await wait_process_frames(1)
	_view.handle_tap(ON_THE_PAGE)
	assert_eq(GameState.elapsed_days, 2, "both pages came off")
	assert_eq(GameState.points, 1, "but only New Year's Day scored")


func test_the_page_on_top_is_always_the_current_one() -> void:
	for _rip: int in 4:
		_view.handle_tap(ON_THE_PAGE)
		await wait_process_frames(1)
	assert_eq(_pinned_pages()[0].year_day(), GameState.elapsed_days)


func test_pinned_pages_never_exceed_the_cap() -> void:
	# The core memory guardrail: the calendar runs forever, the node count
	# does not grow. Sixty rips must not accumulate sheets.
	for _rip: int in 60:
		_view.handle_tap(ON_THE_PAGE)
		await wait_process_frames(1)
		assert_lte(
			_view.live_page_count(),
			CalendarView.MAX_LIVE_PAGES,
			"pinned pages must stay within MAX_LIVE_PAGES"
		)


func test_ripping_faster_than_the_fall_cannot_pile_up_sheets() -> void:
	# Every rip in one frame, so no sheet has time to finish falling. What is
	# left has to be the two pinned pages plus at most MAX_FALLING_PAGES.
	for _rip: int in 30:
		_view.handle_tap(ON_THE_PAGE)
	await wait_process_frames(1)
	assert_lte(
		_count_page_nodes(),
		CalendarView.MAX_LIVE_PAGES + CalendarView.MAX_FALLING_PAGES,
		"sheets on their way down are capped too"
	)
	await wait_seconds(RIP_SETTLE_SECONDS)
	assert_eq(_count_page_nodes(), CalendarView.MAX_LIVE_PAGES, "the sheets all cleared")


func test_each_calendar_is_a_different_shape() -> void:
	# Four calendars, four objects — a daily block is not a monthly sheet with
	# less on it. The daily one is the smallest, and square-ish.
	var seen: Dictionary = {}
	for tier: int in CalendarTier.TIER_COUNT:
		var face: Vector2 = CalendarPage.page_size(tier)
		assert_false(
			seen.has(face), "%s reuses another tier's shape" % CalendarTier.tier_name(tier)
		)
		seen[face] = true
		assert_lte(face.x, 640.0, "%s must fit the wall" % CalendarTier.tier_name(tier))
		assert_lte(
			face.y + CalendarView.BACKING_HEIGHT,
			CalendarView.HANGING_REGION,
			"%s must fit between the tack and the flash band" % CalendarTier.tier_name(tier)
		)

	var daily: Vector2 = CalendarPage.page_size(CalendarTier.DAILY)
	var monthly: Vector2 = CalendarPage.page_size(CalendarTier.MONTHLY)
	assert_lt(daily.x, monthly.x, "the daily block is smaller than the month sheet")
	assert_lt(daily.y, monthly.y)
	assert_almost_eq(daily.x / daily.y, 1.0, 0.15, "and it is roughly square")
	assert_gt(
		CalendarPage.page_size(CalendarTier.QUARTERLY).x,
		CalendarPage.page_size(CalendarTier.QUARTERLY).y,
		"the quarterly sheet is a landscape rectangle"
	)


func test_every_calendar_is_centred_on_the_wall_whatever_shape_it_is() -> void:
	for tier: int in CalendarTier.TIER_COUNT:
		GameState.tier_index = tier
		_view.rebuild()
		await wait_process_frames(1)

		var page: Rect2 = _view.page_rect()
		var backing: Rect2 = _view.backing_rect()
		var label: String = CalendarTier.tier_name(tier)

		assert_almost_eq(
			page.position.x + page.size.x * 0.5, _view.size.x * 0.5, 1.0, "%s centred" % label
		)
		assert_eq(backing.size.x, page.size.x, "%s: the stub is as wide as the sheet" % label)
		assert_almost_eq(backing.end.y, page.position.y + 6.0, 0.1, "%s hangs off it" % label)
		assert_gte(backing.position.y, CalendarView.MIN_BACKING_TOP, "%s clears the band" % label)
		assert_lte(
			page.end.y, CalendarView.HANGING_REGION, "%s stays out of the flash band" % label
		)
		# Balanced: the gap above the stub matches the gap below the sheet.
		assert_almost_eq(
			backing.position.y,
			CalendarView.HANGING_REGION - page.end.y,
			1.5,
			"%s sits level on the wall" % label
		)
		assert_eq(_pinned_pages()[0].position, page.position, "and the page is placed there")


func test_a_tap_lands_on_whichever_calendar_is_hanging() -> void:
	for tier: int in CalendarTier.TIER_COUNT:
		GameState.reset_run()
		GameState.tier_index = tier
		_view.rebuild()
		await wait_process_frames(1)

		_view.handle_tap(ON_THE_WALL)
		assert_eq(GameState.total_rips, 0, "the bare wall is never tappable")
		_view.handle_tap(ON_THE_PAGE)
		assert_eq(GameState.total_rips, 1, "the %s page is" % CalendarTier.tier_name(tier))


func test_a_bought_calendar_replaces_the_one_on_the_wall() -> void:
	GameState.points = GameState.next_tier_cost()
	assert_true(GameState.buy_upgrade())
	_view.rebuild()
	await wait_process_frames(1)

	assert_eq(_view.live_page_count(), CalendarView.MAX_LIVE_PAGES)
	var pages: Array[CalendarPage] = _pinned_pages()
	assert_eq(pages[0].tier_index(), CalendarTier.MONTHLY, "a different calendar entirely")
	assert_eq(pages[0].span_days(), 31, "one rip is January now")


func test_a_rip_on_the_monthly_calendar_advances_a_whole_month() -> void:
	GameState.tier_index = CalendarTier.MONTHLY
	_view.rebuild()
	await wait_process_frames(1)

	_view.handle_tap(ON_THE_PAGE)
	assert_eq(GameState.elapsed_days, 31, "January came off in one rip")
	assert_eq(_pinned_pages()[0].year_day(), 31, "February is on the wall")


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


## The pages still pinned to the wall, top one first.
func _pinned_pages() -> Array[CalendarPage]:
	var pinned: Array[CalendarPage] = []
	for child: Node in _view.get_children():
		var page := child as CalendarPage
		if page != null and not page.is_ripping():
			pinned.append(page)
	pinned.reverse()
	return pinned


## Every page node under the wall, pinned or falling.
func _count_page_nodes() -> int:
	var count: int = 0
	for child: Node in _view.get_children():
		if child is CalendarPage:
			count += 1
	return count
