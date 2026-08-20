class_name CalendarView
extends Control
## The wall: white cubicle panel, one thumbtack, and the calendar hanging off
## it. This is the main view, and the only one you can rip on.
##
## Exactly two pages exist at any moment — the one being ripped and the one
## underneath it, already showing what the rip will reveal. Pages on their way
## down are counted separately and capped too, so holding the tap button in
## cannot pile up sheets. See the spawn guardrail in CLAUDE.md.
##
## The wall is deliberately bare. Dressing it up is a progression reward that
## has not been designed yet — see DESIGN.md.

signal page_ripped(holidays: PackedStringArray)

const PAGE_SCENE: PackedScene = preload("res://scenes/calendar_page.tscn")

## Hard cap on pinned pages: the top one and the one underneath it.
const MAX_LIVE_PAGES: int = 2
## Hard cap on pages still falling. A fast tapper can start a rip every frame;
## past this the oldest sheet is freed immediately rather than accumulating.
const MAX_FALLING_PAGES: int = 3

const WALL: Color = Color(0.929, 0.925, 0.914)
const WALL_GRAIN: Color = Color(0.882, 0.878, 0.867)
const WALL_SEAM: Color = Color(0.839, 0.835, 0.824)
const INK: Color = Color(0.106, 0.106, 0.106)
const PAPER: Color = Color(0.965, 0.961, 0.949)
const SHADOW: Color = Color(0, 0, 0, 0.18)
const MUTED: Color = Color(0.545, 0.541, 0.529)

## Faint vertical fabric lines, so the cubicle panel is plain without being
## blank. A named bound, not one derived from the width.
const WALL_GRAIN_LINES: int = 30
## Height of the panel seam near the bottom of the wall.
const WALL_SEAM_Y: float = 806.0

## The strip the tack goes through, which stays put when a page comes away.
const BACKING_RECT: Rect2 = Rect2(140.0, 70.0, 440.0, 40.0)
## Where a fresh page hangs — just low enough that it never covers the tack.
const PAGE_ORIGIN: Vector2 = Vector2(140.0, 104.0)
const TACK_CENTRE: Vector2 = Vector2(360.0, 90.0)
const TACK_RADIUS: float = 11.0
const SHADOW_OFFSET: Vector2 = Vector2(5.0, 5.0)

## How far a ripped page falls before it is gone.
const FALL_DISTANCE: float = 900.0
## Seconds the "+1 HALLOWEEN" note stays up after a scoring rip, and where on
## the bare wall below the calendar it rises from.
const FLASH_DURATION: float = 1.1
const FLASH_RISE: float = 46.0
const FLASH_BASELINE: float = 790.0

## Index 0 is the page being ripped; index 1 is the one underneath it.
var _pages: Array[CalendarPage] = []
## Pages already torn off, oldest first.
var _falling: Array[CalendarPage] = []
var _flash_text: String = ""
var _flash_progress: float = 1.0
var _flash_tween: Tween


func _ready() -> void:
	rebuild()


## Tears down every page and hangs a fresh calendar. Called on load and again
## whenever a purchase swaps the calendar for a different one.
func rebuild() -> void:
	for page: CalendarPage in _pages:
		if is_instance_valid(page):
			page.queue_free()
	_pages.clear()
	_flash_text = ""

	_add_page(GameState.elapsed_days)
	_add_page(GameState.elapsed_days + GameState.current_span_days())
	_restack()
	queue_redraw()


## Routes one tap from the pager. Only a tap that lands on the hanging page
## rips it; the bare wall around it does nothing.
func handle_tap(local_point: Vector2) -> void:
	if _pages.is_empty():
		return
	var top: CalendarPage = _pages[0]
	if not is_instance_valid(top) or top.is_ripping():
		return
	if not Rect2(top.position, CalendarPage.PAGE_SIZE).has_point(local_point):
		return
	rip()


## Rips the top page off, banks whatever it was worth, and brings up the one
## underneath.
func rip() -> void:
	if _pages.is_empty() or not is_instance_valid(_pages[0]) or _pages[0].is_ripping():
		return

	var collected: PackedStringArray = GameState.rip_page()
	var finished: CalendarPage = _pages.pop_front()
	finished.rip_off(FALL_DISTANCE)
	_track_falling(finished)

	# GameState has already advanced, and the page underneath was built for
	# exactly this position, so it becomes the new top as-is.
	_add_page(GameState.elapsed_days + GameState.current_span_days())
	_restack()

	if not collected.is_empty():
		_start_flash(collected)
	page_ripped.emit(collected)


## How many pages are still pinned to the wall. Used by the tests that guard
## the cap.
func live_page_count() -> int:
	var count: int = 0
	for page: CalendarPage in _pages:
		if is_instance_valid(page):
			count += 1
	return count


func _add_page(elapsed_days: int) -> void:
	if _pages.size() >= MAX_LIVE_PAGES:
		return
	var page: CalendarPage = PAGE_SCENE.instantiate()
	add_child(page)
	page.position = PAGE_ORIGIN
	page.configure(GameState.tier_index, elapsed_days)
	_pages.append(page)


## Keeps the falling pages bounded. The tween frees each one on its own, but a
## tapper faster than the fall would otherwise stack them up.
func _track_falling(page: CalendarPage) -> void:
	# Drop references to sheets that have already finished falling, then cap
	# what is left. The tween frees each sheet on its own; this is only here
	# so a tapper faster than the fall cannot outrun it.
	var still_falling: Array[CalendarPage] = []
	for sheet: CalendarPage in _falling:
		if is_instance_valid(sheet):
			still_falling.append(sheet)
	still_falling.append(page)
	while still_falling.size() > MAX_FALLING_PAGES:
		var oldest: CalendarPage = still_falling.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_falling = still_falling


## Puts the top page in front of the one underneath it, and every sheet still
## falling in front of both — a page peels off towards the viewer, so it has to
## pass over the calendar it came from rather than behind it.
func _restack() -> void:
	for index: int in _pages.size():
		var page: CalendarPage = _pages[index]
		if is_instance_valid(page):
			# Later children draw on top, so the top page must be last.
			move_child(page, get_child_count() - 1 - index)
	for sheet: CalendarPage in _falling:
		if is_instance_valid(sheet):
			move_child(sheet, get_child_count() - 1)


func _start_flash(names: PackedStringArray) -> void:
	_flash_text = "+%d  %s" % [names.size(), ", ".join(names).to_upper()]
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	# A finite tween, redrawing only while the note is up.
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_progress, 0.0, 1.0, FLASH_DURATION)


func _set_flash_progress(progress: float) -> void:
	_flash_progress = progress
	queue_redraw()


func _draw() -> void:
	_draw_wall()
	_draw_backing()
	# Behind the pages, which are children and so draw after this. Only the
	# offset edges show, which is what gives the calendar its bit of depth.
	draw_rect(Rect2(PAGE_ORIGIN + SHADOW_OFFSET, CalendarPage.PAGE_SIZE), SHADOW, true)
	_draw_flash()


func _draw_wall() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), WALL, true)
	for line: int in WALL_GRAIN_LINES:
		var x: float = size.x * (float(line) + 0.5) / float(WALL_GRAIN_LINES)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), WALL_GRAIN, 1.0)
	draw_line(Vector2(0.0, WALL_SEAM_Y), Vector2(size.x, WALL_SEAM_Y), WALL_SEAM, 2.0)


## The stub the tack holds, and the tack itself. Children draw after their
## parent, so the sheets hang over the bottom of the stub — which is exactly
## how a wall calendar reads. The tack sits above where any sheet starts, so
## nothing ever covers it.
func _draw_backing() -> void:
	draw_rect(Rect2(BACKING_RECT.position + SHADOW_OFFSET, BACKING_RECT.size), SHADOW, true)
	draw_rect(BACKING_RECT, PAPER, true)
	draw_rect(BACKING_RECT, INK, false, 2.0)
	draw_circle(TACK_CENTRE + Vector2(2.0, 2.0), TACK_RADIUS, SHADOW, true)
	draw_circle(TACK_CENTRE, TACK_RADIUS, INK, true)
	draw_circle(TACK_CENTRE - Vector2(3.0, 3.0), TACK_RADIUS * 0.34, PAPER, true)


## The note that goes up when a rip collected something. Drawn on the wall
## rather than spawned as a label, so scoring costs no nodes at all.
func _draw_flash() -> void:
	if _flash_text == "" or _flash_progress >= 1.0:
		return
	var font: Font = ThemeDB.fallback_font
	var alpha: float = 1.0 - pow(_flash_progress, 3.0)
	var baseline: float = FLASH_BASELINE - FLASH_RISE * _flash_progress
	var width: float = font.get_string_size(_flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x
	draw_string(
		font,
		Vector2((size.x - width) * 0.5, baseline),
		_flash_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		20,
		Color(INK, alpha)
	)
