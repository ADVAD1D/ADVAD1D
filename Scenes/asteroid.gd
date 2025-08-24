extends Area2D

var speed: float
var direction: Vector2

@export var explosion_scene: PackedScene

func _ready() -> void:
	speed = randf_range(500.0, 800.0)
	scale = Vector2.ZERO
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	
func start(target_position):
	direction = (target_position - position).normalized()

func _process(delta: float) -> void:
	position += direction * speed * delta
	var speed_asteroids = randf_range(150.0, 300.0)
	rotation_degrees += speed_asteroids * delta


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("lasers"):
		var asteroid_explosion = explosion_scene.instantiate()
		add_sibling(asteroid_explosion)
		asteroid_explosion.position = position
		GameManager.add_score(10)
		queue_free() # Replace with function body.
