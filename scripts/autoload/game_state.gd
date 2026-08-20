extends Node
## Process-wide game state: points, which calendar is on the wall, how far
## through the year it has been ripped, and the locally saved best.
##
## Autoloaded as `GameState`. There is no end state — no win, no loss, no cap.
## The calendar keeps going for as long as anyone keeps ripping.

signal calendar_ripped(elapsed_days: int)
signal points_changed(points: int)
signal holidays_collected(names: PackedStringArray)
signal tier_changed(tier_index: int)

const SAVE_PATH: String = "user://blueberry.cfg"
const SAVE_SECTION: String = "progress"

## Points earned. One per holiday ripped past; ordinary days award nothing.
var points: int = 0
## The most points ever held at once on this device.
var best_points: int = 0
## Which of the four calendars is on the wall. See CalendarTier.
var tier_index: int = 0
## Days ripped away across the whole run. Buying a calendar moves this on to
## the next New Year rather than resetting it, so the year keeps climbing —
## it is the record of how far the run has got.
var elapsed_days: int = 0
## Pages ripped in this run, whatever each one was worth. Lifetime, not
## per-calendar: it reads as part of the score, and a score that resets on a
## purchase is a punishment for upgrading.
var total_rips: int = 0
## Holidays collected in this run.
var holiday_count: int = 0

## Set while a save is waiting for the end of the frame. See `_queue_save`.
var _save_queued: bool = false


func _ready() -> void:
	load_progress()


## Day-of-year (0-based) the page currently on the wall opens on.
func current_year_day() -> int:
	return DayCounter.year_day_of(elapsed_days)


## How many days the page on the wall covers — one at Daily, a whole year at
## Yearly, and the real length of the month or quarter in between.
func current_span_days() -> int:
	return CalendarTier.span_days(tier_index, current_year_day())


## The holidays printed on the page currently on the wall, in date order.
## Empty on most pages; that is the point.
func current_holidays() -> PackedStringArray:
	return HolidayData.names_in_span(current_year_day(), current_span_days())


## Rips the page off. Advances the calendar by whatever this tier's page
## covers and banks a point for every holiday that page held. Returns the
## holidays collected, so the caller can show them without recomputing.
func rip_page() -> PackedStringArray:
	var collected: PackedStringArray = current_holidays()

	elapsed_days += current_span_days()
	total_rips += 1
	calendar_ripped.emit(elapsed_days)

	if not collected.is_empty():
		holiday_count += collected.size()
		points += collected.size() * HolidayData.POINTS_PER_HOLIDAY
		best_points = maxi(best_points, points)
		holidays_collected.emit(collected)
		points_changed.emit(points)

	_queue_save()
	return collected


## Points needed for the next calendar, or -1 when there is none left to buy.
func next_tier_cost() -> int:
	return CalendarTier.upgrade_cost(tier_index)


## True when a next calendar exists and the points are already in hand.
func can_afford_upgrade() -> bool:
	if not CalendarTier.has_upgrade(tier_index):
		return false
	return points >= next_tier_cost()


## Buys the next calendar. Spends the points, swaps the tier, and hangs the new
## calendar on the 1st of January of the following year — a new object, not a
## faster old one.
##
## It moves forward to New Year rather than back to zero for two reasons: a
## monthly or quarterly page only lines up if the calendar starts on a
## boundary, and the year is the player's record of the whole run. Ripping
## through a thousand years and then being sent back to 2026 would throw that
## away. Returns false and changes nothing if it cannot be afforded.
func buy_upgrade() -> bool:
	if not can_afford_upgrade():
		return false

	points -= next_tier_cost()
	tier_index = CalendarTier.normalize(tier_index + 1)
	elapsed_days = DayCounter.next_new_year(elapsed_days)

	tier_changed.emit(tier_index)
	points_changed.emit(points)
	_queue_save()
	return true


## The year currently printed on the calendar. No ceiling.
func current_year() -> int:
	return DayCounter.year_of(elapsed_days)


## Starts over on the first calendar, back at the opening year. The personal
## best survives.
func reset_run() -> void:
	points = 0
	tier_index = 0
	elapsed_days = 0
	total_rips = 0
	holiday_count = 0


## Collapses every change made in one frame into a single write. A rip can
## move several counters at once, and saving per counter would turn that into
## several ConfigFile allocations and several browser storage writes.
func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	save_progress.call_deferred()


func save_progress() -> void:
	_save_queued = false
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, "points", points)
	config.set_value(SAVE_SECTION, "best_points", best_points)
	config.set_value(SAVE_SECTION, "tier_index", tier_index)
	config.set_value(SAVE_SECTION, "elapsed_days", elapsed_days)
	config.set_value(SAVE_SECTION, "total_rips", total_rips)
	config.set_value(SAVE_SECTION, "holiday_count", holiday_count)
	var error: int = config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save progress to %s (error %d)" % [SAVE_PATH, error])


func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	# A hand-edited save must not be able to put the wall in an impossible
	# state, so everything restored is clamped on the way in.
	points = maxi(int(config.get_value(SAVE_SECTION, "points", 0)), 0)
	best_points = maxi(int(config.get_value(SAVE_SECTION, "best_points", 0)), points)
	tier_index = CalendarTier.normalize(int(config.get_value(SAVE_SECTION, "tier_index", 0)))
	elapsed_days = maxi(int(config.get_value(SAVE_SECTION, "elapsed_days", 0)), 0)
	total_rips = maxi(int(config.get_value(SAVE_SECTION, "total_rips", 0)), 0)
	holiday_count = maxi(int(config.get_value(SAVE_SECTION, "holiday_count", 0)), 0)

	# Monthly and quarterly pages only line up with real month boundaries if
	# the calendar starts on one. A restored position that does not is snapped
	# back rather than left to drift a page at a time.
	elapsed_days = _snap_to_page_boundary(elapsed_days)


## Rounds an elapsed-day count down to the start of the page it falls inside,
## so every rip from here lands on a real boundary. Bounded by the number of
## pages in a year at the coarsest tier, never by the data.
func _snap_to_page_boundary(days: int) -> int:
	var year_day: int = DayCounter.year_day_of(days)
	if CalendarTier.span_days(tier_index, 0) == 1:
		return days

	var whole_years: int = days - year_day
	var cursor: int = 0
	for _page: int in CalendarTier.taps_per_year(tier_index):
		var span: int = CalendarTier.span_days(tier_index, cursor)
		if year_day < cursor + span:
			return whole_years + cursor
		cursor += span
	return whole_years
