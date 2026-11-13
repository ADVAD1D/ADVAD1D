extends CPUParticles2D

func _ready() -> void:
	# Enemy laser sparks: the arena's enemy colour (the player's laser, the enemy laser and
	# the arenas all spawn this scene, so it dresses itself)
	ArenaEnemySkin.apply(self)
	if GameManager.mobile_mode_active or OS.has_feature("web") or GameManager.force_web_mode:
		lifetime = 0.3
		amount = 7
	fixed_fps = 0
	fract_delta = true
	emitting = true

func _on_finished() -> void:
	queue_free()
