class_name CalendarView
extends Control
## The wall: white cubicle panel, one thumbtack, and the calendar hanging off
## it. This is the main view, and the only one you can rip on.
##
## Each tier is a different-sized object, so the backing strip, the tack and
## the hanging page are all placed from `CalendarPage.page_size()` rather than
## from fixed coordinates. The whole assembly is centred in the wall above the
## flash band, so the small daily block sits at eye level rather than stranded
## at the top of a mostly empty wall, and the tall monthly sheet still fits.
##
## Exactly two pages exist at any moment — the one being ripped and the one
## underneath it, already showing what the rip will reveal. Pages on their way
## down are counted separately and capped too, so holding the tap in cannot
## pile up sheets. See the spawn guardrail in CLAUDE.md.
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

## Faint vertical fabric lines, so the cubicle panel is plain without being
## blank. A named bound, not one derived from the width.
const WALL_GRAIN_LINES: int = 30
## Height of the panel seam near the bottom of the wall.
const WALL_SEAM_Y: float = 806.0

## The wall above the flash band. Backing strip and page are centred in here
## together, so the calendar is balanced whatever shape it is.
const HANGING_REGION: float = 792.0
## Never let the backing ride right up against the UI band.
const MIN_BACKING_TOP: float = 8.0
## The strip the tack goes through, which stays put when a page comes away. It
## is as wide as whatever is hanging off it.
const BACKING_HEIGHT: float = 40.0
## How far the page hangs up behind the backing strip.
const BACKING_OVERLAP: float = 6.0
const TACK_RADIUS: float = 11.0
const SHADOW_OFFSET: Vector2 = Vector2(5.0, 5.0)

## How far a ripped page falls before it is gone.
const FALL_DISTANCE: float = 900.0
## The "+1 HALLOWEEN" note after a scoring rip. It is drawn as a badge on its
## own paper, because a yearly page reaches far enough down the wall that a
## bare line of text would land on top of it.
const FLASH_DURATION: float = 1.1
const FLASH_RISE: float = 44.0
const FLASH_BASELINE: float = 838.0
const FLASH_PADDING: Vector2 = Vector2(18.0, 12.0)

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


## Where the hanging page sits, for the tier currently on the wall.
func page_rect() -> Rect2:
	var face: Vector2 = CalendarPage.page_size(GameState.tier_index)
	var hang: float = BACKING_HEIGHT - BACKING_OVERLAP
	var top: float = maxf((HANGING_REGION - hang - face.y) * 0.5, MIN_BACKING_TOP) + hang
	return Rect2(Vector2((size.x - face.x) * 0.5, top), face)


## The strip the tack goes through, directly above the page and as wide as it.
func backing_rect() -> Rect2:
	var page: Rect2 = page_rect()
	var hang: float = BACKING_HEIGHT - BACKING_OVERLAP
	return Rect2(page.position.x, page.position.y - hang, page.size.x, BACKING_HEIGHT)


## Routes one tap from the pager. Only a tap that lands on the hanging page
## rips it; the bare wall around it does nothing.
func handle_tap(local_point: Vector2) -> void:
	if _pages.is_empty():
		return
	var top: CalendarPage = _pages[0]
	if not is_instance_valid(top) or top.is_ripping():
		return
	if not Rect2(top.position, CalendarPage.page_size(top.tier_index())).has_point(local_point):
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
	page.configure(GameState.tier_index, elapsed_days)
	page.position = page_rect().position
	_pages.append(page)


## Keeps the falling pages bounded. The tween frees each one on its own, but a
## tapper faster than the fall would otherwise stack them up.
func _track_falling(page: CalendarPage) -> void:
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
	_flash_text = "+%d   %s" % [names.size(), ", ".join(names).to_upper()]
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	# A finite tween, redrawing only while the note is up.
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_progress, 0.0, 1.0, FLASH_DURATION)


func _set_flash_progress(progress: float) -> void:
	_flash_progress = progress
	queue_redraw()


func _draw() -> void:
	var page: Rect2 = page_rect()
	_draw_wall()
	_draw_backing()
	# Behind the pages, which are children and so draw after this. Only the
	# offset edges show, which is what gives the calendar its bit of depth.
	draw_rect(Rect2(page.position + SHADOW_OFFSET, page.size), Palette.SHADOW, true)
	_draw_flash()


func _draw_wall() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.WALL, true)
	for line: int in WALL_GRAIN_LINES:
		var x: float = size.x * (float(line) + 0.5) / float(WALL_GRAIN_LINES)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Palette.WALL_GRAIN, 1.0)
	draw_line(Vector2(0.0, WALL_SEAM_Y), Vector2(size.x, WALL_SEAM_Y), Palette.WALL_SEAM, 2.0)


## The stub the tack holds, and the tack itself. Children draw after their
## parent, so the sheet hangs over the bottom of the stub — which is exactly
## how a wall calendar reads. The tack sits above where any sheet starts, so
## nothing ever covers it.
func _draw_backing() -> void:
	var backing: Rect2 = backing_rect()
	var tack := Vector2(size.x * 0.5, backing.position.y + 18.0)
	draw_rect(Rect2(backing.position + SHADOW_OFFSET, backing.size), Palette.SHADOW, true)
	draw_rect(backing, Palette.PAPER, true)
	draw_rect(backing, Palette.INK, false, 2.0)
	draw_circle(tack + Vector2(2.0, 2.0), TACK_RADIUS, Palette.SHADOW)
	draw_circle(tack, TACK_RADIUS, Palette.INK)
	draw_circle(tack - Vector2(3.0, 3.0), TACK_RADIUS * 0.34, Palette.PAPER)


## The note that goes up when a rip collected something. Drawn on the wall
## rather than spawned as a label, so scoring costs no nodes at all.
func _draw_flash() -> void:
	if _flash_text == "" or _flash_progress >= 1.0:
		return
	var font: Font = ThemeDB.fallback_font
	var alpha: float = 1.0 - pow(_flash_progress, 3.0)
	var baseline: float = FLASH_BASELINE - FLASH_RISE * _flash_progress
	var width: float = font.get_string_size(_flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x
	var badge := Rect2(
		Vector2((size.x - width) * 0.5 - FLASH_PADDING.x, baseline - 22.0 - FLASH_PADDING.y),
		Vector2(width + FLASH_PADDING.x * 2.0, 28.0 + FLASH_PADDING.y * 2.0)
	)
	draw_rect(badge, Color(Palette.PAPER, alpha), true)
	draw_rect(badge, Color(Palette.INK, alpha), false, 2.0)
	draw_string(
		font,
		Vector2((size.x - width) * 0.5, baseline),
		_flash_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		20,
		Color(Palette.INK, alpha)
	)
