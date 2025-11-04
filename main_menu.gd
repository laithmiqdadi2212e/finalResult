extends Control

@onready var start_button: Button = $StartButton
@onready var music: AudioStreamPlayer = $audio

const LEVEL_PATH := "res://Scenes/Levels/Level_01.tscn"

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	music.stop()
	if ResourceLoader.exists(LEVEL_PATH):
		var ps := load(LEVEL_PATH) as PackedScene
		get_tree().change_scene_to_packed(ps)
	else:
		push_error("Level scene NOT found at: %s" % LEVEL_PATH)
