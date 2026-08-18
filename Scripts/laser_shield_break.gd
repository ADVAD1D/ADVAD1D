extends GPUParticles2D
@onready var sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	if GameManager.mobile_mode_active:
		lifetime = 0.4
	emitting = true
	get_tree().current_scene.add_child(sound)
	sound.play()

func _on_finished() -> void:
	queue_free()
