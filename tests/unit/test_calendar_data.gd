extends GutTest
## Unit tests for the static month facts.


func test_twelve_months_exactly() -> void:
	assert_eq(CalendarData.MONTH_COUNT, 12)
	assert_eq(CalendarData.MONTH_NAMES.size(), 12)


func test_months_are_a_uniform_thirty_days() -> void:
	# Deliberate: it makes the counter an exact nested odometer. See DESIGN.md.
	assert_eq(CalendarData.DAYS_PER_MONTH, 30)


func test_month_names() -> void:
	assert_eq(CalendarData.month_name(0), "January")
	assert_eq(CalendarData.month_name(11), "December")


func test_normalize_wraps_both_directions() -> void:
	assert_eq(CalendarData.normalize_month(12), 0, "loops back to January")
	assert_eq(CalendarData.normalize_month(13), 1)
	assert_eq(CalendarData.normalize_month(-1), 11)
	assert_eq(CalendarData.normalize_month(-12), 0)


func test_the_calendar_loops_forever() -> void:
	# Month 1200 is January again; the twelve images repeat unchanged.
	assert_eq(CalendarData.normalize_month(1200), 0)
	assert_eq(CalendarData.month_name(1200), "January")


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
