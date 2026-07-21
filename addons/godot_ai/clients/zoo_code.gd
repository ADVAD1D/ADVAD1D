@tool
extends McpClient


func _init() -> void:
	id = "zoo_code"
	display_name = "Zoo Code"
	config_type = "json"
	path_template = {
		"darwin": "~/Library/Application Support/Code/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json",
		"windows": "$APPDATA/Code/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json",
		"linux": "$XDG_CONFIG_HOME/Code/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json",
	}
	server_key_path = PackedStringArray(["mcpServers"])
	## Local validation against the installed extension shows Zoo stores MCP
	## entries in `settings/mcp_settings.json` under `mcpServers`, matching Roo's
	## shape. Its changelog also references Streamable HTTP support, so pin the
	## transport explicitly to avoid any typeless entry falling back to SSE.
	entry_extra_fields = {"type": "streamable-http"}
	## Preserve user-controlled state across reconfigure, parallel to Roo/Kilo.
	entry_initial_fields = {"disabled": false, "alwaysAllow": []}
