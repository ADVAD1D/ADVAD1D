extends PathFollow2D

@export var speed: float = 200.0
@export var shoot_timerate: float = 0.8

var laser_scene = preload("res://Scenes/enemy_laser.tscn")

@onready var shoot_timer: Timer = $ShootTimer
@onready var sprite: AnimatedSprite2D = $DroneSprite
@onready var shoot_muzzle: Marker2D = $Marker2D
@onready var laser_sound: AudioStreamPlayer2D = $LsrSound

var move_direction: int = 1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# This code calculates and prints the progress_ratio for each control point of the parent Path2D.
	# This is temporary and can be removed after noting down the values.
	var path_node = get_parent()
	if not path_node is Path2D:
		print("Parent is not a Path2D node.")
		return

	var curve = path_node.curve
	if not curve:
		print("Path2D does not have a Curve2D resource.")
		return

	var total_length = curve.get_baked_length()
	if total_length == 0:
		print("Curve has no length. Cannot calculate progress ratios.")
		return
		
	print("--- Progress Ratios for Path2D DRONE1 Control Points ---")
	for i in range(curve.get_point_count()):
		var point_pos = curve.get_point_position(i)
		var offset = curve.get_closest_offset(point_pos)
		var ratio = offset / total_length
		print("Point %d: progress_ratio = %f" % [i, ratio])
	print("-------------------------------------------------")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	progress += speed * move_direction * delta
	if progress_ratio >= 1.0:
		sprite.rotation_degrees = -90.0
	elif progress_ratio >= 0.82:
		sprite.rotation_degrees = -90.0
	elif progress_ratio >= 0.18:
		sprite.rotation_degrees = -150.0
	else:
		sprite.rotation_degrees = -90.0
	shoot()

func shoot():
	if shoot_timer.is_stopped():
		var laser_instance = laser_scene.instantiate()
		get_parent().add_child(laser_instance)
		laser_instance.global_position = shoot_muzzle.global_position
		var fire_direction = Vector2.RIGHT.rotated(sprite.global_rotation)
		laser_instance.start(fire_direction)
		shoot_timer.start()
		
		laser_sound.play()
