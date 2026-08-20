extends GutTest
## Unit tests for one page: what it says it holds, and the rip that frees it.

const PAGE_SCENE: PackedScene = preload("res://scenes/calendar_page.tscn")
## Comfortably longer than the tear plus the fall.
const RIP_SETTLE_SECONDS: float = 0.8

var _page: CalendarPage


func before_each() -> void:
	_page = PAGE_SCENE.instantiate()
	add_child_autofree(_page)
	await wait_process_frames(1)


func test_a_daily_page_is_one_day() -> void:
	_page.configure(CalendarTier.DAILY, 0)
	assert_eq(_page.year_day(), 0)
	assert_eq(_page.span_days(), 1)
	assert_eq(_page.holidays(), PackedStringArray(["New Year's Day"]))


func test_a_page_with_nothing_on_it_says_so() -> void:
	_page.configure(CalendarTier.DAILY, 1)
	assert_eq(_page.holidays().size(), 0, "2 January is an ordinary day")


func test_a_monthly_page_spans_its_real_month() -> void:
	_page.configure(CalendarTier.MONTHLY, 31)
	assert_eq(_page.span_days(), 28, "February")
	assert_eq(_page.holidays(), PackedStringArray(["Valentine's Day"]))


func test_a_quarterly_page_lists_every_holiday_it_covers() -> void:
	_page.configure(CalendarTier.QUARTERLY, 0)
	assert_eq(_page.span_days(), 90)
	assert_eq(
		_page.holidays(),
		PackedStringArray(["New Year's Day", "Valentine's Day", "St. Patrick's Day"])
	)


func test_a_yearly_page_covers_the_whole_year() -> void:
	_page.configure(CalendarTier.YEARLY, 0)
	assert_eq(_page.span_days(), CalendarData.DAYS_PER_YEAR)
	assert_eq(_page.holidays().size(), HolidayData.HOLIDAY_COUNT)


func test_a_page_knows_which_calendar_it_came_off() -> void:
	_page.configure(CalendarTier.QUARTERLY, 200)
	assert_eq(_page.tier_index(), CalendarTier.QUARTERLY)


func test_a_page_deep_into_the_future_still_reads_a_real_date() -> void:
	# The game has no end state, so a page has to be addressable at any count.
	var elapsed: int = CalendarData.DAYS_PER_YEAR * 4321 + 303
	_page.configure(CalendarTier.DAILY, elapsed)
	assert_eq(_page.year_day(), 303, "31 October")
	assert_eq(_page.holidays(), PackedStringArray(["Halloween"]))


func test_the_page_carries_the_drawing_for_its_month() -> void:
	_page.configure(CalendarTier.DAILY, CalendarData.month_start_day(6))
	var illustration: MonthImage = _page.get_node("%Illustration")
	assert_eq(illustration.month_index(), 6, "July")


func test_ripping_is_idempotent_and_frees_the_page() -> void:
	_page.configure(CalendarTier.DAILY, 0)
	assert_false(_page.is_ripping())
	_page.rip_off(900.0)
	assert_true(_page.is_ripping())
	_page.rip_off(900.0)

	await wait_seconds(RIP_SETTLE_SECONDS)
	assert_freed(_page, "the page frees itself once it has fallen")


func test_the_rip_carries_the_page_out_of_frame() -> void:
	_page.configure(CalendarTier.DAILY, 0)
	var start: Vector2 = _page.position
	_page.rip_off(900.0)
	await wait_seconds(RIP_SETTLE_SECONDS / 2.0)
	if is_instance_valid(_page):
		assert_gt(_page.position.y, start.y, "the page is falling away")
	await wait_seconds(RIP_SETTLE_SECONDS)
