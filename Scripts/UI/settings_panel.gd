class_name SettingsPanel
extends NinePatchRect
## The settings panel (Scenes/UI/settings_panel.tscn), shared by the main menu (gear
## button) and the pause menu: controls, FPS, full screen, retro shader / shader
## optimization, CRT roll and speedrun toggles, special thanks, music and SFX volume rows.
## Every toggle writes GameManager and calls GameManager.apply_settings() (saves and emits
## settings_changed) so open
## scenes can react (the HUD's FPS label); CRT changes are applied to every CRT shader of
## the current scene through ShaderManager.refresh_current_scene().
## Opening and closing it is up to the scene that holds it.

## Relative/global controls toggled (the main menu shows a hint label).
signal controls_changed(is_relative: bool)
## The special thanks button was pressed (the main menu opens its panel).
signal special_thanks_requested

## Played when the mouse enters a button.
@export var hover_sound: AudioStream
## Played on every toggle.
@export var toggle_sound: AudioStream
## Shows the special thanks button (the pause menu has nowhere to open it).
@export var show_special_thanks: bool = true
## The speedrun timer only starts with a run, so mid-run (pause menu) the toggle is locked.
@export var allow_speedrun_toggle: bool = true

var _hover_player: AudioStreamPlayer
var _toggle_player: AudioStreamPlayer

@onready var controls_button: TextureButton = $ControlsButton
@onready var fps_button: TextureButton = $FPSButton
@onready var retro_button: TextureButton = $RetroShaderButton
@onready var roll_button: TextureButton = $RollButton
@onready var fullscreen_button: TextureButton = $FullScreenButton
@onready var speedrun_button: TextureButton = $SpeedrunButton
@onready var special_thanks_button: TextureButton = $SpecialThanksButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hover_player = _make_player(hover_sound, 0.5)
	_toggle_player = _make_player(toggle_sound, 1.0)
	_connect_hover_sounds(self)
	sync_with_settings()

	controls_button.pressed.connect(_play_toggle)
	controls_button.toggled.connect(func(on: bool):
		GameManager.relative_control_active = on
		_save()
		controls_changed.emit(on)
	)

	fps_button.pressed.connect(_play_toggle)
	fps_button.toggled.connect(func(on: bool):
		GameManager.show_fps = on
		_save()
	)

	fullscreen_button.toggled.connect(func(on: bool):
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	)

	speedrun_button.toggled.connect(func(on: bool):
		GameManager.speedrun_mode_active = on
		_play_toggle()
		_save()
	)

	# Mobile: the button turns the retro (CRT) shader on/off. PC: it is the "optimize
	# shaders" toggle (lighter CRT, which never rolls)
	retro_button.pressed.connect(_play_toggle)
	retro_button.toggled.connect(func(on: bool):
		if GameManager.mobile_mode_active:
			GameManager.retro_shader_active = on
		else:
			GameManager.pc_optimize_shaders = on
		_save()
		ShaderManager.refresh_current_scene()
		_update_roll_button()
	)

	# Pressed = roll off (like the shader button: pressed = lighter effects)
	roll_button.pressed.connect(_play_toggle)
	roll_button.toggled.connect(func(on: bool):
		GameManager.crt_roll_enabled = not on
		_save()
		ShaderManager.refresh_current_scene()
	)

	special_thanks_button.visible = show_special_thanks
	special_thanks_button.pressed.connect(special_thanks_requested.emit)


## Puts every toggle in line with GameManager (without firing their signals). Called on
## ready and every time the panel opens, since another scene may have changed something.
func sync_with_settings() -> void:
	controls_button.set_pressed_no_signal(GameManager.relative_control_active)
	fps_button.set_pressed_no_signal(GameManager.show_fps)
	fullscreen_button.set_pressed_no_signal(
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	speedrun_button.set_pressed_no_signal(GameManager.speedrun_mode_active)
	speedrun_button.disabled = not allow_speedrun_toggle
	speedrun_button.modulate.a = 1.0 if allow_speedrun_toggle else 0.4
	if GameManager.mobile_mode_active:
		retro_button.set_pressed_no_signal(GameManager.retro_shader_active)
	else:
		retro_button.set_pressed_no_signal(GameManager.pc_optimize_shaders)
	roll_button.set_pressed_no_signal(not GameManager.crt_roll_enabled)
	_update_roll_button()


## Disabled (dimmed) where the CRT never rolls anyway: mobile, web and optimized shaders.
func _update_roll_button() -> void:
	roll_button.disabled = not ShaderManager.is_roll_supported()


func _save() -> void:
	GameManager.apply_settings()


func _play_toggle() -> void:
	if _toggle_player:
		_toggle_player.play()


func _make_player(stream: AudioStream, pitch: float) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.bus = &"SFX"
	add_child(player)
	return player


func _connect_hover_sounds(node: Node) -> void:
	if node is BaseButton and _hover_player:
		node.mouse_entered.connect(_hover_player.play)
	for child in node.get_children():
		_connect_hover_sounds(child)
