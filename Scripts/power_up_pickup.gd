extends Area2D

@export var reward_scene: PackedScene
@export var bob_amplitude: float = 8.0 
@export var bob_speed: float = 3.0

var base_y_position: float
var spawn_time: float = 0.2
@onready var sprite: Sprite2D = $Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered) # Replace with function body.
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(4.5, 4.5), spawn_time).from(Vector2.ZERO)
	
func _process(_delta: float) -> void:
	var time = Time.get_ticks_msec() * 0.001
	var displacement = sin(time * bob_speed) * bob_amplitude
	sprite.position.y = base_y_position + displacement

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		call_deferred("_handle_pickup")
		
func _handle_pickup():
	if reward_scene:
		var reward_instance = reward_scene.instantiate()
		get_parent().add_child(reward_instance)
		reward_instance.global_position = global_position
		
	queue_free()
