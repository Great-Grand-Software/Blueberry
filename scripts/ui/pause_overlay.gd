extends Control
## Pause overlay: freezes gameplay and offers Resume and Main Menu.
##
## Its process mode is PROCESS_MODE_ALWAYS in the scene so its buttons keep
## working while the tree is paused.

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"

@onready var _resume_button: Button = %ResumeButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	_resume_button.pressed.connect(_on_resume_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	hide()


func _on_resume_pressed() -> void:
	var screen: Node = get_parent()
	if screen != null and screen.has_method("resume"):
		screen.call("resume")
	else:
		get_tree().paused = false
		hide()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
