extends Area2D

@export var reward_scene: PackedScene
@export var bob_amplitude: float = 8.0 
@export var bob_speed: float = 3.0

var base_y_position: float
var spawn_time: float = 0.2
@onready var sprite: Sprite2D = $Sprite2D

var is_collected: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("pickups")
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_property(self, "scale", Vector2(4.5, 4.5), spawn_time)
	
func _physics_process(_delta: float) -> void:
	if is_collected:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			var has_shield = false
			for child in body.get_children():
				if child.is_in_group("player_shield"):
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
	queue_free()
