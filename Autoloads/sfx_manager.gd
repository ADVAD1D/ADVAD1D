extends Node
signal sfx_volume_changed(sfx_percent)

const min_linear_volume = 0.0001
const max_linear_volume = 0.3

var linear_sfx_volume: float = max_linear_volume

var sfx_bus_index: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sfx_bus_index = AudioServer.get_bus_index("SFX")
	# Saved volume (GameManager loads before this autoload)
	linear_sfx_volume = clamp(GameManager.sfx_volume_percent / 100.0 * max_linear_volume,
			min_linear_volume, max_linear_volume)
	await get_tree().process_frame
	AudioServer.set_bus_volume_db(sfx_bus_index, linear_to_db(linear_sfx_volume))

func increase_sfx_volume():
	linear_sfx_volume = clamp(linear_sfx_volume + (max_linear_volume * 0.05), min_linear_volume, max_linear_volume)
	AudioServer.set_bus_volume_db(sfx_bus_index, linear_to_db(linear_sfx_volume))
	_emit_sfx_volume_changed()
	_save_volume()

func decrease_sfx_volume():
	linear_sfx_volume = clamp(linear_sfx_volume - (max_linear_volume * 0.05), min_linear_volume, max_linear_volume)
	AudioServer.set_bus_volume_db(sfx_bus_index, linear_to_db(linear_sfx_volume))
	_emit_sfx_volume_changed()
	_save_volume()

func get_sfx_volume_percent() -> float:
	return (linear_sfx_volume / max_linear_volume) * 100.0

func _emit_sfx_volume_changed():
	sfx_volume_changed.emit(get_sfx_volume_percent())

## Every volume change (pause menu or main menu settings) is saved right away.
func _save_volume() -> void:
	GameManager.sfx_volume_percent = get_sfx_volume_percent()
	GameManager.save_data()
