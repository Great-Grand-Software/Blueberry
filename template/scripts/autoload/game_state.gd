extends Node

## Process-wide state, and the only autoload.
##
## Kept deliberately small: anything that is really screen state belongs on the
## screen. Adding a second autoload needs a reason, and raising MAX_AUTOLOADS
## in project.conf in the same PR.

## Emitted after [member taps] changes, so screens can redraw without polling.
signal taps_changed(total: int)

var _taps: int = 0


## Every tap the player has ever made, across screens.
func total_taps() -> int:
	return _taps


## Records one tap and notifies listeners.
func register_tap() -> void:
	_taps += 1
	taps_changed.emit(_taps)


## Resets the counter. Exists for tests and for a future "new game".
func reset() -> void:
	_taps = 0
	taps_changed.emit(_taps)
