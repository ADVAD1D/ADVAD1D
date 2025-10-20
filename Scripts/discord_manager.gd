extends Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	DiscordRPC.app_id = 1429848946213126245 # Replace with function body.
	DiscordRPC.large_image = "portada" # Image key from "Art Assets"
	DiscordRPC.large_image_text = "Try it now!"
	DiscordRPC.small_image = "boss" # Image key from "Art Assets"
	DiscordRPC.small_image_text = "Fighting the end boss! D:"
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system()) # "02:46 elapsed"
	# DiscordRPC.end_timestamp = int(Time.get_unix_time_from_system()) + 3600 # +1 hour in unix time / "01:00:00 remaining"
	DiscordRPC.refresh() # Always refresh after changing the values!
