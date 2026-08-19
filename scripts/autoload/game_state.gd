extends Node
## Process-wide game state: the raw day count, the calendar position, and the
## locally saved personal best.
##
## Autoloaded as `GameState`. There is no end state — no win, no loss, no cap.
## The count simply climbs for as long as anyone keeps tapping.

signal day_marked(total_days: int)
signal month_completed(month_index: int)

const SAVE_PATH: String = "user://blueberry.cfg"
const SAVE_SECTION: String = "progress"

## Every day ever tapped in this run. This is the score.
var total_days: int = 0
## The best `total_days` ever reached on this device.
var best_days: int = 0
## Which of the twelve months is on top. Wraps forever.
var month_index: int = 0
## Which day numbers on the current page have been crossed off, 1-based.
var marked_days: Dictionary = {}


func _ready() -> void:
	load_progress()


## Human-readable name of the month currently on top.
func current_month_name() -> String:
	return CalendarData.month_name(month_index)


## How many days on the current page are still unmarked.
func days_remaining() -> int:
	return CalendarData.DAYS_PER_MONTH - marked_days.size()


## True if `day_number` on the current page has already been crossed off.
func is_day_marked(day_number: int) -> bool:
	return marked_days.has(day_number)


## Crosses off one day. Returns true when that tap completed the month.
## Re-tapping an already-marked day does nothing and returns false, so a
## double-tap can never inflate the score.
func mark_day(day_number: int) -> bool:
	if day_number < 1 or day_number > CalendarData.DAYS_PER_MONTH:
		return false
	if marked_days.has(day_number):
		return false

	marked_days[day_number] = true
	total_days += 1
	best_days = maxi(best_days, total_days)
	day_marked.emit(total_days)

	var completed: bool = marked_days.size() >= CalendarData.DAYS_PER_MONTH
	if completed:
		marked_days.clear()
		month_index = CalendarData.normalize_month(month_index + 1)
		month_completed.emit(month_index)
	save_progress()
	return completed


## Starts a fresh run at January day one. The personal best survives.
func reset_run() -> void:
	total_days = 0
	month_index = 0
	marked_days.clear()


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, "best_days", best_days)
	config.set_value(SAVE_SECTION, "total_days", total_days)
	config.set_value(SAVE_SECTION, "month_index", month_index)
	config.set_value(SAVE_SECTION, "marked_days", marked_days.keys())
	var error: int = config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save progress to %s (error %d)" % [SAVE_PATH, error])


func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	best_days = config.get_value(SAVE_SECTION, "best_days", 0)
	total_days = config.get_value(SAVE_SECTION, "total_days", 0)
	month_index = CalendarData.normalize_month(config.get_value(SAVE_SECTION, "month_index", 0))

	# A hand-edited save must not be able to put the page in an impossible
	# state, so every restored day is range-checked on the way in.
	marked_days.clear()
	for day: Variant in config.get_value(SAVE_SECTION, "marked_days", []):
		var day_number: int = int(day)
		if day_number >= 1 and day_number <= CalendarData.DAYS_PER_MONTH:
			marked_days[day_number] = true
