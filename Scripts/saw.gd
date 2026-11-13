extends Area2D

@export var speed: float = 700.0
@export var acceleration: float = 3.0
@export var rotation_speed: float = 1000.0
@export var separation_strength: float = 150.0
@export var saw_particles: PackedScene
## Gap (world units) between a boss's edge and the saw's centre: the saw never gets closer
## (arena 3's GEMELAs). About the saw's radius plus some room.
@export var boss_margin: float = 130.0

## Extra distance past boss_margin where the saw already starts steering away.
const BOSS_STEER_ZONE: float = 150.0
## How hard that steering pushes, in multiples of the saw's speed.
const BOSS_PUSH_STRENGTH: float = 1.5

signal died

@onready var separation_area: Area2D = $SeparationArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trail: GPUParticles2D = $Trail

var metal_sound: AudioStreamPlayer2D = preload("res://Assets/Audio/AudioScenes/saw_explosion_sound.tscn").instantiate()

var player: Node2D
var current_velocity: Vector2 = Vector2.ZERO
var is_dying: bool = false

func setup(config: Dictionary):
	speed = config.get("speed", 700.0)

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	# The arena's enemy colour (sprite, trail and light)
	ArenaEnemySkin.apply(self)
	rotation_speed = randf_range(1400.0, 1600.0)
	speed = randf_range(900.0, 1000.0)
	
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	if GameManager.mobile_mode_active:
		if has_node("Trail"):
			trail.lifetime = 0.2

func _physics_process(delta: float) -> void:
	rotation_degrees += rotation_speed * delta

	var target_velocity = Vector2.ZERO
	if is_instance_valid(player):
		var direction_to_player = global_position.direction_to(player.global_position)
		target_velocity = direction_to_player * speed
		
	var separation_vector = Vector2.ZERO
	var neighbors = separation_area.get_overlapping_areas()
	
	if not neighbors.is_empty():
		for neighbor_area in neighbors:
			separation_vector += (neighbor_area.global_position - global_position)
		
		separation_vector = -separation_vector.normalized()

	target_velocity += separation_vector * separation_strength
	target_velocity += _boss_push() * speed * BOSS_PUSH_STRENGTH

	current_velocity = current_velocity.lerp(target_velocity, acceleration * delta)
	global_position += current_velocity * delta
	_keep_out_of_bosses()


## Arena 3's GEMELAs ("bosses" group): the saw is pushed away when it gets within
## BOSS_STEER_ZONE of the boss_margin limit, harder the closer it gets.
func _boss_push() -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for boss in get_tree().get_nodes_in_group("bosses"):
		if not boss.has_method("get_avoid_radius"):
			continue
		var away: Vector2 = global_position - boss.global_position
		var limit: float = boss.get_avoid_radius() + boss_margin
		var distance: float = away.length()
		if limit > boss_margin and distance < limit + BOSS_STEER_ZONE and distance > 0.001:
			push += away / distance * (1.0 - maxf(distance - limit, 0.0) / BOSS_STEER_ZONE)
	return push


## Never closer than boss_margin to a boss's edge (it used to fly under them).
func _keep_out_of_bosses() -> void:
	for boss in get_tree().get_nodes_in_group("bosses"):
		if not boss.has_method("get_avoid_radius"):
			continue
		var radius: float = boss.get_avoid_radius()
		if radius <= 0.0:
			continue
		var away: Vector2 = global_position - boss.global_position
		var limit: float = radius + boss_margin
		if away.length() < limit:
			if away.length() < 0.001:
				away = Vector2.RIGHT
			global_position = boss.global_position + away.normalized() * limit


func _on_area_entered(area: Area2D) -> void:
	if is_dying:
		return
	if (area.is_in_group("lasers") or area.is_in_group("enemies_death") or area.is_in_group("allies")):
		if area.is_in_group("lasers"):
			# Enemy lasers deflected by the shield belong to EnemyLaserPool
			if area.has_method("deactivate"):
				EnemyLaserPool.release(area)
			else:
				area.queue_free()
			GameManager.add_score(200)
		# Only saws the player destroys count (the arena's death zone doesn't)
		if not area.is_in_group("enemies_death"):
			AchievementManager.add_stat(&"saws_destroyed")
		die_and_respawn()

func die_and_respawn():
	if is_dying:
		return
	is_dying = true
	collision_shape.set_deferred("disabled", true)
	
	var saw_particles_instance = saw_particles.instantiate()
	ArenaEnemySkin.apply(saw_particles_instance)
	add_sibling(saw_particles_instance)
	saw_particles_instance.position = position
	
	hide()
	get_tree().current_scene.add_child(metal_sound)
	metal_sound.play()
	
	await metal_sound.finished
	died.emit(self)
	queue_free()

func die_silently():
	if is_dying:
		return
	is_dying = true
	
	collision_shape.set_deferred("disabled", true)
	
	# OPTIMIZATION: Stagger the explosions randomly over 0.2s to prevent lag spikes on mobile
	await get_tree().create_timer(randf_range(0.01, 0.25)).timeout
	
	hide()
	
	var saw_particles_instance = saw_particles.instantiate()
	ArenaEnemySkin.apply(saw_particles_instance)
	add_sibling(saw_particles_instance)
	saw_particles_instance.position = position
	
	get_tree().current_scene.add_child(metal_sound)
	metal_sound.play()
	
	await metal_sound.finished
	queue_free()
