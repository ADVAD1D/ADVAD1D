extends Area2D
## Pickup that puts `reward_scene` on the player (laser shield, quad laser...). It isn't
## collected while the player already has a child in `active_group` (that reward running).

@export var reward_scene: PackedScene
## Group of the reward while it's on the player.
@export var active_group: StringName = &"player_shield"
@export var bob_amplitude: float = 8.0 
@export var bob_speed: float = 3.0

var base_y_position: float
var spawn_time: float = 0.2
@onready var sprite: Sprite2D = $Sprite2D

var is_collected: bool = false
var _spawn_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	scale = Vector2.ZERO
	_spawn_tween = create_tween()
	_spawn_tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	_spawn_tween.tween_property(self, "scale", Vector2(4.5, 4.5), spawn_time)
	
func _physics_process(_delta: float) -> void:
	if is_collected:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			var has_shield = false
			for child in body.get_children():
				if child.is_in_group(active_group):
					has_shield = true
					break
			if not has_shield:
				is_collected = true
				call_deferred("_equip_shield", body)
				break
				
func _process(_delta: float) -> void:
	var time = Time.get_ticks_msec() * 0.001
	var displacement = sin(time * bob_speed) * bob_amplitude
	sprite.position.y = base_y_position + displacement
func _equip_shield(player_node):
	var shield = reward_scene.instantiate()
	player_node.add_child(shield)
	shield.position = Vector2.ZERO
	_shrink_and_free()

## The spawn animation backwards: it shrinks away once collected, then frees itself.
func _shrink_and_free() -> void:
	set_deferred("monitoring", false)
	if _spawn_tween:
		_spawn_tween.kill()
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_property(self, "scale", Vector2.ZERO, spawn_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
