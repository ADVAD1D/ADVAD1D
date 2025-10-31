extends Area2D

@export var speed: float = 700.0
@export var acceleration: float = 3.0
@export var saw_particles: PackedScene

#this variable takes the elements in nodes tree
#CharacterBody hereda de la clase padre de Node, funciona bien al tiparla así
@export var player: Node2D

@onready var metal_sound: AudioStreamPlayer2D = $MetalSound
@onready var shoot_timer: Timer = $ShootTimer
@onready var laser_scene = preload("res://Scenes/laser.tscn")

#muzzles
@onready var muzzle1: Marker2D = $Marker2D1
@onready var muzzle2: Marker2D = $Marker2D2
@onready var muzzle3: Marker2D = $Marker2D3
@onready var muzzle4: Marker2D = $Marker2D4
@onready var muzzle5: Marker2D = $Marker2D5
@onready var muzzle6: Marker2D = $Marker2D6

var rotation_speed: float
var current_velocity: Vector2 = Vector2.ZERO
var is_dying: bool = false
var spawn_time: float = 0.1

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	rotation_speed = randf_range(1200.0, 1500.0)
	speed = randf_range(900.0, 1000.0)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), spawn_time).from(Vector2.ZERO)

func _physics_process(delta: float) -> void:
	rotation_degrees += rotation_speed * delta

	var target_velocity = Vector2.ZERO
	if is_instance_valid(player):
		var direction_to_player = global_position.direction_to(player.global_position)
		target_velocity = direction_to_player * speed
	
	current_velocity = current_velocity.lerp(target_velocity, acceleration * delta)
	global_position += current_velocity * delta
	
	shoot()
	
func shoot():
	if is_dying:
		return
		
	if shoot_timer.is_stopped():
		var muzzles = [muzzle1, muzzle2, muzzle3, muzzle4, muzzle5, muzzle6]
		
		for muzzle in muzzles:
			var laser_instance = laser_scene.instantiate()
			get_parent().add_child(laser_instance)
			laser_instance.global_position = muzzle.global_position
			var fire_direction = global_position.direction_to(muzzle.global_position)
			laser_instance.start(fire_direction)
			
		shoot_timer.start()

func _on_area_entered(area: Area2D) -> void:
	if is_dying:
		return
	
	if area.is_in_group("enemy_laser") or area.is_in_group("saws"):
		area.queue_free()
		die()

func die():
	is_dying = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	
	var saw_particles_instance = saw_particles.instantiate()
	get_parent().add_child(saw_particles_instance)
	saw_particles_instance.position = position
	
	hide()
	metal_sound.play()
	
	await metal_sound.finished
	queue_free()
