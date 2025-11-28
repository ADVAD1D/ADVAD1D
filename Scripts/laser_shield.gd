extends Area2D

@export var animated_sprites: Array[AnimatedSprite2D]
@export var duration_timer: Timer

@onready var spawn_time: float = 0.1
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play_all("default") # Replace with function body.
	duration_timer.timeout.connect(queue_free)
	duration_timer.start()
	area_entered.connect(_on_area_entered)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), spawn_time).from(Vector2.ZERO)

func play_all(animation_name: String):
	for sprite in animated_sprites:
		if is_instance_valid(sprite):
			sprite.play(animation_name)
		
func _on_area_entered(area: Area2D):
	if area.is_in_group("enemy_laser"):
		if area.has_method("set_direction"):
			area.set_direction(-area.direction)
			#change the group
			area.remove_from_group("enemy_laser")
			area.add_to_group("lasers")
	elif area.is_in_group("saws"):
		area.die_and_respawn()
