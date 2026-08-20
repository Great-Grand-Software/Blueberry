extends GutTest
## Unit tests for the four calendars and the cost of moving up.


func test_there_are_four_tiers_in_order() -> void:
	assert_eq(CalendarTier.TIER_COUNT, 4)
	assert_eq(CalendarTier.TIERS.size(), 4)
	assert_eq(CalendarTier.tier_name(CalendarTier.DAILY), "Daily")
	assert_eq(CalendarTier.tier_name(CalendarTier.MONTHLY), "Monthly")
	assert_eq(CalendarTier.tier_name(CalendarTier.QUARTERLY), "Quarterly")
	assert_eq(CalendarTier.tier_name(CalendarTier.YEARLY), "Yearly")


func test_taps_per_year_matches_the_brief() -> void:
	assert_eq(CalendarTier.taps_per_year(CalendarTier.DAILY), 365)
	assert_eq(CalendarTier.taps_per_year(CalendarTier.MONTHLY), 12)
	assert_eq(CalendarTier.taps_per_year(CalendarTier.QUARTERLY), 4)
	assert_eq(CalendarTier.taps_per_year(CalendarTier.YEARLY), 1)


func test_tiers_clamp_rather_than_wrap() -> void:
	# Unlike the calendar itself, the ladder has a top and a bottom.
	assert_eq(CalendarTier.normalize(-3), 0)
	assert_eq(CalendarTier.normalize(9), CalendarTier.YEARLY)


func test_a_daily_rip_is_one_day_wherever_it_lands() -> void:
	for year_day: int in [0, 58, 200, 364]:
		assert_eq(CalendarTier.span_days(CalendarTier.DAILY, year_day), 1)


func test_a_monthly_rip_spans_the_real_month_it_is_on() -> void:
	assert_eq(CalendarTier.span_days(CalendarTier.MONTHLY, 0), 31, "January")
	assert_eq(CalendarTier.span_days(CalendarTier.MONTHLY, 31), 28, "February")
	assert_eq(CalendarTier.span_days(CalendarTier.MONTHLY, 334), 31, "December")


func test_a_quarterly_rip_spans_its_whole_quarter() -> void:
	assert_eq(CalendarTier.span_days(CalendarTier.QUARTERLY, 0), 90, "Q1: 31+28+31")
	assert_eq(CalendarTier.span_days(CalendarTier.QUARTERLY, 90), 91, "Q2: 30+31+30")


func test_a_yearly_rip_spans_the_whole_year() -> void:
	assert_eq(CalendarTier.span_days(CalendarTier.YEARLY, 0), CalendarData.DAYS_PER_YEAR)


func test_a_year_of_rips_lands_exactly_on_new_year_again() -> void:
	# The guardrail that keeps monthly and quarterly pages on real boundaries
	# forever: a page always spans to the next boundary, never past it.
	for tier: int in CalendarTier.TIER_COUNT:
		var cursor: int = 0
		for _rip: int in CalendarTier.taps_per_year(tier):
			cursor += CalendarTier.span_days(tier, cursor)
		assert_eq(
			cursor,
			CalendarData.DAYS_PER_YEAR,
			"%s must take exactly a year, not a day more" % CalendarTier.tier_name(tier)
		)


func test_the_ladder_is_priced_in_decades_then_centuries_then_millennia() -> void:
	# A year is eight points on every calendar, so the price is really a span
	# of in-game time: ten years, then a hundred, then a thousand.
	var expected_years: Array[int] = [10, 100, 1000]
	for tier: int in CalendarTier.TIER_COUNT - 1:
		assert_eq(
			CalendarTier.upgrade_cost(tier) / HolidayData.HOLIDAY_COUNT,
			expected_years[tier],
			"the %s upgrade" % CalendarTier.tier_name(tier)
		)
	assert_eq(CalendarTier.upgrade_cost(CalendarTier.DAILY), 80)
	assert_eq(CalendarTier.upgrade_cost(CalendarTier.MONTHLY), 800)
	assert_eq(CalendarTier.upgrade_cost(CalendarTier.QUARTERLY), 8000)


func test_the_first_upgrade_is_a_real_stretch() -> void:
	# The brief asks for at least 30 points, and roughly eight to ten years of
	# the daily calendar before the first upgrade is in reach.
	var first: int = CalendarTier.upgrade_cost(CalendarTier.DAILY)
	assert_gte(first, 30, "at least thirty points")
	assert_between(first / HolidayData.HOLIDAY_COUNT, 8, 10, "eight to ten years of ripping")


func test_costs_escalate_exponentially() -> void:
	assert_eq(CalendarTier.upgrade_cost(CalendarTier.DAILY), CalendarTier.BASE_COST)
	assert_eq(
		CalendarTier.upgrade_cost(CalendarTier.MONTHLY),
		CalendarTier.BASE_COST * CalendarTier.COST_RATIO
	)
	assert_eq(
		CalendarTier.upgrade_cost(CalendarTier.QUARTERLY),
		CalendarTier.BASE_COST * CalendarTier.COST_RATIO * CalendarTier.COST_RATIO
	)


func test_each_upgrade_costs_strictly_more_than_the_last() -> void:
	var previous: int = 0
	for tier: int in CalendarTier.TIER_COUNT - 1:
		var cost: int = CalendarTier.upgrade_cost(tier)
		assert_gt(cost, previous, "tier %d must cost more than the one below" % tier)
		previous = cost


func test_the_top_tier_has_nothing_left_to_buy() -> void:
	assert_true(CalendarTier.has_upgrade(CalendarTier.QUARTERLY))
	assert_false(CalendarTier.has_upgrade(CalendarTier.YEARLY))
	assert_eq(CalendarTier.upgrade_cost(CalendarTier.YEARLY), -1)


func test_every_tier_names_its_unit() -> void:
	assert_eq(CalendarTier.unit_name(CalendarTier.DAILY), "DAY")
	assert_eq(CalendarTier.unit_name(CalendarTier.YEARLY), "YEAR")
