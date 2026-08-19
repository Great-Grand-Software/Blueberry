extends Control
## Main menu: the project's entry point. Start and Quit.
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
	_best_label.text = "BEST  %s" % DayCounter.format_all(GameState.best_days)
	# On the Web the player closes the tab; a Quit button there does nothing.
	_quit_button.visible = not OS.has_feature("web")


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
