extends Control
## The gameplay screen: the UI band, the three swipeable views, and the pause
## overlay. It owns none of the game logic — it wires the views to GameState
## and keeps the band in step with them.

@onready var _pager: ViewPager = %ViewPager
@onready var _header: HeaderBar = %HeaderBar
@onready var _calendar_view: CalendarView = %CalendarView
@onready var _stats_view: StatsView = %StatsView
@onready var _store_view: StoreView = %StoreView
@onready var _pause_button: Button = %PauseButton
@onready var _pause_overlay: Control = %PauseOverlay


func _ready() -> void:
	_pause_button.pressed.connect(_on_pause_button_pressed)
	_pager.view_changed.connect(_on_view_pager_view_changed)
	_calendar_view.page_ripped.connect(_on_calendar_view_page_ripped)
	_store_view.purchased.connect(_on_store_view_purchased)
	_refresh()
	_header.set_view(_pager.view_index())


## Called by the pause overlay's Resume button.
func resume() -> void:
	get_tree().paused = false
	_pause_overlay.hide()


## Brings every readout back in line with GameState. The two side views are
## repainted even while off-screen — they are one swipe away, and repainting a
## drawn view costs nothing until it is actually visible.
func _refresh() -> void:
	_header.refresh()
	_stats_view.refresh()
	_store_view.refresh()


func _on_calendar_view_page_ripped(_holidays: PackedStringArray) -> void:
	_refresh()


## A purchase swaps the calendar on the wall, so the view is rebuilt from
## scratch rather than re-pointed, and the player is taken back to the wall to
## see what they bought.
func _on_store_view_purchased(_tier_index: int) -> void:
	_calendar_view.rebuild()
	_refresh()
	_pager.go_to(ViewPager.CALENDAR_VIEW)


func _on_view_pager_view_changed(view_index: int) -> void:
	_header.set_view(view_index)
	_refresh()


func _on_pause_button_pressed() -> void:
	get_tree().paused = true
	_pause_overlay.show()
