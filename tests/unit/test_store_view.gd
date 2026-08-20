extends GutTest
## Tests for the store: the buy button, the affordability gate, and the one
## place the pager deliberately keeps its hands off a contact.
##
## Split from `test_view_pager.gd` only because that file is at gdlint's
## public-method ceiling; these drive the same scene.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
## Comfortably longer than ViewPager.SETTLE_DURATION.
const SETTLE_SECONDS: float = 0.4
## A point over the store's buy button, in viewport coordinates.
const ON_BUY: Vector2 = Vector2(360.0, 738.0)
## Far enough sideways to commit a swipe: over 28% of 720.
const COMMIT_TRAVEL: float = 350.0

var _screen: Control
var _pager: ViewPager
var _store: StoreView


func before_each() -> void:
	GameState.reset_run()
	GameState.best_points = 0
	_screen = GAME_SCENE.instantiate()
	add_child_autofree(_screen)
	_pager = _screen.get_node("%ViewPager")
	_store = _screen.get_node("%StoreView")
	await wait_process_frames(2)


func after_all() -> void:
	GameState.reset_run()


func _buy_button() -> Button:
	return _screen.get_node("%BuyButton")


func _press(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	_pager._input(event)


func _move_to(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	_pager._input(event)


func _release(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = point
	_pager._input(event)


## Puts the store in front with `points` in the account.
func _open_store(points: int) -> void:
	GameState.points = points
	_store.refresh()
	_pager.go_to(ViewPager.STORE_VIEW)
	await wait_seconds(SETTLE_SECONDS)


func test_the_store_sells_when_the_points_are_there() -> void:
	await _open_store(GameState.next_tier_cost())
	assert_false(_buy_button().disabled, "the button is live")

	_buy_button().pressed.emit()
	await wait_seconds(SETTLE_SECONDS)

	assert_eq(GameState.tier_index, CalendarTier.MONTHLY, "the calendar was swapped")
	assert_eq(_pager.view_index(), ViewPager.CALENDAR_VIEW, "and you are sent back to it")


func test_the_store_will_not_sell_on_credit() -> void:
	await _open_store(GameState.next_tier_cost() - 1)

	assert_true(_buy_button().disabled, "the button is off, not merely ignored")
	assert_string_contains(_buy_button().text, "MORE POINT", "and it says what is missing")

	_buy_button().pressed.emit()
	await wait_process_frames(1)
	assert_eq(GameState.tier_index, CalendarTier.DAILY, "one point short buys nothing")


func test_the_button_goes_away_once_there_is_nothing_left_to_sell() -> void:
	GameState.tier_index = CalendarTier.YEARLY
	await _open_store(9999)
	assert_false(_buy_button().visible, "no button where there is no offer")


func test_the_pager_keeps_off_the_buy_button() -> void:
	# The button handles its own contact through the normal GUI path, so the
	# pager must not read it as well — otherwise a press on the button would
	# register as a tap on the store too, and a drag off it would swipe away
	# mid-purchase.
	await _open_store(GameState.next_tier_cost())
	assert_true(
		_store.swallows_contact(ON_BUY - _store.global_position),
		"the store claims the contact over its live button"
	)

	_press(ON_BUY)
	_move_to(ON_BUY + Vector2(-COMMIT_TRAVEL, 0.0))
	_release(ON_BUY + Vector2(-COMMIT_TRAVEL, 0.0))
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_pager.view_index(), ViewPager.STORE_VIEW, "the button owns that contact")


func test_a_dead_button_is_not_a_dead_zone() -> void:
	# Nothing to buy means nothing to claim, so the store can still be swiped
	# off from anywhere on it.
	await _open_store(0)
	assert_false(_store.swallows_contact(ON_BUY - _store.global_position))

	_press(ON_BUY)
	_move_to(ON_BUY + Vector2(COMMIT_TRAVEL, 0.0))
	_release(ON_BUY + Vector2(COMMIT_TRAVEL, 0.0))
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_pager.view_index(), ViewPager.CALENDAR_VIEW, "swiped away from the store")


func test_the_buy_button_is_the_one_accent_in_the_game() -> void:
	await _open_store(GameState.next_tier_cost())
	var style: StyleBox = _buy_button().get_theme_stylebox("normal")
	assert_true(style is StyleBoxFlat, "really styled, not drawn to look like a button")
	assert_eq((style as StyleBoxFlat).bg_color, Palette.ACCENT, "pale blue")


func test_the_accent_is_the_only_colour_in_the_palette() -> void:
	# Everything else is a near-neutral. `scripts/check-constraints.sh` holds
	# the same line across every file; this holds it for the palette itself.
	var accent_chroma: float = _chroma(Palette.ACCENT)
	assert_gt(accent_chroma, 0.05, "the accent is a real colour")
	for shade: Color in [
		Palette.INK,
		Palette.PAPER,
		Palette.RULE,
		Palette.MUTED,
		Palette.WALL,
		Palette.WALL_GRAIN,
		Palette.WALL_SEAM,
		Palette.BAND,
		Palette.BAND_TEXT,
		Palette.BAND_MUTED,
		Palette.SHADOW,
	]:
		assert_lte(_chroma(shade), 0.05, "%s must stay neutral" % shade)


func _chroma(shade: Color) -> float:
	return maxf(shade.r, maxf(shade.g, shade.b)) - minf(shade.r, minf(shade.g, shade.b))
