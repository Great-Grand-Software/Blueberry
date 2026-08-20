extends GutTest
## Tests for the note that pops up when a rip scores.
##
## Split from `test_calendar_view.gd` only because that file is at gdlint's
## public-method ceiling; these drive the same wall.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
## A point on the hanging page, in view-local coordinates.
const ON_THE_PAGE: Vector2 = Vector2(360.0, 300.0)

var _screen: Control
var _view: CalendarView


func before_each() -> void:
	GameState.reset_run()
	GameState.best_points = 0
	_screen = GAME_SCENE.instantiate()
	add_child_autofree(_screen)
	_view = _screen.get_node("%CalendarView")
	await wait_process_frames(2)


func after_all() -> void:
	GameState.reset_run()


func test_a_scoring_rip_pops_the_note_above_every_sheet() -> void:
	# The note is its own node, last on the wall, because children draw after
	# their parent: a badge painted by the wall lands behind the calendar, and
	# the whole point of moving it to the top of the sheet was to get it out
	# from behind the player's hand.
	var flash: PointFlash = _view.get_node("%PointFlash")
	assert_false(flash.is_showing(), "nothing to say yet")

	_view.handle_tap(ON_THE_PAGE)
	await wait_process_frames(2)
	assert_true(flash.is_showing(), "New Year's Day scored")
	assert_eq(
		_view.get_child(_view.get_child_count() - 1),
		flash,
		"the note must be the last child, or a sheet covers it"
	)

	await wait_seconds(PointFlash.DURATION + 0.2)
	assert_false(flash.is_showing(), "and it clears itself")


func test_an_ordinary_rip_says_nothing() -> void:
	var flash: PointFlash = _view.get_node("%PointFlash")
	GameState.elapsed_days = 1
	_view.rebuild()
	await wait_process_frames(1)

	_view.handle_tap(ON_THE_PAGE)
	await wait_process_frames(2)
	assert_false(flash.is_showing(), "2 January is worth nothing, and says so by saying nothing")
