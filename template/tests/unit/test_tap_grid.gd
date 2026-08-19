extends GutTest

## Tests for TapGrid.
##
## Note what is asserted: the guardrails, not just the happy path. cell_count()
## being bounded by named constants is the property that keeps the node count
## from growing with data, so it is worth a test of its own.

var _grid: TapGrid


func before_each() -> void:
	_grid = TapGrid.new(500.0)


func test_the_first_cell_is_index_zero() -> void:
	assert_eq(_grid.cell_at(Vector2(1.0, 1.0)), 0, "top-left point maps to cell 0")


func test_the_last_cell_is_hit_testable() -> void:
	var last: int = _grid.cell_count() - 1
	assert_eq(_grid.cell_at(Vector2(499.0, 499.0)), last, "bottom-right maps to the last cell")


func test_points_outside_the_grid_are_not_cells() -> void:
	assert_eq(_grid.cell_at(Vector2(-1.0, 10.0)), -1, "left of the grid")
	assert_eq(_grid.cell_at(Vector2(10.0, 500.0)), -1, "below the grid")


func test_every_cell_maps_to_exactly_one_index() -> void:
	var seen: Dictionary = {}
	for index: int in range(_grid.cell_count()):
		var centre: Vector2 = _grid.cell_origin(index) + Vector2.ONE * (_grid.cell_size() * 0.5)
		var got: int = _grid.cell_at(centre)
		assert_false(seen.has(got), "cell %d claimed twice" % got)
		seen[got] = true
	assert_eq(seen.size(), _grid.cell_count(), "every cell is reachable")


func test_cell_count_is_bounded_by_named_constants() -> void:
	assert_eq(_grid.cell_count(), TapGrid.COLUMNS * TapGrid.ROWS, "count comes from constants")
	assert_lt(_grid.cell_count(), 64, "stays under the 64-node ceiling in CLAUDE.md §4")
