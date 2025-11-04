extends Area2D

@export_file("*.tscn") var next_scene_path := "res://Scenes/Levels/Level_02.tscn"

func _ready() -> void:
	# make sure the signal is connected even if not wired in the editor
	body_entered.connect(_on_body_entered)
	# debug: show setup
	print("[Door] monitoring:", monitoring, "  mask:", collision_mask, "  path:", next_scene_path)

func _on_body_entered(body: Node) -> void:
	print("[Door] body_entered by:", body.name, " groups:", body.get_groups())
	if not body.is_in_group("player"):
		print("[Door] ignored — not in 'player' group")
		return

	if ResourceLoader.exists(next_scene_path):
		var ps := load(next_scene_path) as PackedScene
		if Engine.has_singleton("SceneTransition"):
			SceneTransition.load_scene(ps)
		else:
			get_tree().change_scene_to_packed(ps)
	else:
		push_error("[Door] Scene NOT found: %s" % next_scene_path)
