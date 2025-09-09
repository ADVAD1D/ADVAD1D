extends Area2D

@export var speed: float = 700.0
@export var acceleration: float = 3.0
@export var rotation_speed: float = 1000.0
@export var separation_strength: float = 150.0
@export var saw_particles: PackedScene

signal died

@onready var separation_area: Area2D = $SeparationArea
@onready var metal_sound: AudioStreamPlayer2D = $MetalSound

var player: Node2D
var current_velocity: Vector2 = Vector2.ZERO
var is_dying: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	rotation_speed = randf_range(1400.0, 1600.0)
	speed = randf_range(900.0, 1000.0)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).from(Vector2.ZERO)

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
	
	current_velocity = current_velocity.lerp(target_velocity, acceleration * delta)
	global_position += current_velocity * delta


func _on_area_entered(area: Area2D) -> void:
	if (area.is_in_group("lasers") or area.is_in_group("enemies_death")) and not is_dying:
		is_dying = true
		
		if area.is_in_group("lasers"):
			area.queue_free()
		
		var saw_particles_instance = saw_particles.instantiate()
		add_sibling(saw_particles_instance)
		saw_particles_instance.position = position
		
		hide()
		$CollisionShape2D.set_deferred("disabled", true) 
		GameManager.add_score(200)
		
		metal_sound.play()
		died.emit()
		
		await metal_sound.finished 
		
		queue_free()
