class_name PointFlash
extends Control
## The "+1 HALLOWEEN" note that pops up when a rip scores.
##
## It is its own node, and the last child of the wall, for one reason: the
## calendar pages are children too, and children draw after their parent. A
## badge painted by the wall itself lands *behind* the sheet, which is exactly
## what happened the first time this was tried over the top of the page.
##
## It pops at the TOP of the sheet, not the bottom. Watching someone play
## settled that: the hand that just tapped is over the middle and lower half of
## the calendar, so a note under the page sits behind the player's own fingers
## at the moment they most need to see why they scored.
##
## Pale blue, because pale blue means points — see DESIGN.md §9.

## Seconds the note is up. Held at full strength for the first half so it is
## read rather than glimpsed; a rip is fast, the reason for it should not be.
const DURATION: float = 1.6
const FADE_SHARPNESS: float = 2.0
## How far it floats up over its life.
const RISE: float = 30.0
## Where it starts, measured down from the top edge of the sheet. Far enough
## that even at full rise the badge clears the heading printed on every face —
## it should announce the point, not hide what page you are on.
const TOP_OFFSET: float = 128.0
const PADDING: Vector2 = Vector2(20.0, 13.0)
const FONT_SIZE: int = 21
const BADGE_HEIGHT: float = 28.0

var _text: String = ""
var _progress: float = 1.0
var _anchor_y: float = 0.0
var _tween: Tween


## Pops the note for `names`, anchored to the top edge of the sheet they came
## off. Calling again restarts it, so a fast tapper always sees the latest.
func show_points(names: PackedStringArray, sheet_top: float) -> void:
	if names.is_empty():
		return
	_text = "+%d   %s" % [names.size(), ", ".join(names).to_upper()]
	_anchor_y = sheet_top
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# A finite tween, redrawing only while the note is up.
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, DURATION)


## Clears the note without playing it out. Used when the calendar is swapped.
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_text = ""
	_progress = 1.0
	queue_redraw()


## True while a note is on screen. Used by the tests.
func is_showing() -> bool:
	return _text != "" and _progress < 1.0


func _set_progress(progress: float) -> void:
	_progress = progress
	queue_redraw()


func _draw() -> void:
	if not is_showing():
		return
	var font: Font = ThemeDB.fallback_font
	var alpha: float = clampf((1.0 - _progress) * FADE_SHARPNESS, 0.0, 1.0)
	var baseline: float = _anchor_y + TOP_OFFSET - RISE * _progress
	var text_width: float = Lettering.width_of(font, _text, FONT_SIZE)
	var badge := Rect2(
		Vector2((size.x - text_width) * 0.5 - PADDING.x, baseline - 22.0 - PADDING.y),
		Vector2(text_width + PADDING.x * 2.0, BADGE_HEIGHT + PADDING.y * 2.0)
	)

	draw_rect(Rect2(badge.position + Vector2(3.0, 3.0), badge.size), Color(Palette.SHADOW, alpha))
	draw_rect(badge, Color(Palette.ACCENT, alpha))
	draw_rect(badge, Color(Palette.INK, alpha), false, 2.0)
	Lettering.draw_centred(
		self,
		font,
		badge.position.x,
		badge.size.x,
		baseline,
		_text,
		FONT_SIZE,
		Color(Palette.INK, alpha),
		Lettering.WEIGHT_BOLD
	)
