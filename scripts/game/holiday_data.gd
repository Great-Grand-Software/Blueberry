class_name HolidayData
extends RefCounted
## The holidays that are worth a point, and where they sit in the year.
##
## Points come from holidays and from nothing else — most rips award nothing,
## which is what makes a page with a holiday on it feel like something. Eight
## of them, all on fixed dates, so no rule here has to know about weekdays.
##
## Eight is inside the 6-10 the brief asks for. They are not spread evenly
## through the year — Q1 and Q4 hold three each, Q2 and Q3 one apiece — so a
## quarterly page is worth anywhere from one to three points depending on which
## quarter it is. What is always true is that a whole year is worth eight, on
## every tier, and that is the invariant the upgrades rest on.

## Fixed-date holidays, in calendar order: 0-based month, 1-based day, name.
const HOLIDAYS: Array[Dictionary] = [
	{"month": 0, "day": 1, "name": "New Year's Day"},
	{"month": 1, "day": 14, "name": "Valentine's Day"},
	{"month": 2, "day": 17, "name": "St. Patrick's Day"},
	{"month": 3, "day": 1, "name": "April Fools' Day"},
	{"month": 6, "day": 4, "name": "Independence Day"},
	{"month": 9, "day": 31, "name": "Halloween"},
	{"month": 10, "day": 11, "name": "Veterans Day"},
	{"month": 11, "day": 25, "name": "Christmas Day"},
]

const HOLIDAY_COUNT: int = 8
const POINTS_PER_HOLIDAY: int = 1


## Day-of-year (0-based) that the holiday at `holiday_index` falls on.
static func year_day_of(holiday_index: int) -> int:
	var holiday: Dictionary = HOLIDAYS[posmod(holiday_index, HOLIDAY_COUNT)]
	return CalendarData.month_start_day(int(holiday["month"])) + int(holiday["day"]) - 1


## True if a holiday falls on this day-of-year.
static func is_holiday(year_day: int) -> bool:
	return name_on(year_day) != ""


## The holiday on this day-of-year, or "" if the day is an ordinary one.
static func name_on(year_day: int) -> String:
	var wrapped: int = CalendarData.normalize_year_day(year_day)
	for index: int in HOLIDAY_COUNT:
		if year_day_of(index) == wrapped:
			return str(HOLIDAYS[index]["name"])
	return ""


## Every holiday inside a span of `day_count` days starting at `first_year_day`,
## in the order the span reaches them.
##
## A tap at the Yearly tier spans the whole 365 days, so the span can wrap past
## New Year. Offsets are taken modulo the year rather than by walking the days,
## which keeps this a loop over eight holidays no matter how long the span is.
static func names_in_span(first_year_day: int, day_count: int) -> PackedStringArray:
	var found: Array[Dictionary] = []
	var span: int = clampi(day_count, 0, CalendarData.DAYS_PER_YEAR)
	var start: int = CalendarData.normalize_year_day(first_year_day)
	for index: int in HOLIDAY_COUNT:
		var offset: int = posmod(year_day_of(index) - start, CalendarData.DAYS_PER_YEAR)
		if offset < span:
			found.append({"offset": offset, "name": str(HOLIDAYS[index]["name"])})

	found.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return int(a["offset"]) < int(b["offset"])
	)

	var names: PackedStringArray = []
	for entry: Dictionary in found:
		names.append(str(entry["name"]))
	return names


## How many holidays a span contains. Same span rules as `names_in_span`.
static func count_in_span(first_year_day: int, day_count: int) -> int:
	return names_in_span(first_year_day, day_count).size()
