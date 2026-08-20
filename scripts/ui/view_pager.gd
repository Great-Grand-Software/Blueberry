class_name ViewPager
extends Control
## Three views side by side, moved between by dragging one contact sideways.
##
## Every gameplay contact below the UI band arrives here first, and this is the
## only place that decides what it was: a drag past SWIPE_THRESHOLD is a swipe,
## and anything that presses and lifts inside TAP_SLOP is a tap, handed on to
## whichever view is showing. One owner for the finger is what keeps a swipe
## that starts on the calendar from also ripping the page under it.
##
## It is still one point of contact — pressed, moved, released. Touch index 0
## or the left mouse button, and nothing else: no second finger is consulted
## and no gesture event is read, so the single-contact rule in CLAUDE.md holds.

signal view_changed(view_index: int)

## Left to right. Calendar is the middle one, so both others are one swipe away.
const VIEW_COUNT: int = 3
const STATS_VIEW: int = 0
const CALENDAR_VIEW: int = 1
const STORE_VIEW: int = 2

## Sideways travel that turns a press into a swipe rather than a tap.
const SWIPE_THRESHOLD: float = 34.0
## How far a press may wander and still count as a tap on release.
const TAP_SLOP: float = 16.0
## Fraction of a screen width that commits the swipe to the next view.
const COMMIT_FRACTION: float = 0.28
const SETTLE_DURATION: float = 0.22

var _view_index: int = CALENDAR_VIEW
var _views: Array[Control] = []
var _contact_down: bool = false
var _swiping: bool = false
var _press_point: Vector2 = Vector2.ZERO
var _press_offset: float = 0.0
var _settle_tween: Tween

@onready var _track: Control = %Track
@onready var _arrows: ViewArrows = %ViewArrows


func _ready() -> void:
	for child: Node in _track.get_children():
		if _views.size() >= VIEW_COUNT:
			break
		if child is Control:
			_views.append(child as Control)
	resized.connect(_layout_views)
	_layout_views()
	_arrows.set_view(_view_index, _views.size())


## Which view is showing.
func view_index() -> int:
	return _view_index


## The view currently showing, or null before `_ready`.
func current_view() -> Control:
	if _view_index < 0 or _view_index >= _views.size():
		return null
	return _views[_view_index]


## Moves to a view without a swipe — used after a purchase, which sends the
## player back to the wall to see what they bought.
func go_to(view_index_value: int, animate: bool = true) -> void:
	var target: int = clampi(view_index_value, 0, _views.size() - 1)
	var changed: bool = target != _view_index
	_view_index = target
	_arrows.set_view(_view_index, _views.size())
	_settle(animate)
	if changed:
		view_changed.emit(_view_index)


## Lays the three views out in a row and parks the track on the current one.
## Re-run on resize, so the fixed 3:4 frame is established before any input.
func _layout_views() -> void:
	_track.size = Vector2(size.x * VIEW_COUNT, size.y)
	for index: int in _views.size():
		var view: Control = _views[index]
		view.position = Vector2(index * size.x, 0.0)
		view.size = size
		# The pager owns every contact in here, so nothing underneath may
		# swallow one.
		view.mouse_filter = MOUSE_FILTER_IGNORE
	_track.position.x = -_view_index * size.x
	_arrows.size = size


func _input(event: InputEvent) -> void:
	# One point of contact only: finger zero, or the left mouse button. A
	# swipe is that same one contact held and moved, so nothing here needs a
	# second index or a gesture event.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return
		if touch.pressed:
			_press(touch.position)
		else:
			_release(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != 0:
			return
		_drag_to(drag.position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_press(click.position)
		else:
			_release(click.position)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# Movement with nothing held is just the cursor passing over. This is
		# the gate that makes a missed release harmless: the contact flag may
		# go stale, but nothing moves without the button.
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		_drag_to(motion.position)


## Takes the contact, if it started inside the pager and nothing in the view
## wants it for itself. A press on the UI band above — the pause button lives
## there — is left alone for the same reason: real `Button` nodes handle their
## own contact, and a control that swallows one cannot also be swiped from.
## That is the standard trade, and it is why the buy button is the only thing
## in a view allowed to claim one.
func _press(point: Vector2) -> void:
	if not get_global_rect().has_point(point):
		return
	if _view_swallows(point):
		return
	if _settle_tween != null and _settle_tween.is_valid():
		_settle_tween.kill()
	_contact_down = true
	_swiping = false
	_press_point = point
	_press_offset = _track.position.x


func _drag_to(point: Vector2) -> void:
	if not _contact_down:
		return
	var travel: Vector2 = point - _press_point
	if not _swiping:
		# Sideways and far enough. Comparing against the vertical travel keeps
		# a shaky tap from scrolling the views out from under itself.
		if absf(travel.x) < SWIPE_THRESHOLD or absf(travel.x) <= absf(travel.y):
			return
		_swiping = true

	var span: float = size.x * float(_views.size() - 1)
	_track.position.x = clampf(_press_offset + travel.x, -span, 0.0)
	_accept()


func _release(point: Vector2) -> void:
	if not _contact_down:
		return
	_contact_down = false

	if _swiping:
		_swiping = false
		_settle_to_nearest(point.x - _press_point.x)
		_accept()
		return

	if _press_point.distance_to(point) <= TAP_SLOP:
		_deliver_tap(point)
		_accept()


## The chevron on a side is a tap target as well as a hint, so the swipe is an
## option rather than the only way through. Returns true if the tap was one.
func _tapped_an_arrow(point: Vector2) -> bool:
	var local: Vector2 = point - global_position
	for direction: int in [-1, 1]:
		if _arrows.has_view(direction) and _arrows.zone(direction).has_point(local):
			go_to(_view_index + direction)
			return true
	return false


## Commits to the next view along if the drag went far enough, and springs back
## to the one it started on if it did not.
func _settle_to_nearest(travel_x: float) -> void:
	var target: int = _view_index
	if absf(travel_x) > size.x * COMMIT_FRACTION:
		# Dragging left pulls the next view in from the right.
		target = _view_index + (1 if travel_x < 0.0 else -1)
	go_to(target)


## True if the view showing has a control of its own under this point, which
## it will receive through the normal GUI path instead.
func _view_swallows(point: Vector2) -> bool:
	var view: Control = current_view()
	if view == null or not view.has_method("swallows_contact"):
		return false
	return bool(view.call("swallows_contact", point - view.global_position))


## Hands a tap to the view showing, in that view's own coordinates. Views opt
## in by defining `handle_tap`; the stats view has nothing to tap and does not.
func _deliver_tap(point: Vector2) -> void:
	if _tapped_an_arrow(point):
		return
	var view: Control = current_view()
	if view == null or not view.has_method("handle_tap"):
		return
	view.call("handle_tap", point - view.global_position)


## Slides the track onto the current view. One finite tween, always completes.
func _settle(animate: bool) -> void:
	if _settle_tween != null and _settle_tween.is_valid():
		_settle_tween.kill()
	var destination: float = -_view_index * size.x
	if not animate:
		_track.position.x = destination
		return
	_settle_tween = create_tween()
	_settle_tween.set_trans(Tween.TRANS_CUBIC)
	_settle_tween.set_ease(Tween.EASE_OUT)
	_settle_tween.tween_property(_track, "position:x", destination, SETTLE_DURATION)


## Marks the event handled so it never reaches a control underneath as well.
func _accept() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()
