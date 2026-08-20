extends Control
## Main menu: the project's entry point, and the only teaching the game does.
##
## It is one blank calendar on the same cubicle wall the game uses, with Start
## printed on the sheet. Pressing a calendar is the entire game, so the menu is
## the gesture rather than a description of it.
##
## Start continues the saved run rather than restarting it — the game has no
## end state, so there is nothing to restart from.

const GAME_SCENE: String = "res://scenes/game.tscn"

@onready var _start_button: Button = %StartButton
@onready var _quit_button: Button = %QuitButton
@onready var _best_label: Label = %BestLabel


func _ready() -> void:
	_start_button.pressed.connect(_on_start_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_best_label.text = _progress_text()
	# On the Web the player closes the tab; a Quit button there does nothing.
	_quit_button.visible = not OS.has_feature("web")


## What the saved run has reached, or an invitation if there is not one yet.
func _progress_text() -> String:
	if GameState.total_rips <= 0:
		return "a new calendar, starting %d" % CalendarData.START_YEAR
	return (
		"%s points  ·  ripped to %d  ·  best %s"
		% [
			DayCounter.with_separators(GameState.points),
			GameState.current_year(),
			DayCounter.with_separators(GameState.best_points),
		]
	)


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
