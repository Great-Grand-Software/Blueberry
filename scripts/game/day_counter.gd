class_name DayCounter
extends RefCounted
## Turns the running count of days ripped away into the date on the wall, and
## formats the numbers the readouts print.
##
## The calendar opens on the 1st of January 2026 and never stops, so the count
## is unbounded and the year is simply however many whole 365-day years have
## gone by on top of it. Nothing here caps or rounds:
## `recombine(decompose(n)) == n` for every n, which `test_day_counter.gd`
## asserts.
##
## This is where display formatting lives, because the date is the thing most
## of it is for. `with_separators` is here rather than in a class of its own so
## the header, the stats view and the store all group their digits the same way.


## Splits elapsed days into the date they land on: how many whole years have
## passed, which month, and which day of that month. Negative input is clamped
## to zero — the calendar never runs backwards.
static func decompose(elapsed_days: int) -> Dictionary:
	var total: int = maxi(elapsed_days, 0)
	var years: int = total / CalendarData.DAYS_PER_YEAR
	var year_day: int = total % CalendarData.DAYS_PER_YEAR
	return {
		"years": years,
		"year_day": year_day,
		"month_index": CalendarData.month_of_year_day(year_day),
		"day_of_month": CalendarData.day_of_month(year_day),
	}


## The inverse of `decompose`. Kept so the round trip can be asserted rather
## than assumed.
static func recombine(parts: Dictionary) -> int:
	return int(parts["years"]) * CalendarData.DAYS_PER_YEAR + int(parts["year_day"])


## The year printed on the calendar. Starts at CalendarData.START_YEAR and has
## no ceiling — a long run really does reach the year 6782.
static func year_of(elapsed_days: int) -> int:
	return maxi(elapsed_days, 0) / CalendarData.DAYS_PER_YEAR + CalendarData.START_YEAR


## Day-of-year (0-based) the calendar is currently open on.
static func year_day_of(elapsed_days: int) -> int:
	return maxi(elapsed_days, 0) % CalendarData.DAYS_PER_YEAR


## Elapsed days at the 1st of January following `elapsed_days`. A day already
## on New Year stays where it is. This is where a purchase moves the calendar
## to: a fresh sheet starting on a real boundary, without giving back the years
## already ripped.
static func next_new_year(elapsed_days: int) -> int:
	var total: int = maxi(elapsed_days, 0)
	var into_the_year: int = year_day_of(total)
	if into_the_year == 0:
		return total
	return total + CalendarData.DAYS_PER_YEAR - into_the_year


## The date as one short line, e.g. "17 MAR 2029".
static func format_date(elapsed_days: int) -> String:
	var parts: Dictionary = decompose(elapsed_days)
	return (
		"%d %s %d"
		% [
			int(parts["day_of_month"]),
			CalendarData.month_abbreviation(int(parts["month_index"])),
			year_of(elapsed_days),
		]
	)


## Groups a count in threes, e.g. 8000 -> "8,000". Points and rip counts run to
## five figures on a long game, and an ungrouped run of digits is the thing that
## makes a big score unreadable. Bounded by the digits in the number.
static func with_separators(value: int) -> String:
	var digits: String = str(absi(value))
	var grouped: String = ""
	var placed: int = 0
	for index: int in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		placed += 1
		if placed % 3 == 0 and index > 0:
			grouped = "," + grouped
	return "-" + grouped if value < 0 else grouped
