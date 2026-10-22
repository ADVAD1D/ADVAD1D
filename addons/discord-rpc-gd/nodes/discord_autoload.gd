## This is a GDscript Node wich gets automatically added as Autoload while installing the addon.
## 
## It can run in the background to comunicate with Discord.
## You don't need to use it. If you remove it make sure to run [code]DiscordRPC.run_callbacks()[/code] in a [code]_process[/code] function.
##
## @tutorial: https://github.com/vaporvee/discord-rpc-godot/wiki
extends Node

var is_desktop: bool = true
# The DiscordRPC singleton comes from the GDExtension, which is only exported for
# desktop. Look it up at runtime instead of using the bare `DiscordRPC` identifier,
# otherwise this script fails to parse on Web/Android/iOS builds.
var discord_rpc: Object = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Ignore Discord RPC process entirely on Web and Mobile
	if OS.has_feature("web") or OS.has_feature("mobile") or GameManager.mobile_mode_active or GameManager.force_web_mode \
			or not Engine.has_singleton("DiscordRPC"):
		is_desktop = false
		set_process(false)
		return

	discord_rpc = Engine.get_singleton("DiscordRPC")

	# NOTE: The Discord App ID (Client ID) is public information required by the Discord client.
	# It is completely safe to hardcode it here. It is NOT a secret token or key.
	var discord_app_id = 1429848946213126245

	if discord_app_id:
		discord_rpc.app_id = int(discord_app_id) # Replace with function body.
		discord_rpc.large_image = "portada" # Image key from "Art Assets"
		discord_rpc.start_timestamp = int(Time.get_unix_time_from_system()) # "02:46 elapsed"
		# discord_rpc.end_timestamp = int(Time.get_unix_time_from_system()) + 3600 # +1 hour in unix time / "01:00:00 remaining"
		discord_rpc.refresh() # Always refresh after changing the values!
	else:
		print("Error, no se encontró el valor DISCORD_APP_ID en el archivo .env")

func _process(_delta) -> void:
	if is_desktop and discord_rpc:
		discord_rpc.run_callbacks()
