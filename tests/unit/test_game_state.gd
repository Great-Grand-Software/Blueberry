extends GutTest
## Unit tests for the score, the calendar position, and the personal best.


func before_each() -> void:
	GameState.reset_run()
	GameState.best_days = 0


func after_all() -> void:
	GameState.reset_run()


func _mark_whole_month() -> bool:
	var completed: bool = false
	for day: int in range(1, CalendarData.DAYS_PER_MONTH + 1):
		completed = GameState.mark_day(day)
	return completed


func test_starts_on_january_with_nothing_marked() -> void:
	assert_eq(GameState.month_index, 0)
	assert_eq(GameState.total_days, 0)
	assert_eq(GameState.days_remaining(), 30)
	assert_eq(GameState.current_month_name(), "January")


func test_marking_a_day_scores_it() -> void:
	var completed: bool = GameState.mark_day(1)
	assert_false(completed, "one day does not finish the month")
	assert_eq(GameState.total_days, 1)
	assert_true(GameState.is_day_marked(1))
	assert_eq(GameState.days_remaining(), 29)


func test_re_tapping_a_marked_day_does_nothing() -> void:
	GameState.mark_day(5)
	GameState.mark_day(5)
	GameState.mark_day(5)
	assert_eq(GameState.total_days, 1, "a double-tap cannot inflate the score")


func test_out_of_range_days_are_rejected() -> void:
	assert_false(GameState.mark_day(0))
	assert_false(GameState.mark_day(31))
	assert_false(GameState.mark_day(-1))
	assert_eq(GameState.total_days, 0)


func test_thirty_taps_completes_the_month() -> void:
	var completed: bool = _mark_whole_month()
	assert_true(completed, "the thirtieth tap completes the month")
	assert_eq(GameState.total_days, 30)
	assert_eq(GameState.month_index, 1, "advanced to February")
	assert_eq(GameState.days_remaining(), 30, "the new page is blank")


func test_the_calendar_loops_after_twelve_months() -> void:
	for _month: int in 12:
		_mark_whole_month()
	assert_eq(GameState.total_days, 360, "a full year of taps")
	assert_eq(GameState.month_index, 0, "back to January, same twelve drawings")


func test_the_count_keeps_climbing_past_a_year() -> void:
	for _month: int in 13:
		_mark_whole_month()
	assert_eq(GameState.total_days, 390, "no cap, no end state")
	assert_eq(GameState.month_index, 1)


func test_day_marked_signal_fires_once_per_new_day() -> void:
	watch_signals(GameState)
	GameState.mark_day(1)
	GameState.mark_day(1)
	GameState.mark_day(2)
	assert_signal_emit_count(GameState, "day_marked", 2)


func test_month_completed_signal_fires_once_per_month() -> void:
	watch_signals(GameState)
	_mark_whole_month()
	assert_signal_emit_count(GameState, "month_completed", 1)


func test_personal_best_survives_a_reset() -> void:
	_mark_whole_month()
	assert_eq(GameState.best_days, 30)
	GameState.reset_run()
	assert_eq(GameState.total_days, 0, "the run resets")
	assert_eq(GameState.best_days, 30, "the personal best does not")


func test_best_only_moves_up() -> void:
	_mark_whole_month()
	GameState.reset_run()
	GameState.mark_day(1)
	assert_eq(GameState.best_days, 30, "a shorter run cannot lower the best")


func test_progress_survives_a_save_and_reload() -> void:
	GameState.mark_day(3)
	GameState.mark_day(9)
	GameState.save_progress()

	GameState.reset_run()
	GameState.load_progress()

	assert_eq(GameState.total_days, 2)
	assert_true(GameState.is_day_marked(3))
	assert_true(GameState.is_day_marked(9))
	assert_false(GameState.is_day_marked(4))
