extends GutTest
## Unit tests for the purchase ladder: what a calendar costs, what buying one
## does to the run, and what it deliberately does not undo.
##
## Split from `test_game_state.gd` only because that file is at gdlint's
## public-method ceiling; these drive the same autoload.


func before_each() -> void:
	GameState.reset_run()
	GameState.best_points = 0


func after_all() -> void:
	GameState.reset_run()


## Gets the points into the account without waiting out a decade of rips.
func _grant(amount: int) -> void:
	GameState.points = amount
	GameState.best_points = maxi(GameState.best_points, amount)


func test_an_upgrade_is_gated_on_the_points_being_there() -> void:
	assert_false(GameState.can_afford_upgrade(), "nothing earned yet")
	assert_false(GameState.buy_upgrade(), "and so nothing is sold")
	assert_eq(GameState.tier_index, CalendarTier.DAILY)

	_grant(GameState.next_tier_cost() - 1)
	assert_false(GameState.can_afford_upgrade(), "one point short is still short")

	_grant(GameState.next_tier_cost())
	assert_true(GameState.can_afford_upgrade())


func test_buying_swaps_the_calendar_and_spends_the_points() -> void:
	var cost: int = GameState.next_tier_cost()
	_grant(cost + 2)
	GameState.elapsed_days = 200
	GameState.total_rips = 200

	assert_true(GameState.buy_upgrade())
	assert_eq(GameState.tier_index, CalendarTier.MONTHLY)
	assert_eq(GameState.points, 2, "the cost is spent, the rest is kept")
	assert_eq(
		GameState.elapsed_days,
		CalendarData.DAYS_PER_YEAR,
		"the new calendar starts on the next New Year, not back at the beginning"
	)
	assert_eq(GameState.total_rips, 200, "a lifetime count, not a per-calendar one")


func test_buying_never_hands_back_the_years_already_ripped() -> void:
	# The year on the wall is the record of the whole run. Ripping through a
	# thousand years and then being sent back to the start would throw it away.
	GameState.elapsed_days = CalendarData.DAYS_PER_YEAR * 240 + 71
	var before: int = GameState.current_year()
	_grant(GameState.next_tier_cost())

	assert_true(GameState.buy_upgrade())
	assert_eq(GameState.current_year(), before + 1, "rolled on to the next New Year")
	assert_eq(GameState.current_year_day(), 0, "and the new sheet starts on 1 January")


func test_the_top_calendar_cannot_be_upgraded_past() -> void:
	GameState.tier_index = CalendarTier.YEARLY
	_grant(99999)
	assert_eq(GameState.next_tier_cost(), -1)
	assert_false(GameState.can_afford_upgrade())
	assert_false(GameState.buy_upgrade(), "there is nothing above yearly")
	assert_eq(GameState.points, 99999, "and nothing is charged for it")


func test_climbing_every_tier_leaves_the_ladder_at_the_top() -> void:
	for _step: int in CalendarTier.TIER_COUNT - 1:
		_grant(GameState.next_tier_cost())
		assert_true(GameState.buy_upgrade())
	assert_eq(GameState.tier_index, CalendarTier.YEARLY)
	assert_eq(GameState.points, 0)


func test_the_daily_calendar_really_does_take_a_decade_to_climb_off() -> void:
	# Played honestly rather than granted: the first upgrade costs the best part
	# of ten years of ripping single days off. The eightieth holiday is
	# Christmas of the tenth year, so it comes into reach a few days short of
	# the decade — 3,644 rips, against 76 under the old curve.
	var cost: int = GameState.next_tier_cost()
	while GameState.points < cost:
		GameState.rip_page()

	assert_eq(GameState.points, cost)
	assert_eq(GameState.current_year(), CalendarData.START_YEAR + 9, "deep into the tenth year")
	assert_eq(GameState.total_rips, 3644)
	assert_true(GameState.can_afford_upgrade())

	# And buying rolls the calendar on to the New Year that decade ends with.
	assert_true(GameState.buy_upgrade())
	assert_eq(GameState.current_year(), CalendarData.START_YEAR + 10, "2036")
	assert_eq(GameState.current_year_day(), 0)
