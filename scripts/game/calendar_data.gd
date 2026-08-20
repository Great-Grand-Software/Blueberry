class_name CalendarData
extends RefCounted
## Static facts about the year the calendar rips through.
##
## Months are their real lengths and the year is a flat 365 days, with no leap
## day. Real lengths are what let the holiday table sit on real dates — the
## 31st of October has to exist for Halloween to — and dropping the leap day
## keeps every year identical, so a tier's taps-per-year stays a constant
## instead of shifting every fourth year.
##
## This replaced a uniform 30-day month, which existed to make the old
## day-odometer an exact nested ladder. The score is holidays now, not days,
## so nothing depends on the ladder any more. See DESIGN.md.

const MONTH_NAMES: PackedStringArray = [
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
]

const MONTH_ABBREVIATIONS: PackedStringArray = [
	"JAN",
	"FEB",
	"MAR",
	"APR",
	"MAY",
	"JUN",
	"JUL",
	"AUG",
	"SEP",
	"OCT",
	"NOV",
	"DEC",
]

const MONTH_LENGTHS: PackedInt32Array = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

const MONTH_COUNT: int = 12
const DAYS_PER_YEAR: int = 365
const MONTHS_PER_QUARTER: int = 3
const QUARTER_COUNT: int = 4

const QUARTER_NAMES: PackedStringArray = ["Q1", "Q2", "Q3", "Q4"]


## Wraps `month_index` into 0..11, so the calendar can loop forever.
static func normalize_month(month_index: int) -> int:
	return posmod(month_index, MONTH_COUNT)


## Wraps a day-of-year into 0..364. Day 0 is the 1st of January.
static func normalize_year_day(year_day: int) -> int:
	return posmod(year_day, DAYS_PER_YEAR)


## Display name of the given month, wrapping out-of-range indices.
static func month_name(month_index: int) -> String:
	return MONTH_NAMES[normalize_month(month_index)]


## Three-letter name of the given month, for the tighter tier layouts.
static func month_abbreviation(month_index: int) -> String:
	return MONTH_ABBREVIATIONS[normalize_month(month_index)]


## How many days the given month holds. 28 for February — always.
static func days_in_month(month_index: int) -> int:
	return MONTH_LENGTHS[normalize_month(month_index)]


## Day-of-year (0-based) that the given month starts on. The loop is bounded
## by MONTH_COUNT, never by data, so it cannot run away.
static func month_start_day(month_index: int) -> int:
	var wrapped: int = normalize_month(month_index)
	var start: int = 0
	for index: int in wrapped:
		start += MONTH_LENGTHS[index]
	return start


## Which month a day-of-year falls in. Bounded by MONTH_COUNT.
static func month_of_year_day(year_day: int) -> int:
	var remaining: int = normalize_year_day(year_day)
	for index: int in MONTH_COUNT:
		var length: int = MONTH_LENGTHS[index]
		if remaining < length:
			return index
		remaining -= length
	return MONTH_COUNT - 1


## Day of the month (1-based) that a day-of-year falls on.
static func day_of_month(year_day: int) -> int:
	var wrapped: int = normalize_year_day(year_day)
	return wrapped - month_start_day(month_of_year_day(wrapped)) + 1


## Which quarter (0..3) the given month belongs to.
static func quarter_of_month(month_index: int) -> int:
	return normalize_month(month_index) / MONTHS_PER_QUARTER


## First month of the given quarter.
static func quarter_first_month(quarter_index: int) -> int:
	return posmod(quarter_index, QUARTER_COUNT) * MONTHS_PER_QUARTER


## How many days the given quarter holds.
static func days_in_quarter(quarter_index: int) -> int:
	var first: int = quarter_first_month(quarter_index)
	var total: int = 0
	for offset: int in MONTHS_PER_QUARTER:
		total += MONTH_LENGTHS[normalize_month(first + offset)]
	return total


## Path to the line drawing for the given month. There are exactly twelve,
## reused unchanged on every loop through the year.
static func month_image_path(month_index: int) -> String:
	return "res://assets/images/months/month_%02d.svg" % (normalize_month(month_index) + 1)
