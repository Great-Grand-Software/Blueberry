extends GutTest
## Unit tests for turning elapsed days into the date on the page.


func test_the_calendar_opens_on_new_years_day_of_the_starting_year() -> void:
	var parts: Dictionary = DayCounter.decompose(0)
	assert_eq(parts["years"], 0)
	assert_eq(parts["month_index"], 0)
	assert_eq(parts["day_of_month"], 1)
	assert_eq(DayCounter.year_of(0), CalendarData.START_YEAR)
	assert_eq(CalendarData.START_YEAR, 2026)


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
	assert_eq(DayCounter.year_of(CalendarData.DAYS_PER_YEAR), CalendarData.START_YEAR + 1)


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
	# The game has no end state, so the year simply keeps climbing. A long run
	# really does reach the far future, and that is the point of showing it.
	assert_eq(DayCounter.year_of(CalendarData.DAYS_PER_YEAR * 1000), CalendarData.START_YEAR + 1000)
	var huge: int = CalendarData.DAYS_PER_YEAR * 987654
	assert_eq(DayCounter.year_of(huge), 987654 + CalendarData.START_YEAR)


func test_new_year_is_the_next_boundary_forward_not_a_reset() -> void:
	# A purchase moves the calendar here. It must never hand back years
	# already ripped, because the year is the record of the whole run.
	assert_eq(DayCounter.next_new_year(0), 0, "already on New Year")
	assert_eq(DayCounter.next_new_year(1), CalendarData.DAYS_PER_YEAR)
	assert_eq(DayCounter.next_new_year(364), CalendarData.DAYS_PER_YEAR)
	assert_eq(
		DayCounter.next_new_year(CalendarData.DAYS_PER_YEAR),
		CalendarData.DAYS_PER_YEAR,
		"a boundary stays put"
	)
	for elapsed: int in [0, 1, 200, 365, 900, 40000]:
		var moved: int = DayCounter.next_new_year(elapsed)
		assert_gte(moved, elapsed, "never backwards")
		assert_eq(DayCounter.year_day_of(moved), 0, "always lands on the 1st of January")


func test_big_numbers_are_grouped_so_they_can_be_read() -> void:
	assert_eq(DayCounter.with_separators(0), "0")
	assert_eq(DayCounter.with_separators(80), "80")
	assert_eq(DayCounter.with_separators(800), "800")
	assert_eq(DayCounter.with_separators(8000), "8,000")
	assert_eq(DayCounter.with_separators(1234567), "1,234,567")
	assert_eq(DayCounter.with_separators(-4200), "-4,200")


func test_negative_input_is_clamped() -> void:
	var parts: Dictionary = DayCounter.decompose(-5)
	assert_eq(parts["years"], 0, "the calendar never runs backwards")
	assert_eq(parts["day_of_month"], 1)


func test_the_date_reads_as_one_line_with_a_real_year() -> void:
	assert_eq(DayCounter.format_date(0), "1 JAN 2026")
	assert_eq(DayCounter.format_date(303), "31 OCT 2026")
	assert_eq(DayCounter.format_date(CalendarData.DAYS_PER_YEAR), "1 JAN 2027")
	assert_eq(DayCounter.format_date(CalendarData.DAYS_PER_YEAR * 2001), "1 JAN 4027")
