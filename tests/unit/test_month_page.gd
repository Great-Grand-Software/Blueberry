extends GutTest
## Unit tests for the calendar page: hit testing, marking, and the fold.

const PAGE_SCENE: PackedScene = preload("res://scenes/month_page.tscn")
## Comfortably longer than MonthPage.FOLD_DURATION.
const FOLD_SETTLE_SECONDS: float = 0.55

var _page: MonthPage


func before_each() -> void:
	_page = PAGE_SCENE.instantiate()
	add_child_autofree(_page)
	_page.size = Vector2(420, 420)
	_page.configure(0, {})
	await wait_process_frames(1)


func test_the_grid_holds_every_day_of_the_month() -> void:
	assert_eq(MonthPage.COLUMNS * MonthPage.ROWS, 35)
	assert_gte(
		MonthPage.COLUMNS * MonthPage.ROWS,
		CalendarData.DAYS_PER_MONTH,
		"the grid must have room for every day"
	)


func test_the_first_cell_is_day_one() -> void:
	assert_eq(_page.day_at_position(Vector2(10, 10)), 1)


func test_the_last_day_is_hit_testable() -> void:
	# Day 30 is the last cell of the fifth row: column index 1, row index 4.
	var cell := Vector2(420.0 / MonthPage.COLUMNS, 420.0 / MonthPage.ROWS)
	var point := Vector2(cell.x * 1.5, cell.y * 4.5)
	assert_eq(_page.day_at_position(point), 30)


func test_cells_past_the_last_day_are_not_days() -> void:
	# The five trailing blanks are what make it read as a wall calendar.
	var cell := Vector2(420.0 / MonthPage.COLUMNS, 420.0 / MonthPage.ROWS)
	var point := Vector2(cell.x * 6.5, cell.y * 4.5)
	assert_eq(_page.day_at_position(point), 0, "cell 35 is blank")


func test_points_outside_the_page_are_not_days() -> void:
	assert_eq(_page.day_at_position(Vector2(-5, 10)), 0)
	assert_eq(_page.day_at_position(Vector2(10, -5)), 0)
	assert_eq(_page.day_at_position(Vector2(500, 10)), 0)
	assert_eq(_page.day_at_position(Vector2(10, 500)), 0)


func test_every_day_maps_to_exactly_one_cell() -> void:
	var seen: Dictionary = {}
	var cell := Vector2(420.0 / MonthPage.COLUMNS, 420.0 / MonthPage.ROWS)
	for row: int in MonthPage.ROWS:
		for column: int in MonthPage.COLUMNS:
			var point := Vector2((column + 0.5) * cell.x, (row + 0.5) * cell.y)
			var day: int = _page.day_at_position(point)
			if day > 0:
				assert_false(seen.has(day), "day %d mapped twice" % day)
				seen[day] = true
	assert_eq(seen.size(), CalendarData.DAYS_PER_MONTH, "all 30 days reachable")


func test_configure_reports_its_month() -> void:
	_page.configure(7, {})
	assert_eq(_page.month_index(), 7)


func test_folding_is_idempotent_and_frees_the_page() -> void:
	assert_false(_page.is_folding())
	_page.fold_down()
	assert_true(_page.is_folding())
	_page.fold_down()

	await wait_seconds(FOLD_SETTLE_SECONDS)
	assert_freed(_page, "the page frees itself once the fold finishes")


func test_the_fold_collapses_the_page() -> void:
	_page.fold_down()
	await wait_seconds(FOLD_SETTLE_SECONDS / 2.0)
	if is_instance_valid(_page):
		assert_lt(_page.scale.y, 1.0, "the page is collapsing downward")
	await wait_seconds(FOLD_SETTLE_SECONDS)
