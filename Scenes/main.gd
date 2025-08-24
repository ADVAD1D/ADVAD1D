extends Node2D

@onready var player = $CharacterBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.died.connect(_on_player_died) # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_death_zone_area_entered(area: Area2D) -> void:
	if area.is_in_group("asteroides"):
		area.queue_free()


func _on_laser_zone_area_entered(area: Area2D) -> void:
	if area.is_in_group("lasers"):
		area.queue_free() # Replace with function body.
		
func _on_player_died() -> void:
	GameManager.reset_score()
	get_tree().call_deferred("reload_current_scene")
