class_name MonthImage
extends TextureRect
## The square line drawing above the calendar, one per month.
##
## There are exactly twelve drawings, one theme, reused unchanged every time
## the calendar loops back to January. That repetition is deliberate — see the
## open slots in DESIGN.md.
##
## Only one drawing is ever resident: assigning `texture` drops the previous
## one. Nothing preloads the set.

var _month_index: int = -1


## The month currently on display, or -1 before the first call.
func month_index() -> int:
	return _month_index


## Shows the drawing for `month_index`, wrapping so the twelve loop forever.
func show_month(month_index_value: int) -> void:
	var wrapped: int = CalendarData.normalize_month(month_index_value)
	if wrapped == _month_index:
		return

	var path: String = CalendarData.month_image_path(wrapped)
	if not ResourceLoader.exists(path):
		push_warning("Month drawing missing: %s" % path)
		return

	_month_index = wrapped
	texture = load(path)
