extends GutTest
## Unit tests for the multi-unit odometer.


func test_the_ladder_is_exact() -> void:
	assert_eq(DayCounter.DAYS_PER_MONTH, 30)
	assert_eq(DayCounter.DAYS_PER_YEAR, 360, "12 months of 30 days")
	assert_eq(DayCounter.DAYS_PER_DECADE, 3600)
	assert_eq(DayCounter.DAYS_PER_CENTURY, 36000)
	assert_eq(DayCounter.DAYS_PER_MILLENNIUM, 360000)


func test_six_units_are_displayed() -> void:
	assert_eq(DayCounter.UNITS.size(), 6)


func test_zero_is_all_zeros() -> void:
	var parts: Dictionary = DayCounter.decompose(0)
	for unit: Dictionary in DayCounter.UNITS:
		assert_eq(parts[unit["key"]], 0, "%s starts at zero" % unit["key"])


func test_a_single_day() -> void:
	var parts: Dictionary = DayCounter.decompose(1)
	assert_eq(parts["days"], 1)
	assert_eq(parts["months"], 0)
	assert_eq(parts["years"], 0)


func test_thirty_days_is_exactly_one_month() -> void:
	var parts: Dictionary = DayCounter.decompose(30)
	assert_eq(parts["months"], 1)
	assert_eq(parts["days"], 0, "no remainder")


func test_a_full_year() -> void:
	var parts: Dictionary = DayCounter.decompose(360)
	assert_eq(parts["years"], 1)
	assert_eq(parts["months"], 0)
	assert_eq(parts["days"], 0)


func test_a_mixed_reading() -> void:
	# 1 millennium + 2 centuries + 3 decades + 4 years + 5 months + 6 days
	var total: int = 360000 + 2 * 36000 + 3 * 3600 + 4 * 360 + 5 * 30 + 6
	var parts: Dictionary = DayCounter.decompose(total)
	assert_eq(parts["millennia"], 1)
	assert_eq(parts["centuries"], 2)
	assert_eq(parts["decades"], 3)
	assert_eq(parts["years"], 4)
	assert_eq(parts["months"], 5)
	assert_eq(parts["days"], 6)


func test_units_recombine_into_the_input() -> void:
	# The decomposition must be lossless for any count.
	for total: int in [0, 1, 29, 30, 359, 360, 4001, 99999, 1234567]:
		var parts: Dictionary = DayCounter.decompose(total)
		var rebuilt: int = 0
		for unit: Dictionary in DayCounter.UNITS:
			rebuilt += parts[unit["key"]] * int(unit["size"])
		assert_eq(rebuilt, total, "decompose(%d) must recombine exactly" % total)


func test_there_is_no_cap() -> void:
	# The largest unit grows without bound rather than saturating.
	var huge: int = 360000 * 4321
	var parts: Dictionary = DayCounter.decompose(huge)
	assert_eq(parts["millennia"], 4321)


func test_negative_input_is_clamped() -> void:
	var parts: Dictionary = DayCounter.decompose(-5)
	assert_eq(parts["days"], 0, "the counter never runs backwards")


func test_values_are_zero_padded() -> void:
	assert_eq(DayCounter.format_unit(7, "days"), "07")
	assert_eq(DayCounter.format_unit(7, "months"), "00")
	assert_eq(DayCounter.format_unit(7, "millennia"), "000")


func test_the_largest_unit_grows_past_its_padding() -> void:
	assert_eq(DayCounter.format_unit(360000 * 1234, "millennia"), "1234")


func test_format_all_reads_as_one_line() -> void:
	assert_eq(DayCounter.format_all(0), "000 0 0 0 00 00")
	assert_eq(DayCounter.format_all(7), "000 0 0 0 00 07")
	assert_eq(DayCounter.format_all(30), "000 0 0 0 01 00")
