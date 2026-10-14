extends Node
## Autoload: MobileOptimizer
## Optimizes the game for Android/iOS by detecting the platform, enabling mobile mode,
## and capping the framerate to prevent thermal throttling and battery drain.

func _ready():
	# Detect if running on a mobile OS
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		# Automatically toggle the mobile controls on GameManager
		GameManager.mobile_mode_active = true
	
	apply_performance_settings()

## Applies framerate and performance settings based on the current mobile mode
func apply_performance_settings():
	if GameManager.mobile_mode_active:
		# Limit the framerate to save battery, but only to a rate the screen can show evenly:
		# 60 on 60/120Hz panels, 90 on 90Hz, 72 on 144Hz... (60 FPS on a 90Hz panel judders)
		var paced_fps: int = _get_paced_fps()
		Engine.max_fps = paced_fps
		# One physics tick per rendered frame: movement done in _physics_process (player,
		# enemies) stays in step with movement done in _process (camera, lasers, asteroids)
		Engine.physics_ticks_per_second = paced_fps
		# Turn ON V-Sync to perfectly pace 60 FPS into 120Hz/90Hz compositors when Android UI overlays appear
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		# Wake Lock: Prevent the screen from sleeping while playing
		DisplayServer.screen_set_keep_on(true)
		# Dynamically expand the viewport to fill Ultrawide screens without black bars
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		# Lights, the background shader and the CRT pass are paid per pixel: rendering at the
		# base resolution instead of the phone's native one cuts that cost many times over
		if GameManager.mobile_low_res_render:
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		else:
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	else:
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		# 0 means unlimited FPS (or handled by Desktop V-Sync)
		Engine.max_fps = 0
		Engine.physics_ticks_per_second = ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		# Allow desktop monitors to sleep normally
		DisplayServer.screen_set_keep_on(false)

## Returns the lowest framerate >= 55 that divides the screen refresh rate evenly,
## so every frame stays on screen for the same number of refreshes.
func _get_paced_fps() -> int:
	var refresh_rate: float = DisplayServer.screen_get_refresh_rate()
	if refresh_rate < 30.0:
		# Unknown refresh rate (the engine returns -1)
		return 60
	var paced: float = refresh_rate
	var divisor: int = 2
	while refresh_rate / divisor >= 55.0:
		paced = refresh_rate / divisor
		divisor += 1
	return roundi(paced)
