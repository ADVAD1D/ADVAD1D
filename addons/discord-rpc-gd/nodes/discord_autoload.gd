## This is a GDscript Node wich gets automatically added as Autoload while installing the addon.
## 
## It can run in the background to comunicate with Discord.
## You don't need to use it. If you remove it make sure to run [code]DiscordRPC.run_callbacks()[/code] in a [code]_process[/code] function.
##
## @tutorial: https://github.com/vaporvee/discord-rpc-godot/wiki
extends Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var discord_app_id = EnvParser.parse("DISCORD_APP_ID")
	
	DiscordRPC.app_id = int(discord_app_id) # Replace with function body.
	DiscordRPC.large_image = "portada" # Image key from "Art Assets"
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system()) # "02:46 elapsed"
	# DiscordRPC.end_timestamp = int(Time.get_unix_time_from_system()) + 3600 # +1 hour in unix time / "01:00:00 remaining"
	DiscordRPC.refresh() # Always refresh after changing the values!

func  _process(_delta) -> void:
	DiscordRPC.run_callbacks()
