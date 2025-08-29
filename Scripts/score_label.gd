extends Label

@onready var score_sound: AudioStreamPlayer2D = $ScoreSound

func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)
	_on_score_updated(GameManager.score)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_score_updated(new_score: int) -> void:
	text = "SCORE: " + str(GameManager.score)
	if new_score > 0:
		score_sound.play()
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(self, "scale", Vector2.ONE, 0.1)
