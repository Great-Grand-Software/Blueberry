extends GutTest
## Leak tests: playing for a long time must not grow memory or node count.
##
## The game has no end state — someone can tap at it indefinitely — so the
## failure mode that actually matters is not "the build is big", it is "memory
## climbs while you play". A build that leaks a little per month will be fine
## in review and dead after an hour.
##
## These assert the engine's own counters, which is the authoritative measure.
## A leak here reproduces in the browser too, where the WebAssembly heap cap is
## far tighter than on desktop.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const FOLD_SETTLE_SECONDS: float = 0.6

## Live nodes must return to the starting count after each month. A handful of
## slack absorbs engine-internal churn; anything more is an accumulation.
const NODE_SLACK: int = 8
## Static memory growth allowed across three months of play, in bytes.
const MEMORY_SLACK_BYTES: float = 4.0 * 1024 * 1024

var _screen: Control


func before_each() -> void:
	GameState.reset_run()
	GameState.best_days = 0
	_screen = GAME_SCENE.instantiate()
	add_child_autofree(_screen)
	await wait_process_frames(3)


func after_all() -> void:
	GameState.reset_run()


func _nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _memory() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC)


func _play_one_month() -> void:
	var host: Control = _screen.get_node("%PageHost")
	for day: int in range(1, CalendarData.DAYS_PER_MONTH + 1):
		var top: MonthPage = host.get_child(host.get_child_count() - 1) as MonthPage
		top.day_tapped.emit(day)
	await wait_seconds(FOLD_SETTLE_SECONDS)


func test_node_count_does_not_grow_across_months() -> void:
	await _play_one_month()
	var baseline: int = _nodes()

	for _month: int in 3:
		await _play_one_month()

	var grown: int = _nodes() - baseline
	assert_lte(
		grown,
		NODE_SLACK,
		"live nodes grew by %d across three months — pages are accumulating" % grown
	)


func test_static_memory_does_not_grow_across_months() -> void:
	await _play_one_month()
	var baseline: float = _memory()

	for _month: int in 3:
		await _play_one_month()

	var grown: float = _memory() - baseline
	assert_lt(
		grown,
		MEMORY_SLACK_BYTES,
		"static memory grew by %.2f MB across three months" % (grown / 1048576.0)
	)


func test_a_long_session_stays_bounded() -> void:
	# Twelve months: a full loop of the calendar and every drawing loaded once.
	# This is the closest thing to "someone left it running".
	await _play_one_month()
	var baseline_nodes: int = _nodes()
	var baseline_memory: float = _memory()

	for _month: int in 12:
		await _play_one_month()

	var node_growth: int = _nodes() - baseline_nodes
	var memory_growth: float = (_memory() - baseline_memory) / 1048576.0
	gut.p("after 12 months: node growth=%d, static memory growth=%.2f MB"
		% [node_growth, memory_growth])

	assert_lte(node_growth, NODE_SLACK, "node count must not climb over a full year")
	assert_lt(memory_growth, 8.0, "static memory must not climb over a full year")
	assert_eq(GameState.total_days, 390, "13 months of taps were actually played")
