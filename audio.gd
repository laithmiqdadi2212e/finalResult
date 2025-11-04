extends AudioStreamPlayer

func _ready():
	get_tree().get_root().add_child(self)
	self.owner = null
	if not playing:
		play()
