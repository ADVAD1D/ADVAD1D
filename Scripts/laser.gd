extends Area2D

@export var speed = 2100
@export var enemy_laser_particles: PackedScene
@onready var laser_light: PointLight2D = $PointLight2D
var direction = Vector2.ZERO

func _ready() -> void:
	if GameManager.mobile_mode_active or OS.has_feature("mobile") or OS.has_feature("web") or GameManager.force_web_mode:
		if is_instance_valid(laser_light):
			laser_light.shadow_enabled = false
			laser_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# Called when the node enters the scene tree for the first time.
func start(start_direction: Vector2):
	direction = start_direction
	rotation = direction.angle() + PI / 2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var unscaled_delta = delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	position += direction * speed * unscaled_delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("asteroides"):
		queue_free() # Replace with function body.
	if area.is_in_group("enemy_laser"):
		
		if enemy_laser_particles:
			var enemy_particles_instance = enemy_laser_particles.instantiate()
			enemy_particles_instance.global_position = (global_position + area.global_position) / 2
			get_parent().call_deferred("add_child", enemy_particles_instance)

		EnemyLaserPool.release(area)
		queue_free()
