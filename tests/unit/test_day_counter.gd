extends GutTest
## Unit tests for turning elapsed days into the date on the page.


func test_the_calendar_opens_on_the_first_of_january() -> void:
	var parts: Dictionary = DayCounter.decompose(0)
	assert_eq(parts["years"], 0)
	assert_eq(parts["month_index"], 0)
	assert_eq(parts["day_of_month"], 1)
	assert_eq(DayCounter.year_of(0), DayCounter.FIRST_YEAR)


func test_a_single_day() -> void:
	var parts: Dictionary = DayCounter.decompose(1)
	assert_eq(parts["day_of_month"], 2, "2 January")
	assert_eq(parts["month_index"], 0)


func test_a_date_partway_through_the_year() -> void:
	# Day 303 is 31 October, which is Halloween.
	var parts: Dictionary = DayCounter.decompose(303)
	assert_eq(parts["month_index"], 9)
	assert_eq(parts["day_of_month"], 31)
	assert_eq(parts["years"], 0)


func test_a_full_year_rolls_the_year_over() -> void:
	var parts: Dictionary = DayCounter.decompose(CalendarData.DAYS_PER_YEAR)
	assert_eq(parts["years"], 1)
	assert_eq(parts["month_index"], 0)
	assert_eq(parts["day_of_month"], 1, "back to the 1st of January")
	assert_eq(DayCounter.year_of(CalendarData.DAYS_PER_YEAR), DayCounter.FIRST_YEAR + 1)


func test_the_decomposition_recombines_into_the_input() -> void:
	# Lossless for every count, which is what lets the date be derived from
	# one running number instead of being tracked separately.
	for total: int in [0, 1, 30, 59, 364, 365, 366, 4001, 99999, 1234567]:
		assert_eq(
			DayCounter.recombine(DayCounter.decompose(total)),
			total,
			"decompose(%d) must recombine exactly" % total
		)


func test_every_day_of_a_year_round_trips() -> void:
	for year_day: int in CalendarData.DAYS_PER_YEAR:
		var elapsed: int = CalendarData.DAYS_PER_YEAR * 7 + year_day
		assert_eq(DayCounter.recombine(DayCounter.decompose(elapsed)), elapsed)
		assert_eq(DayCounter.year_day_of(elapsed), year_day)


func test_there_is_no_cap() -> void:
	# The game has no end state, so the year simply keeps climbing.
	var huge: int = CalendarData.DAYS_PER_YEAR * 987654
	assert_eq(DayCounter.year_of(huge), 987654 + DayCounter.FIRST_YEAR)


func test_negative_input_is_clamped() -> void:
	var parts: Dictionary = DayCounter.decompose(-5)
	assert_eq(parts["years"], 0, "the calendar never runs backwards")
	assert_eq(parts["day_of_month"], 1)


func test_the_date_reads_as_one_line() -> void:
	assert_eq(DayCounter.format_date(0), "1 JAN  YEAR 1")
	assert_eq(DayCounter.format_date(303), "31 OCT  YEAR 1")
	assert_eq(DayCounter.format_date(CalendarData.DAYS_PER_YEAR), "1 JAN  YEAR 2")
