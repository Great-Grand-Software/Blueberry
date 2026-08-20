extends GutTest
## Unit tests for points, the calendar position, and the purchase gate.


func before_each() -> void:
	GameState.reset_run()
	GameState.best_points = 0


func after_all() -> void:
	GameState.reset_run()


## Rips a whole year at whatever tier is set, and returns the points earned.
func _rip_a_year() -> int:
	var before: int = GameState.points
	for _rip: int in CalendarTier.taps_per_year(GameState.tier_index):
		GameState.rip_page()
	return GameState.points - before


## Gets the points into the account without waiting out a year of rips.
func _grant(amount: int) -> void:
	GameState.points = amount
	GameState.best_points = maxi(GameState.best_points, amount)


func test_starts_on_the_daily_calendar_at_new_year() -> void:
	assert_eq(GameState.tier_index, CalendarTier.DAILY)
	assert_eq(GameState.elapsed_days, 0)
	assert_eq(GameState.points, 0)
	assert_eq(GameState.current_span_days(), 1, "one rip, one day")


func test_a_rip_advances_the_calendar_by_one_page() -> void:
	GameState.rip_page()
	assert_eq(GameState.elapsed_days, 1)
	assert_eq(GameState.total_rips, 1)


func test_an_ordinary_day_is_worth_nothing() -> void:
	# 2 January. Most rips award nothing, and that is the design.
	GameState.elapsed_days = 1
	var collected: PackedStringArray = GameState.rip_page()
	assert_eq(collected.size(), 0)
	assert_eq(GameState.points, 0)


func test_a_holiday_is_worth_a_point() -> void:
	var collected: PackedStringArray = GameState.rip_page()
	assert_eq(collected, PackedStringArray(["New Year's Day"]), "1 January")
	assert_eq(GameState.points, 1)
	assert_eq(GameState.holiday_count, 1)


func test_a_year_of_daily_rips_collects_every_holiday_once() -> void:
	assert_eq(_rip_a_year(), HolidayData.HOLIDAY_COUNT)
	assert_eq(GameState.elapsed_days, CalendarData.DAYS_PER_YEAR)
	assert_eq(GameState.total_rips, 365)


func test_a_year_is_worth_the_same_on_every_calendar() -> void:
	# The whole point of an upgrade: the same eight points for fewer rips,
	# never a different amount of points.
	for tier: int in CalendarTier.TIER_COUNT:
		GameState.reset_run()
		GameState.tier_index = tier
		var earned: int = _rip_a_year()
		assert_eq(
			earned,
			HolidayData.HOLIDAY_COUNT,
			"a year on the %s calendar" % CalendarTier.tier_name(tier)
		)
		assert_eq(GameState.elapsed_days, CalendarData.DAYS_PER_YEAR, "exactly one year")


func test_a_coarser_page_collects_every_holiday_it_covers_at_once() -> void:
	GameState.tier_index = CalendarTier.YEARLY
	var collected: PackedStringArray = GameState.rip_page()
	assert_eq(collected.size(), HolidayData.HOLIDAY_COUNT, "one rip, the whole year")
	assert_eq(GameState.points, HolidayData.HOLIDAY_COUNT)


func test_the_page_on_the_wall_lists_what_it_is_worth() -> void:
	GameState.tier_index = CalendarTier.MONTHLY
	assert_eq(GameState.current_holidays(), PackedStringArray(["New Year's Day"]))
	GameState.rip_page()
	assert_eq(GameState.current_holidays(), PackedStringArray(["Valentine's Day"]))


func test_the_calendar_keeps_going_past_a_year() -> void:
	GameState.tier_index = CalendarTier.YEARLY
	for _year: int in 5:
		GameState.rip_page()
	assert_eq(GameState.points, HolidayData.HOLIDAY_COUNT * 5, "no cap, no end state")
	assert_eq(DayCounter.year_of(GameState.elapsed_days), DayCounter.FIRST_YEAR + 5)


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
	assert_eq(GameState.elapsed_days, 0, "the new calendar starts at New Year")
	assert_eq(GameState.total_rips, 0, "tap progress resets on the new tier")


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


func test_signals_fire_for_what_actually_happened() -> void:
	watch_signals(GameState)
	GameState.elapsed_days = 1
	GameState.rip_page()
	assert_signal_emit_count(GameState, "calendar_ripped", 1)
	assert_signal_emit_count(GameState, "holidays_collected", 0, "an ordinary day")

	GameState.elapsed_days = 0
	GameState.rip_page()
	assert_signal_emit_count(GameState, "holidays_collected", 1, "New Year's Day")
	assert_signal_emit_count(GameState, "points_changed", 1)


func test_personal_best_survives_a_reset() -> void:
	GameState.rip_page()
	assert_eq(GameState.best_points, 1)
	GameState.reset_run()
	assert_eq(GameState.points, 0, "the run resets")
	assert_eq(GameState.best_points, 1, "the personal best does not")


func test_best_only_moves_up() -> void:
	GameState.tier_index = CalendarTier.YEARLY
	GameState.rip_page()
	var best: int = GameState.best_points
	_grant(0)
	GameState.reset_run()
	GameState.elapsed_days = 1
	GameState.rip_page()
	assert_eq(GameState.best_points, best, "a worse run cannot lower the best")


func test_progress_survives_a_save_and_reload() -> void:
	GameState.tier_index = CalendarTier.MONTHLY
	GameState.rip_page()
	GameState.rip_page()
	GameState.save_progress()
	var points: int = GameState.points
	var elapsed: int = GameState.elapsed_days

	GameState.reset_run()
	GameState.load_progress()

	assert_eq(GameState.tier_index, CalendarTier.MONTHLY)
	assert_eq(GameState.points, points)
	assert_eq(GameState.elapsed_days, elapsed)


func test_a_tampered_save_cannot_leave_a_page_half_ripped() -> void:
	# A monthly page only lines up with real months if the calendar sits on a
	# boundary, so a restored position that does not is snapped back.
	GameState.tier_index = CalendarTier.MONTHLY
	GameState.elapsed_days = 40
	GameState.points = -7
	GameState.save_progress()

	GameState.reset_run()
	GameState.load_progress()

	assert_eq(GameState.elapsed_days, 31, "snapped back to the 1st of February")
	assert_eq(GameState.points, 0, "a negative total is clamped")
