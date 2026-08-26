extends Area2D

var speed: float
var direction: Vector2
var speed_multiplier: float = 1.0

@export var explosion_scene: PackedScene
@export var asteroid_explosion_sound: PackedScene

var speed_asteroids: float

func _ready() -> void:
	speed = randf_range(500.0, 1000.0) * speed_multiplier
	speed_asteroids = randf_range(150.0, 300.0)
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	
func start(target_position):
	direction = (target_position - position).normalized()

func _process(delta: float) -> void:
	position += direction * speed * delta
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
		
		GameManager.add_score(50)
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
		EnemyLaserPool.release(area)
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
		
	if area.is_in_group("player_shield"):
		if explosion_scene:
			var asteroid_explosion = explosion_scene.instantiate()
			add_sibling(asteroid_explosion)
			asteroid_explosion.position = position
		
		if asteroid_explosion_sound:
			var sound_instance = asteroid_explosion_sound.instantiate()
			get_parent().add_child(sound_instance)
			sound_instance.position = position
		queue_free()
			
	if area.is_in_group("allies"):
		if explosion_scene:
			var asteroid_explosion = explosion_scene.instantiate()
			add_sibling(asteroid_explosion)
			asteroid_explosion.position = position
		
		if asteroid_explosion_sound:
			var sound_instance = asteroid_explosion_sound.instantiate()
			get_parent().add_child(sound_instance)
			sound_instance.position = position
			
		queue_free()
