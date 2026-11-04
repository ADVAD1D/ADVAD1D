extends Area2D

var speed: float
var direction: Vector2
var speed_multiplier: float = 1.0

@export var explosion_scene: PackedScene
@export var asteroid_explosion_sound: PackedScene

var speed_asteroids: float
## Set by explode(), so two hits in the same frame don't explode (or score) twice.
var _exploded: bool = false

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
	if _exploded:
		return
	if area.is_in_group("lasers"):
		# Only the player's lasers give score
		GameManager.add_score(50)
		explode()
	elif area.is_in_group("enemy_laser"):
		EnemyLaserPool.release(area)
		explode()
	elif area.is_in_group("saws") or area.is_in_group("player_shield") \
			or area.is_in_group("allies"):
		explode()


## Explosion effect + sound, then the asteroid is removed. Gives no score (the caller adds
## it when the player did it). Also used by arena 2's laser guns (LaserGun beam).
func explode() -> void:
	if _exploded:
		return
	_exploded = true
	if explosion_scene:
		var asteroid_explosion = explosion_scene.instantiate()
		asteroid_explosion.global_position = global_position
		get_parent().call_deferred("add_child", asteroid_explosion)

	if asteroid_explosion_sound:
		var sound_instance = asteroid_explosion_sound.instantiate()
		sound_instance.global_position = global_position
		get_parent().call_deferred("add_child", sound_instance)
	queue_free()
