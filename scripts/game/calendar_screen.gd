extends Control
## The gameplay screen: UI band, month drawing, and the calendar the player
## crosses off.
##
## Exactly two pages exist at any moment — the one being tapped and the one
## beneath it, already showing next month so the fold reveals something real.
## See the spawn guardrail in CLAUDE.md.

const PAGE_SCENE: PackedScene = preload("res://scenes/month_page.tscn")

## Hard cap on simultaneously instantiated pages: the top one and the one
## underneath it. The calendar runs forever; the node count does not grow.
const MAX_LIVE_PAGES: int = 2

## Index 0 is the page being tapped; index 1 is the one underneath it.
var _pages: Array[MonthPage] = []

@onready var _page_host: Control = %PageHost
@onready var _month_image: MonthImage = %MonthImage
@onready var _counter: Control = %CounterDisplay
@onready var _month_label: Label = %MonthLabel
@onready var _best_label: Label = %BestLabel
@onready var _pause_button: Button = %PauseButton
@onready var _pause_overlay: Control = %PauseOverlay


func _ready() -> void:
	_pause_button.pressed.connect(_on_pause_button_pressed)
	_month_image.show_month(GameState.month_index)
	_build_pages()
	_refresh_labels()


## Creates the top page and the one beneath it, in that order.
func _build_pages() -> void:
	_add_page(GameState.month_index, GameState.marked_days)
	_add_page(CalendarData.normalize_month(GameState.month_index + 1), {})
	_restack()


func _add_page(month_index: int, marked_days: Dictionary) -> void:
	if _pages.size() >= MAX_LIVE_PAGES:
		return
	var page: MonthPage = PAGE_SCENE.instantiate()
	_page_host.add_child(page)
	page.configure(month_index, marked_days)
	page.day_tapped.connect(_on_page_day_tapped.bind(page))
	_pages.append(page)


## Puts the top page in front and makes only it tappable.
func _restack() -> void:
	for index: int in _pages.size():
		var page: MonthPage = _pages[index]
		if not is_instance_valid(page):
			continue
		var is_top: bool = index == 0
		# Later children draw on top, so the top page must be last.
		_page_host.move_child(page, _pages.size() - 1 - index)
		page.mouse_filter = MOUSE_FILTER_STOP if is_top else MOUSE_FILTER_IGNORE


func _on_page_day_tapped(day_number: int, page: MonthPage) -> void:
	# Only the top page is tappable, but a tap that lands during a fold must
	# not reach through to the page underneath.
	if _pages.is_empty() or page != _pages[0] or page.is_folding():
		return

	var completed: bool = GameState.mark_day(day_number)
	page.mark_day(day_number)
	_refresh_labels()

	if completed:
		_fold_top_page()


## Folds the finished page away and brings up the one underneath.
func _fold_top_page() -> void:
	var finished: MonthPage = _pages.pop_front()
	finished.fold_down()

	# GameState has already advanced, and the page underneath was built for
	# exactly this month, so it becomes the new top as-is.
	_month_image.show_month(GameState.month_index)
	_add_page(CalendarData.normalize_month(GameState.month_index + 1), {})
	_restack()


func _refresh_labels() -> void:
	_counter.call("set_total_days", GameState.total_days)
	_month_label.text = GameState.current_month_name().to_upper()
	_best_label.text = "BEST %d" % GameState.best_days


func _on_pause_button_pressed() -> void:
	get_tree().paused = true
	_pause_overlay.show()


## Called by the pause overlay's Resume button.
func resume() -> void:
	get_tree().paused = false
	_pause_overlay.hide()
