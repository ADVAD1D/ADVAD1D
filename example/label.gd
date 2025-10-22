extends Label

@export var env_key: String

func _ready() -> void:
	text = EnvParser.parse(env_key)
