extends Label

@onready var score_sound: AudioStreamPlayer2D = $ScoreSound

func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)
	# The pause menu's EN/ES switch: rewrite it in the new language right away
	GameManager.language_changed.connect(_update_text.unbind(1))
	_on_score_updated(GameManager.score)

func _update_text() -> void:
	text = tr("SCORE: ") + str(GameManager.score)

func _on_score_updated(new_score: int) -> void:
	_update_text()
	if new_score > 0:
		score_sound.play()
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(self, "scale", Vector2.ONE, 0.1)
