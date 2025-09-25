extends AudioStreamPlayer


var playlist = [
	preload("res://Assets/Audio/Music/Cosmic-Drift.wav"),
	preload("res://Assets/Audio/Music/Space-Dance.wav"),
	preload("res://Assets/Audio/Music/Space-War.wav")
]

var shuffled_playlist = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	finished.connect(play_next_shuffled_song)
	play_next_shuffled_song() # Replace with function body.

func play_next_shuffled_song():
	if shuffled_playlist.is_empty():
		print("Playlist terminada. ¡Barajando de nuevo!")
		shuffled_playlist = playlist.duplicate()
		shuffled_playlist.shuffle()
	
	stream = shuffled_playlist.pop_front()
	play()
	print("Ahora suena: ", stream.resource_path.get_file())
