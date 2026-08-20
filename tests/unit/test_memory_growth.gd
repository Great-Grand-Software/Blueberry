extends GutTest
## Leak tests: playing for a long time must not grow memory or node count.
##
## The game has no end state — someone can rip at it indefinitely — so the
## failure mode that actually matters is not "the build is big", it is "memory
## climbs while you play". A build that leaks a little per page will be fine in
## review and dead after an hour.
##
## These assert the engine's own counters, which is the authoritative measure.
## A leak here reproduces in the browser too, where the WebAssembly heap cap is
## far tighter than on desktop.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
## Comfortably longer than the tear plus the fall.
const RIP_SETTLE_SECONDS: float = 0.8
## Rips per batch. A month of daily ripping, near enough.
const RIPS_PER_BATCH: int = 30
## A point on the hanging page, in view-local coordinates.
const ON_THE_PAGE: Vector2 = Vector2(360.0, 400.0)

## Live nodes must return to the starting count after each batch. A handful of
## slack absorbs engine-internal churn; anything more is an accumulation.
const NODE_SLACK: int = 8
## Static memory growth allowed across three batches of play, in bytes.
const MEMORY_SLACK_BYTES: float = 4.0 * 1024 * 1024

var _screen: Control
var _view: CalendarView


func before_each() -> void:
	GameState.reset_run()
	GameState.best_points = 0
	_screen = GAME_SCENE.instantiate()
	add_child_autofree(_screen)
	_view = _screen.get_node("%CalendarView")
	await wait_process_frames(3)


func after_all() -> void:
	GameState.reset_run()


func _nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _memory() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC)


func _rip_a_batch() -> void:
	for _rip: int in RIPS_PER_BATCH:
		_view.handle_tap(ON_THE_PAGE)
		await wait_process_frames(1)
	await wait_seconds(RIP_SETTLE_SECONDS)


func test_node_count_does_not_grow_across_batches() -> void:
	await _rip_a_batch()
	var baseline: int = _nodes()

	for _batch: int in 3:
		await _rip_a_batch()

	var grown: int = _nodes() - baseline
	assert_lte(
		grown,
		NODE_SLACK,
		"live nodes grew by %d across three batches — sheets are accumulating" % grown
	)


func test_static_memory_does_not_grow_across_batches() -> void:
	await _rip_a_batch()
	var baseline: float = _memory()

	for _batch: int in 3:
		await _rip_a_batch()

	var grown: float = _memory() - baseline
	assert_lt(
		grown,
		MEMORY_SLACK_BYTES,
		"static memory grew by %.2f MB across three batches" % (grown / 1048576.0)
	)


func test_a_long_session_stays_bounded() -> void:
	# A full year of daily ripping: every drawing loaded once, every holiday
	# collected once. This is the closest thing to "someone left it running".
	await _rip_a_batch()
	var baseline_nodes: int = _nodes()
	var baseline_memory: float = _memory()

	for _batch: int in 12:
		await _rip_a_batch()

	var node_growth: int = _nodes() - baseline_nodes
	var memory_growth: float = (_memory() - baseline_memory) / 1048576.0
	gut.p(
		(
			"after %d rips: node growth=%d, static memory growth=%.2f MB"
			% [GameState.total_rips, node_growth, memory_growth]
		)
	)

	assert_lte(node_growth, NODE_SLACK, "node count must not climb over a year of ripping")
	assert_lt(memory_growth, 8.0, "static memory must not climb over a year of ripping")
	assert_eq(GameState.total_rips, RIPS_PER_BATCH * 13, "the rips were actually played")


func test_swapping_the_calendar_frees_the_old_one() -> void:
	# A purchase rebuilds the wall from scratch. Doing that three times must
	# not leave three calendars' worth of sheets behind.
	await _rip_a_batch()
	var baseline: int = _nodes()

	for _step: int in CalendarTier.TIER_COUNT - 1:
		GameState.points = GameState.next_tier_cost()
		assert_true(GameState.buy_upgrade())
		_view.rebuild()
		await wait_process_frames(2)

	assert_eq(GameState.tier_index, CalendarTier.YEARLY)
	assert_lte(_nodes() - baseline, NODE_SLACK, "the old calendars were freed")
