class_name VolumeRow
extends Control
## One volume row (icon, -, percentage, +) for the music (MusicPlayer) or the sound effects
## (SfxManager). Works like the pause menu volume buttons: holding a button keeps changing
## the volume, and a click plays at the new volume. The managers save every change.
## Children: DecreaseButton, IncreaseButton (TextureButton), Percentage (Label).

enum Channel { MUSIC, SFX }

## Seconds between steps while a button is held (the pause menu's VolumeTimer).
const REPEAT_DELAY: float = 0.1

@export var channel: Channel = Channel.MUSIC
## Plays at the new volume after each step (on Master, so it is heard even at SFX 0%).
@export var click_sound: AudioStream

var _repeat_left: float = 0.0

@onready var decrease_button: TextureButton = $DecreaseButton
@onready var increase_button: TextureButton = $IncreaseButton
@onready var percentage_label: Label = $Percentage


func _ready() -> void:
	if channel == Channel.MUSIC:
		MusicPlayer.volume_changed.connect(_show_percent)
		_show_percent(MusicPlayer.get_volume_percent())
	else:
		SfxManager.sfx_volume_changed.connect(_show_percent)
		_show_percent(SfxManager.get_sfx_volume_percent())


func _process(delta: float) -> void:
	_repeat_left -= delta
	if _repeat_left > 0.0:
		return
	var step: int = 0
	if decrease_button.is_pressed():
		step = -1
	elif increase_button.is_pressed():
		step = 1
	if step != 0:
		_change_volume(step)
		_repeat_left = REPEAT_DELAY


func _change_volume(step: int) -> void:
	var new_db: float
	if channel == Channel.MUSIC:
		if step > 0:
			MusicPlayer.increase_volume()
		else:
			MusicPlayer.decrease_volume()
		new_db = MusicPlayer.volume_db
	else:
		if step > 0:
			SfxManager.increase_sfx_volume()
		else:
			SfxManager.decrease_sfx_volume()
		new_db = AudioServer.get_bus_volume_db(SfxManager.sfx_bus_index)
	_play_click(new_db)


func _play_click(volume_db: float) -> void:
	if click_sound == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = click_sound
	player.bus = &"Master"
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _show_percent(percent: float) -> void:
	percentage_label.text = str(int(round(percent))) + "%"
