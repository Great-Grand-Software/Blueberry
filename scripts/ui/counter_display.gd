extends Control
## The odometer: days tapped, shown across six units at once.
##
## Drawn in a single `_draw()` rather than twelve labels, to keep the node
## count flat and the type crisp. Higher units sit at zero for a very long
## time; that is the point of showing them.

const INK: Color = Color(0.965, 0.961, 0.949)
const MUTED: Color = Color(0.549, 0.545, 0.533)

const VALUE_FONT_SIZE: int = 30
const LABEL_FONT_SIZE: int = 12
const VALUE_BASELINE: float = 38.0
const LABEL_BASELINE: float = 56.0

var _total_days: int = 0


## Updates the reading. Cheap enough to call on every tap.
func set_total_days(total_days: int) -> void:
	if total_days == _total_days:
		return
	_total_days = total_days
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var parts: Dictionary = DayCounter.decompose(_total_days)
	var column_count: int = DayCounter.UNITS.size()
	var column_width: float = size.x / float(column_count)

	for index: int in column_count:
		var unit: Dictionary = DayCounter.UNITS[index]
		var centre: float = (index + 0.5) * column_width
		var value: String = str(parts[unit["key"]]).pad_zeros(unit["pad"])

		var value_width: float = font.get_string_size(
			value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, VALUE_FONT_SIZE
		).x
		draw_string(
			font,
			Vector2(centre - value_width * 0.5, VALUE_BASELINE),
			value,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			VALUE_FONT_SIZE,
			INK
		)

		var label: String = unit["label"]
		var label_width: float = font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_FONT_SIZE
		).x
		draw_string(
			font,
			Vector2(centre - label_width * 0.5, LABEL_BASELINE),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			LABEL_FONT_SIZE,
			MUTED
		)
