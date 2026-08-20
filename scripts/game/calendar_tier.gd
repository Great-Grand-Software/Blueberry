class_name CalendarTier
extends RefCounted
## The four calendars, and what a rip is worth on each.
##
## A tier is not a speed multiplier bolted onto one object — each is a distinct
## calendar that a rip advances by a different span, and buying one swaps the
## calendar out. What stays constant is the year: every tier still passes the
## same eight holidays per year, so an upgrade buys the same points for fewer
## rips rather than a different amount of points.
##
## Costs are BASE_COST * COST_RATIO^tier: 80, 800 and 8000 points. Because a
## year is worth eight points on every calendar, that reads as a clean ladder of
## in-game time — the first upgrade is ten years of ripping, the second a
## hundred, the third a thousand. The year on the wall is the progress bar.
##
## In actual rips at the tier you are on, that is roughly 3,650, then 1,200,
## then 4,000. The dip in the middle is the point of an upgrade: the monthly
## calendar covers thirty times the year per rip, so a hundred years on it is
## less work than ten years of ripping single days.

## Ordered from the starting tier upward. `span_days` of 0 means the span is
## the real length of whatever month or quarter the rip lands on.
const TIERS: Array[Dictionary] = [
	{"key": "daily", "name": "Daily", "unit": "DAY", "taps_per_year": 365, "span_days": 1},
	{"key": "monthly", "name": "Monthly", "unit": "MONTH", "taps_per_year": 12, "span_days": 0},
	{
		"key": "quarterly",
		"name": "Quarterly",
		"unit": "QUARTER",
		"taps_per_year": 4,
		"span_days": 0
	},
	{"key": "yearly", "name": "Yearly", "unit": "YEAR", "taps_per_year": 1, "span_days": 365},
]

const TIER_COUNT: int = 4

const DAILY: int = 0
const MONTHLY: int = 1
const QUARTERLY: int = 2
const YEARLY: int = 3

## Cost of the first upgrade, in points, and the factor between upgrades.
## 80 points is ten years at eight holidays a year.
const BASE_COST: int = 80
const COST_RATIO: int = 10


## Clamps a tier index into 0..3. Tiers do not wrap — the top is the top.
static func normalize(tier_index: int) -> int:
	return clampi(tier_index, 0, TIER_COUNT - 1)


## Display name of the tier, e.g. "Quarterly".
static func tier_name(tier_index: int) -> String:
	var tier: Dictionary = TIERS[normalize(tier_index)]
	return str(tier["name"])


## What one rip is called on this tier, e.g. "QUARTER".
static func unit_name(tier_index: int) -> String:
	var tier: Dictionary = TIERS[normalize(tier_index)]
	return str(tier["unit"])


## How many rips this tier takes to get through one year.
static func taps_per_year(tier_index: int) -> int:
	var tier_data: Dictionary = TIERS[normalize(tier_index)]
	return int(tier_data["taps_per_year"])


## How many days one rip advances, starting from `year_day`.
##
## Monthly and quarterly spans are the real lengths of the month or quarter
## being ripped, so a rip always lands exactly on the next boundary. Starting
## every tier at the 1st of January is what keeps that alignment true forever.
static func span_days(tier_index: int, year_day: int) -> int:
	var tier: int = normalize(tier_index)
	var tier_data: Dictionary = TIERS[tier]
	var fixed: int = int(tier_data["span_days"])
	if fixed > 0:
		return fixed
	var month: int = CalendarData.month_of_year_day(year_day)
	if tier == QUARTERLY:
		return CalendarData.days_in_quarter(CalendarData.quarter_of_month(month))
	return CalendarData.days_in_month(month)


## True if there is a tier above this one to buy.
static func has_upgrade(tier_index: int) -> bool:
	return normalize(tier_index) < TIER_COUNT - 1


## Points needed to move up from `tier_index`, or -1 at the top tier.
static func upgrade_cost(tier_index: int) -> int:
	if not has_upgrade(tier_index):
		return -1
	var cost: int = BASE_COST
	for _step: int in normalize(tier_index):
		cost *= COST_RATIO
	return cost
