class_name DayCounter
extends RefCounted
## Turns the running count of days ripped away into the date the wall reads.
##
## The calendar starts on the 1st of January of Year 1 and never stops, so the
## count is unbounded and the year is simply however many whole 365-day years
## have gone by. Nothing here caps or rounds: `recombine(decompose(n)) == n`
## for every n, which is what `test_day_counter.gd` asserts.
##
## This used to be a six-unit odometer, because the score used to be days
## tapped. The score is holidays now, so what the player wants from this number
## is the date, not a unit ladder. See DESIGN.md.

## The year the calendar opens on. Year 1 reads better on the page than Year 0.
const FIRST_YEAR: int = 1


## Splits elapsed days into the date they land on: how many whole years have
## passed, which month, and which day of that month. Negative input is clamped
## to zero — the calendar never runs backwards.
static func decompose(elapsed_days: int) -> Dictionary:
	var total: int = maxi(elapsed_days, 0)
	var years: int = total / CalendarData.DAYS_PER_YEAR
	var year_day: int = total % CalendarData.DAYS_PER_YEAR
	var month_index: int = CalendarData.month_of_year_day(year_day)
	return {
		"years": years,
		"year_day": year_day,
		"month_index": month_index,
		"day_of_month": CalendarData.day_of_month(year_day),
	}


## The inverse of `decompose`. Kept so the round trip can be asserted rather
## than assumed.
static func recombine(parts: Dictionary) -> int:
	return int(parts["years"]) * CalendarData.DAYS_PER_YEAR + int(parts["year_day"])


## The date as one short line, e.g. "17 MAR YEAR 3".
static func format_date(elapsed_days: int) -> String:
	var parts: Dictionary = decompose(elapsed_days)
	return (
		"%d %s  YEAR %d"
		% [
			int(parts["day_of_month"]),
			CalendarData.month_abbreviation(int(parts["month_index"])),
			int(parts["years"]) + FIRST_YEAR,
		]
	)


## The year showing on the calendar, counting from FIRST_YEAR. No cap.
static func year_of(elapsed_days: int) -> int:
	return maxi(elapsed_days, 0) / CalendarData.DAYS_PER_YEAR + FIRST_YEAR


## Day-of-year (0-based) the calendar is currently open on.
static func year_day_of(elapsed_days: int) -> int:
	return maxi(elapsed_days, 0) % CalendarData.DAYS_PER_YEAR
