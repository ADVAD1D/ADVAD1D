extends Area2D

var speed: float
var direction: Vector2

@export var explosion_scene: PackedScene
@export var asteroid_explosion_sound: PackedScene

func _ready() -> void:
	speed = randf_range(500.0, 1000.0)
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
		if explosion_scene:
			var asteroid_explosion = explosion_scene.instantiate()
			add_sibling(asteroid_explosion)
			asteroid_explosion.position = position
		
		if asteroid_explosion_sound:
			var sound_instance = asteroid_explosion_sound.instantiate()
			get_parent().add_child(sound_instance)
			sound_instance.position = position
		
		GameManager.add_score(10)
		queue_free() # Replace with function body.
		
	if area.is_in_group("enemy_laser"):
		if explosion_scene:
			var asteroid_explosion = explosion_scene.instantiate()
			add_sibling(asteroid_explosion)
			asteroid_explosion.position = position
		
		if asteroid_explosion_sound:
			var sound_instance = asteroid_explosion_sound.instantiate()
			get_parent().add_child(sound_instance)
			sound_instance.position = position
		area.queue_free()
		queue_free()
		
	if area.is_in_group("saws"):
		if explosion_scene:
			var asteroid_explosion = explosion_scene.instantiate()
			add_sibling(asteroid_explosion)
			asteroid_explosion.position = position
		
		if asteroid_explosion_sound:
			var sound_instance = asteroid_explosion_sound.instantiate()
			get_parent().add_child(sound_instance)
			sound_instance.position = position
		queue_free()
