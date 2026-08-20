extends GutTest
## Unit tests for the static facts about the year.


func test_twelve_months_exactly() -> void:
	assert_eq(CalendarData.MONTH_COUNT, 12)
	assert_eq(CalendarData.MONTH_NAMES.size(), 12)
	assert_eq(CalendarData.MONTH_ABBREVIATIONS.size(), 12)
	assert_eq(CalendarData.MONTH_LENGTHS.size(), 12)


func test_months_are_their_real_lengths() -> void:
	# Real lengths are what let holidays sit on real dates — the 31st of
	# October has to exist for Halloween to. See DESIGN.md.
	assert_eq(CalendarData.days_in_month(0), 31, "January")
	assert_eq(CalendarData.days_in_month(1), 28, "February, never 29")
	assert_eq(CalendarData.days_in_month(3), 30, "April")
	assert_eq(CalendarData.days_in_month(11), 31, "December")


func test_the_year_is_a_flat_365_days() -> void:
	var total: int = 0
	for month: int in CalendarData.MONTH_COUNT:
		total += CalendarData.days_in_month(month)
	assert_eq(total, CalendarData.DAYS_PER_YEAR)
	assert_eq(total, 365, "no leap day, so every year is identical")


func test_month_names_and_abbreviations() -> void:
	assert_eq(CalendarData.month_name(0), "January")
	assert_eq(CalendarData.month_name(11), "December")
	assert_eq(CalendarData.month_abbreviation(9), "OCT")


func test_normalize_wraps_both_directions() -> void:
	assert_eq(CalendarData.normalize_month(12), 0, "loops back to January")
	assert_eq(CalendarData.normalize_month(-1), 11)
	assert_eq(CalendarData.normalize_year_day(365), 0)
	assert_eq(CalendarData.normalize_year_day(-1), 364)


func test_month_starts_run_end_to_end() -> void:
	assert_eq(CalendarData.month_start_day(0), 0, "the 1st of January is day zero")
	assert_eq(CalendarData.month_start_day(1), 31, "February starts after January")
	assert_eq(CalendarData.month_start_day(11), 334, "December starts on day 334")


func test_every_day_of_the_year_maps_back_to_its_own_date() -> void:
	# The round trip has to be exact for all 365 days, because the holiday
	# table and every page title are addressed by day-of-year.
	for year_day: int in CalendarData.DAYS_PER_YEAR:
		var month: int = CalendarData.month_of_year_day(year_day)
		var day: int = CalendarData.day_of_month(year_day)
		assert_between(
			day,
			1,
			CalendarData.days_in_month(month),
			"day %d of month %d is in range" % [day, month]
		)
		assert_eq(
			CalendarData.month_start_day(month) + day - 1,
			year_day,
			"day-of-year %d must rebuild from its own date" % year_day
		)


func test_known_dates_land_where_they_should() -> void:
	assert_eq(CalendarData.month_of_year_day(0), 0, "1 January")
	assert_eq(CalendarData.day_of_month(0), 1)
	assert_eq(CalendarData.month_of_year_day(364), 11, "31 December")
	assert_eq(CalendarData.day_of_month(364), 31)
	# 31 October, which only exists because months are their real lengths.
	assert_eq(CalendarData.month_of_year_day(303), 9)
	assert_eq(CalendarData.day_of_month(303), 31)


func test_quarters_cover_the_year_exactly_once() -> void:
	var total: int = 0
	for quarter: int in CalendarData.QUARTER_COUNT:
		total += CalendarData.days_in_quarter(quarter)
	assert_eq(total, CalendarData.DAYS_PER_YEAR, "four quarters, one year")
	assert_eq(CalendarData.quarter_of_month(0), 0)
	assert_eq(CalendarData.quarter_of_month(11), 3)
	assert_eq(CalendarData.quarter_first_month(2), 6, "Q3 starts in July")


func test_every_month_has_a_drawing_on_disk() -> void:
	for month: int in CalendarData.MONTH_COUNT:
		var path: String = CalendarData.month_image_path(month)
		assert_true(ResourceLoader.exists(path), "missing drawing: %s" % path)


func test_image_paths_wrap_with_the_calendar() -> void:
	assert_eq(
		CalendarData.month_image_path(12),
		CalendarData.month_image_path(0),
		"looping reuses the same twelve drawings"
	)
