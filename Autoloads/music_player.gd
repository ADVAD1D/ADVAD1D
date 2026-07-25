extends AudioStreamPlayer

signal volume_changed(volume_percent)

const min_linear_volume = 0.0001
const max_linear_volume = 0.3

var linear_volume: float = max_linear_volume

var is_fading: bool = false

var no_music_scenes = [
	"res://Scenes/tutorial.tscn",
	"res://Scenes/spash_screen.tscn"
]

#LA RUTA A LA MÚSICA NO FUNCIONABA POR UNA MAYÚSCULA ME CAGO EN TODOO CHAVAL MANOLO
var scene1_specific_playlist: Dictionary = {
	"res://Scenes/Abduction.tscn": preload("res://Assets/Audio/Music/circuit-pathway-387799.ogg"),
	"res://Scenes/ending.tscn": preload("res://Assets/Audio/Music/star-runner-411375.ogg"),
	"res://Scenes/main_menu.tscn": preload("res://Assets/Audio/Music/in-time-all-hope-was-lost-411362.ogg"),
	"res://Scenes/skin_selector.tscn": preload("res://Assets/Audio/Music/where-we-used-to-be-415885.ogg"),
	"res://Scenes/ai_console.tscn": preload("res://Assets/Audio/Music/psychronic-hypnotic-crystals-415889.ogg"),
	"res://Scenes/UI/ai_console_subviewport.tscn": preload("res://Assets/Audio/Music/psychronic-hypnotic-crystals-415889.ogg")	
}

@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

#the max size for game resource(music) for itchio browser support is 200mb on index.pck
#ogg format is better for this

var arena_playlists = {
	0: [
		preload("res://Assets/Audio/Music/neon-rising-336846.ogg"),
		preload("res://Assets/Audio/Music/digital-dream-391529.ogg"),
		preload("res://Assets/Audio/Music/velvet-malware-454813.ogg"),
		preload("res://Assets/Audio/Music/psychronic-break-forward-468745.ogg"),
		preload("res://Assets/Audio/Music/pulsehaven-nexus-382253.ogg"),
		preload("res://Assets/Audio/Music/blue-light-district-397940.ogg"),
		preload("res://Assets/Audio/Music/the-fight-left-in-us-391531.ogg"),
		preload("res://Assets/Audio/Music/psychronic-breakpoint-triumph-468746.ogg"),
		preload("res://Assets/Audio/Music/ascending-data-418712.ogg"),
		preload("res://Assets/Audio/Music/digital-disconnect-454806.ogg"),
	],
	1: [
		preload("res://Assets/Audio/Music/neon-rising-336846.ogg"),
		preload("res://Assets/Audio/Music/digital-dream-391529.ogg"),
		preload("res://Assets/Audio/Music/psychronic-the-stars-donx27t-wait-for-you-481769.ogg")
	],
	2: [
		preload("res://Assets/Audio/Music/neon-rising-336846.ogg"),
		preload("res://Assets/Audio/Music/digital-dream-391529.ogg"),
	]
}

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
	#fix lag shutering in change music signal, use call deferred
	finished.connect(_on_music_finished)
	get_tree().scene_changed.connect(_on_scene_changed) # Replace with function body.
	
	volume_db = linear_to_db(linear_volume)
	
	_emit_volume_changed()
	_on_scene_changed()
	
func _on_music_finished():
	call_deferred("play_next_shuffled_song")
	
func _on_scene_changed():
	var current_scene_path = get_tree().current_scene.scene_file_path
	_log_message(["Actual Scene: ", current_scene_path])
	
	if scene1_specific_playlist.has(current_scene_path):
		var specific_song = scene1_specific_playlist[current_scene_path]
		
		if stream != specific_song:
			stream = specific_song
			volume_db = linear_to_db(linear_volume)
			play()
			var specific_song_path = stream.resource_path.get_file()
			_log_message(["Playing specific track: ", specific_song_path])
			
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
		_log_message("Playlist finished, shuffling again!")
		var current_playlist = arena_playlists.get(GameManager.current_arena_index, arena_playlists[0])
		shuffled_playlist = current_playlist.duplicate()
		shuffled_playlist.shuffle()
	
	stream = shuffled_playlist.pop_front()
	volume_db = linear_to_db(linear_volume)
	play()
	_emit_volume_changed()
	var next_shuffled_song = stream.resource_path.get_file()
	_log_message(["Now sounds: ", next_shuffled_song])
	
func play_sfx(sound_resource: AudioStream):
	if is_instance_valid(sfx_player) and sound_resource:
		sfx_player.stream = sound_resource
		sfx_player.play()

func fade_out_and_stop(duration: float):
	if not playing or is_fading:
		return
		
	is_fading = true
	_log_message("Starting fade out of the music...")
	
	var tween = create_tween()
	tween.tween_property(self, "volume_db", -80.0, duration)
	
	await tween.finished
	
	stop()
	volume_db = 0.0 
	is_fading = false
	_log_message("Music Stopped.")
	
func increase_volume():
	linear_volume = clamp(linear_volume + (max_linear_volume * 0.05), min_linear_volume, max_linear_volume)
	volume_db = linear_to_db(linear_volume)
	_emit_volume_changed()

func decrease_volume():
	linear_volume = clamp(linear_volume - (max_linear_volume * 0.05), min_linear_volume, max_linear_volume)
	volume_db = linear_to_db(linear_volume)
	_emit_volume_changed()

func get_volume_percent() -> float:
	return (linear_volume / max_linear_volume) * 100.0

func _emit_volume_changed():
	volume_changed.emit(get_volume_percent())
	
func _log_message(message):
	if GameManager.is_debug_text == true:
		var final_string = ""
		if typeof(message) == TYPE_ARRAY:
			for arg in message:
				final_string += str(arg) + " "
			final_string = final_string.strip_edges()
		else:
			final_string = str(message)
		print_rich("[color=yellow][DEV LOG][/color] " + final_string)
	else:
		return
