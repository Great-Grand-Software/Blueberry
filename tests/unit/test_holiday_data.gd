extends GutTest
## Unit tests for the holiday table — the only source of points in the game.


func test_the_year_holds_eight_holidays() -> void:
	# The brief asks for roughly six to ten.
	assert_eq(HolidayData.HOLIDAY_COUNT, 8)
	assert_eq(HolidayData.HOLIDAYS.size(), HolidayData.HOLIDAY_COUNT)
	assert_between(HolidayData.HOLIDAY_COUNT, 6, 10)


func test_one_holiday_is_worth_one_point() -> void:
	assert_eq(HolidayData.POINTS_PER_HOLIDAY, 1)


func test_holidays_sit_on_the_dates_they_are_named_for() -> void:
	assert_eq(HolidayData.name_on(0), "New Year's Day", "1 January")
	assert_eq(HolidayData.name_on(CalendarData.month_start_day(9) + 30), "Halloween")
	assert_eq(HolidayData.name_on(CalendarData.month_start_day(11) + 24), "Christmas Day")
	assert_eq(HolidayData.name_on(CalendarData.month_start_day(2) + 16), "St. Patrick's Day")


func test_every_holiday_falls_inside_its_own_month() -> void:
	for index: int in HolidayData.HOLIDAY_COUNT:
		var holiday: Dictionary = HolidayData.HOLIDAYS[index]
		var year_day: int = HolidayData.year_day_of(index)
		assert_eq(CalendarData.month_of_year_day(year_day), int(holiday["month"]))
		assert_eq(CalendarData.day_of_month(year_day), int(holiday["day"]))


func test_holidays_never_share_a_day() -> void:
	var seen: Dictionary = {}
	for index: int in HolidayData.HOLIDAY_COUNT:
		var year_day: int = HolidayData.year_day_of(index)
		assert_false(seen.has(year_day), "two holidays on day %d" % year_day)
		seen[year_day] = true


func test_most_days_are_worth_nothing() -> void:
	# The whole economy rests on this: points are rare because holidays are.
	var scoring: int = 0
	for year_day: int in CalendarData.DAYS_PER_YEAR:
		if HolidayData.is_holiday(year_day):
			scoring += 1
	assert_eq(scoring, HolidayData.HOLIDAY_COUNT)
	assert_eq(HolidayData.name_on(1), "", "2 January is an ordinary day")


func test_a_one_day_span_is_just_that_day() -> void:
	assert_eq(HolidayData.count_in_span(0, 1), 1, "New Year's Day")
	assert_eq(HolidayData.count_in_span(1, 1), 0, "the day after it")


func test_a_whole_year_span_holds_every_holiday_once() -> void:
	# True from any starting day, which is what makes the yearly calendar
	# worth the same as 365 daily rips.
	for start: int in [0, 45, 200, 364]:
		assert_eq(
			HolidayData.count_in_span(start, CalendarData.DAYS_PER_YEAR),
			HolidayData.HOLIDAY_COUNT,
			"a year starting on day %d" % start
		)


func test_a_span_that_wraps_past_new_year_still_counts_correctly() -> void:
	# 25 December to 1 January inclusive: Christmas and New Year's Day.
	var span: PackedStringArray = HolidayData.names_in_span(
		CalendarData.month_start_day(11) + 24, 8
	)
	assert_eq(span, PackedStringArray(["Christmas Day", "New Year's Day"]))


func test_names_come_back_in_the_order_the_span_reaches_them() -> void:
	var first_quarter: PackedStringArray = HolidayData.names_in_span(
		0, CalendarData.days_in_quarter(0)
	)
	assert_eq(
		first_quarter, PackedStringArray(["New Year's Day", "Valentine's Day", "St. Patrick's Day"])
	)


func test_the_quarters_between_them_hold_the_whole_year() -> void:
	# Real dates cluster: three holidays in Q1 and three in Q4, one each in
	# between. A quarterly page is therefore worth one to three points — but
	# the four of them still add up to the year exactly once, which is what
	# keeps a quarterly year worth the same as a daily one.
	var counts: Array[int] = []
	for quarter: int in CalendarData.QUARTER_COUNT:
		var first_month: int = CalendarData.quarter_first_month(quarter)
		counts.append(
			HolidayData.count_in_span(
				CalendarData.month_start_day(first_month), CalendarData.days_in_quarter(quarter)
			)
		)
	assert_eq(counts, [3, 1, 1, 3] as Array[int])

	var total: int = 0
	for count: int in counts:
		total += count
	assert_eq(total, HolidayData.HOLIDAY_COUNT, "four quarters, one year, eight points")


func test_an_empty_span_holds_nothing() -> void:
	assert_eq(HolidayData.count_in_span(0, 0), 0)


func test_a_span_longer_than_a_year_cannot_double_count() -> void:
	# Clamped to the year, so nothing can be collected twice in one rip.
	assert_eq(HolidayData.count_in_span(0, 4000), HolidayData.HOLIDAY_COUNT)
