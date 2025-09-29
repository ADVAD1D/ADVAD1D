extends AudioStreamPlayer


var playlist = [
	preload("res://Assets/Audio/Music/Cosmic-Drift.wav"),
	preload("res://Assets/Audio/Music/letx27s-meet-michelle-synthpop-background-music-for-video-vlog-394174.wav"),
	preload("res://Assets/Audio/Music/techno-driver-188955.wav"),
	preload("res://Assets/Audio/Music/neon-drive-retrowaver-synthwave-vaporwave-retro-80s-193108.wav"),
	preload("res://Assets/Audio/Music/synthwave-80s-retro-background-music-400483.wav"),
	preload("res://Assets/Audio/Music/synthwave-retrowave-sythpop-121540.wav")
]

#licences
#Music by <a href="https://pixabay.com/es/users/white_records-32584949/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=394174">Maksym Dudchyk</a> from <a href="https://pixabay.com//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=394174">Pixabay</a>
#Music by <a href="https://pixabay.com/es/users/sergepavkinmusic-6130722/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=335098">Sergii Pavkin</a> from <a href="https://pixabay.com/music//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=335098">Pixabay</a>
#Music by <a href="https://pixabay.com/es/users/lesiakower-25701529/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=109038">Lesiakower</a> from <a href="https://pixabay.com//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=109038">Pixabay</a>
#Music by <a href="https://pixabay.com/es/users/amaksi-28332361/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=121540">Aleksey Voronin</a> from <a href="https://pixabay.com/music//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=121540">Pixabay</a>
#Music by <a href="https://pixabay.com/es/users/lnplusmusic-47631836/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=400483">Andrii Poradovskyi</a> from <a href="https://pixabay.com/music//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=400483">Pixabay</a>
#Music by <a href="https://pixabay.com/es/users/artur_aravidi_music-37133175/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=193108">Artur Aravidi</a> from <a href="https://pixabay.com//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=193108">Pixabay</a>

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
