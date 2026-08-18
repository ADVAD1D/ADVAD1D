extends Control

@export var next_scene: PackedScene
@export var display_duration: float = 2.0
@export var fade_out_duration: float = 0.5
@export var fade_in_duration: float = 0.5

@onready var sprite_logo: TextureRect = $LogoSprite

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if GameManager.mobile_mode_active:
		get_tree().root.size_changed.connect(_on_window_resized)
		_on_window_resized()
		
	sprite_logo.modulate.a = 0.0
	
	var sprite_fadein_tween = create_tween()
	sprite_fadein_tween.tween_property(sprite_logo, "modulate:a", 1.0, fade_in_duration)
	GameManager.can_pause = false
	start_sequence()

func _on_window_resized() -> void:
	var center_x = get_viewport().get_visible_rect().size.x / 2.0
	var center_y = get_viewport().get_visible_rect().size.y / 2.0
	
	if sprite_logo:
		sprite_logo.anchor_left = 0.5
		sprite_logo.anchor_right = 0.5
		sprite_logo.anchor_top = 0.5
		sprite_logo.anchor_bottom = 0.5
		sprite_logo.position.x = center_x - 38.0
		sprite_logo.position.y = center_y - 41.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func start_sequence():
	await get_tree().create_timer(display_duration).timeout
	
	#fades 
	var sprite_tween = create_tween()
	sprite_tween.tween_property(sprite_logo, "modulate:a", 0.0, fade_out_duration)
	
	await sprite_tween.finished
	
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
	else:
		print("Error, no se asignó una escena")
