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
		# Limit to 60 FPS to stabilize physics/movement and save battery
		Engine.max_fps = 60
		# Turn ON V-Sync to perfectly pace 60 FPS into 120Hz/90Hz compositors when Android UI overlays appear
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		# Wake Lock: Prevent the screen from sleeping while playing
		DisplayServer.screen_set_keep_on(true)
		# Dynamically expand the viewport to fill Ultrawide screens without black bars
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	else:
		# 0 means unlimited FPS (or handled by Desktop V-Sync)
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		# Allow desktop monitors to sleep normally
		DisplayServer.screen_set_keep_on(false)
