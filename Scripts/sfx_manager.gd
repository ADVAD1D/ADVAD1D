extends Node
signal sfx_volume_changed(sfx_percent)

const min_volume_db = -50.0
const max_volume_db = 0.0

var sfx_bus_index: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sfx_bus_index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_bus_index, max_volume_db)
	
func increase_sfx_volume():
	var current_vol = AudioServer.get_bus_volume_db(sfx_bus_index)
	var new_vol = clamp(current_vol + 2.0, min_volume_db, max_volume_db)
	AudioServer.set_bus_volume_db(sfx_bus_index, new_vol)
	_emit_sfx_volume_changed()

func decrease_sfx_volume():
	var current_vol = AudioServer.get_bus_volume_db(sfx_bus_index)
	var new_vol = clamp(current_vol - 2.0, min_volume_db, max_volume_db)
	AudioServer.set_bus_volume_db(sfx_bus_index, new_vol)
	_emit_sfx_volume_changed()

func get_sfx_volume_percent() -> float:
	var current_vol = AudioServer.get_bus_volume_db(sfx_bus_index)
	return ((current_vol - min_volume_db) / (max_volume_db - min_volume_db)) * 100.0

func _emit_sfx_volume_changed():
	sfx_volume_changed.emit(get_sfx_volume_percent())
