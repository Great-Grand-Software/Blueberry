class_name DayCounter
extends RefCounted
## Converts a raw count of days into every larger unit at once.
##
## The score is one number — days tapped — but it is shown decomposed across
## six units simultaneously, each padded with leading zeros, so the display
## reads like an odometer that will clearly never fill. There is no cap.
##
## The ladder is exact by construction: 30 days to a month, 12 months to a
## year, then powers of ten. Nothing here rounds or approximates.

const DAYS_PER_MONTH: int = CalendarData.DAYS_PER_MONTH
const MONTHS_PER_YEAR: int = CalendarData.MONTH_COUNT
const DAYS_PER_YEAR: int = DAYS_PER_MONTH * MONTHS_PER_YEAR
const DAYS_PER_DECADE: int = DAYS_PER_YEAR * 10
const DAYS_PER_CENTURY: int = DAYS_PER_DECADE * 10
const DAYS_PER_MILLENNIUM: int = DAYS_PER_CENTURY * 10

## Unit key, short label, days per unit, and how many digits to pad to.
## Ordered largest first, which is the order they are displayed in.
const UNITS: Array[Dictionary] = [
	{"key": "millennia", "label": "MIL", "size": DAYS_PER_MILLENNIUM, "pad": 3},
	{"key": "centuries", "label": "CEN", "size": DAYS_PER_CENTURY, "pad": 1},
	{"key": "decades", "label": "DEC", "size": DAYS_PER_DECADE, "pad": 1},
	{"key": "years", "label": "YRS", "size": DAYS_PER_YEAR, "pad": 1},
	{"key": "months", "label": "MON", "size": DAYS_PER_MONTH, "pad": 2},
	{"key": "days", "label": "DAY", "size": 1, "pad": 2},
]


## Splits `total_days` across every unit, largest first. Each unit holds only
## its own remainder, so the six values recombine exactly into the input.
## Negative input is clamped to zero; the counter never runs backwards.
static func decompose(total_days: int) -> Dictionary:
	var remaining: int = maxi(total_days, 0)
	var result: Dictionary = {}
	for unit: Dictionary in UNITS:
		var size: int = unit["size"]
		result[unit["key"]] = remaining / size
		remaining %= size
	return result


## The value of one unit, zero-padded to its display width. The largest unit
## is never truncated — it simply grows past its padding.
static func format_unit(total_days: int, unit_key: String) -> String:
	var parts: Dictionary = decompose(total_days)
	for unit: Dictionary in UNITS:
		if unit["key"] == unit_key:
			return str(parts[unit_key]).pad_zeros(unit["pad"])
	return ""


## The whole odometer as one line, e.g. "000 0 0 0 00 07".
static func format_all(total_days: int) -> String:
	var parts: PackedStringArray = []
	for unit: Dictionary in UNITS:
		parts.append(format_unit(total_days, unit["key"]))
	return " ".join(parts)
