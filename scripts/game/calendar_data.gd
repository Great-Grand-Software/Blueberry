class_name CalendarData
extends RefCounted
## Static month facts.
##
## Months are a uniform 30 days. That is a deliberate simplification, not an
## oversight: it makes the multi-unit counter a clean nested odometer
## (30 days = 1 month, 12 months = 1 year) instead of a lumpy approximation,
## and the brief calls for "roughly thirty taps" per month either way.
## Real 28/30/31-day months are an open slot — see DESIGN.md.

const MONTH_NAMES: PackedStringArray = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]

const MONTH_COUNT: int = 12
const DAYS_PER_MONTH: int = 30


## Wraps `month_index` into 0..11, so the calendar can loop forever.
static func normalize_month(month_index: int) -> int:
	return posmod(month_index, MONTH_COUNT)


## Display name of the given month, wrapping out-of-range indices.
static func month_name(month_index: int) -> String:
	return MONTH_NAMES[normalize_month(month_index)]


## Path to the line drawing for the given month. There are exactly twelve,
## reused unchanged on every loop through the year.
static func month_image_path(month_index: int) -> String:
	return "res://assets/images/months/month_%02d.svg" % (normalize_month(month_index) + 1)
