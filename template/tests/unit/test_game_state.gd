extends GutTest

## Tests for the GameState autoload.

func before_each() -> void:
	GameState.reset()


func after_all() -> void:
	GameState.reset()


func test_starts_at_zero() -> void:
	assert_eq(GameState.total_taps(), 0, "a fresh state has no taps")


func test_registering_a_tap_increments_the_total() -> void:
	GameState.register_tap()
	GameState.register_tap()
	assert_eq(GameState.total_taps(), 2, "two taps counted")


func test_registering_a_tap_emits_the_signal() -> void:
	watch_signals(GameState)
	GameState.register_tap()
	assert_signal_emitted_with_parameters(GameState, "taps_changed", [1])
