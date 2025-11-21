extends AudioStreamPlayer

signal volume_changed(volume_percent)

const min_linear_volume = 0.0001

var linear_volume: float = 1.0

var is_fading: bool = false

var no_music_scenes = [
	"res://Scenes/tutorial.tscn",
	"res://Scenes/spash_screen.tscn"
]

var scene1_specific_playlist: Dictionary = {
	"res://Scenes/abduction.tscn": preload("res://Assets/Audio/Music/circuit-pathway-387799.wav"),
	"res://Scenes/ending.tscn": preload("res://Assets/Audio/Music/star-runner-411375.wav"),
	"res://Scenes/main_menu.tscn": preload("res://Assets/Audio/Music/in-time-all-hope-was-lost-411362.wav"),
	"res://Scenes/skin_selector.tscn": preload("res://Assets/Audio/where-we-used-to-be-415885.wav")
	
}

@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var playlist = [
	preload("res://Assets/Audio/Music/neon-rising-336846.wav"),
	preload("res://Assets/Audio/Music/videoplayback.wav"),
	preload("res://Assets/Audio/Music/techno-driver-188955.wav"),
	preload("res://Assets/Audio/Music/neon-drive-retrowaver-synthwave-vaporwave-retro-80s-193108.wav"),
	preload("res://Assets/Audio/Music/cybertech-flight-404708-_1_.wav"),
	preload("res://Assets/Audio/Music/end-of-the-line-317985.wav"),
	preload("res://Assets/Audio/Music/pulsehaven-nexus-382253.wav"),
	preload("res://Assets/Audio/Music/melody-machine-283000.wav"),
	preload("res://Assets/Audio/Music/blue-light-district-397940.wav"),
	preload("res://Assets/Audio/Music/the-fight-left-in-us-391531.wav"),
	preload("res://Assets/Audio/Music/chipwave-horizon-377407.wav"),
	preload("res://Assets/Audio/Music/starstream-circuit-370586.wav"),
	preload("res://Assets/Audio/Music/darkwave-dawn-371013.wav"),
	preload("res://Assets/Audio/Music/ascending-data-418712.wav"),
	preload("res://Assets/Audio/Music/starstream-interceptor-438040.wav")
]

#licences
#Music by <a href="https://pixabay.com/es/users/psychronic-13092015/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=336846">Douglas Gustafson</a> from <a href="https://pixabay.com/music//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=336846">Pixabay</a>
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
	get_tree().scene_changed.connect(_on_scene_changed) # Replace with function body.
	
	volume_db = linear_to_db(linear_volume)
	
	_emit_volume_changed()
	_on_scene_changed()
	
	
func _on_scene_changed():
	var current_scene_path = get_tree().current_scene.scene_file_path
	print("Escena actual: ", get_tree().current_scene.scene_file_path)
	
	if scene1_specific_playlist.has(current_scene_path):
		var specific_song = scene1_specific_playlist[current_scene_path]
		
		if stream != specific_song:
			stream = specific_song
			volume_db = linear_to_db(linear_volume)
			play()
			print("reproduciendo tema específico: ", stream.resource_path.get_file())
			
	elif current_scene_path in no_music_scenes:
		stop()
		return
			
	elif not playing:
		play_next_shuffled_song()

func play_next_shuffled_song():
	var current_scene_path = get_tree().current_scene.scene_file_path
	
	if scene1_specific_playlist.has(current_scene_path):
		play()
		return
		
	if shuffled_playlist.is_empty():
		print("Playlist terminada. ¡Barajando de nuevo!")
		shuffled_playlist = playlist.duplicate()
		shuffled_playlist.shuffle()
	
	stream = shuffled_playlist.pop_front()
	volume_db = linear_to_db(linear_volume)
	play()
	_emit_volume_changed()
	print("Ahora suena: ", stream.resource_path.get_file())
	
func play_sfx(sound_resource: AudioStream):
	if is_instance_valid(sfx_player) and sound_resource:
		sfx_player.stream = sound_resource
		sfx_player.play()

func fade_out_and_stop(duration: float):
	if not playing or is_fading:
		return
		
	is_fading = true
	print("iniciando fade out de la música...")
	
	var tween = create_tween()
	tween.tween_property(self, "volume_db", -80.0, duration)
	
	await tween.finished
	
	stop()
	volume_db = 0.0 
	is_fading = false
	print("Música detenida.")
	
func increase_volume():
	linear_volume = clamp(linear_volume + 0.05, min_linear_volume, 1.0)
	volume_db = linear_to_db(linear_volume)
	_emit_volume_changed()

func decrease_volume():
	linear_volume = clamp(linear_volume - 0.05, min_linear_volume, 1.0)
	volume_db = linear_to_db(linear_volume)
	_emit_volume_changed()

func get_volume_percent() -> float:
	return linear_volume * 100.0

func _emit_volume_changed():
	volume_changed.emit(get_volume_percent())
