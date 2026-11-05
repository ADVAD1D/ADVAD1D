class_name SimTerminal
extends RefCounted
## Fake shell behind the chat console (ai_console.gd): the training simulation's
## computer, logged in as ADNEX. A tiny read-only filesystem with ls, cd, pwd, cat and a
## fake `sudo pacman -Syu`.
##
## run() returns the output as an Array: each String is a BBCode line (text already
## escaped), each float is a pause in seconds before the next line (for the install log).
## Commands arrive normalized by the console (lowercase, single spaces), so every name in
## FILES is lowercase.

## Directories are Dictionaries (name -> child), files are Strings (their content).
## A directory holding LOCKED can't be opened (permission denied).
const LOCKED: String = "__locked"
const FILES: Dictionary = {
	"home": {
		"adnex": {
			".profile": "export PILOT=ADNEX\nexport SIM_MODE=TRAINING\nalias fight='./simulate --hard'",
			".sim_history": "./simulate --arena 01\n./simulate --arena 01\n./simulate --arena 01 --retry\n./simulate --arena 01 --retry\n./simulate --arena 02",
			".classified": {LOCKED: true},
			"orders.txt": "TRAINING ORDERS\n1. Survive every phase.\n2. Reach the score before the timer ends.\n3. Do not trust the walls in arena 02.",
			"missions": {
				"arena_01.log": "ARENA 01\nSTATUS: ONLINE\nHOSTILES: ships, saws, asteroids\nRESULT: subject keeps coming back.",
				"arena_02.log": "ARENA 02\nSTATUS: ONLINE\nHOSTILES: ships, saws, laser guns\nNOTE: the final transmission is encoded.",
			},
		},
	},
	"sim": {
		"core.bin": "",
		"arenas": {
			"arena_01.map": "GAUNTLET. One bridge. No way back.",
			"arena_02.map": "SEALED ROOM. Guns on both walls.",
		},
		"enemies": {
			"ship.cfg": "speed=500\nfire_rate=high\nmercy=0",
			"saw.cfg": "rpm=9000\nbounces=infinite",
			"laser_gun.cfg": "charge=0.9s\nbeam=wall-to-wall",
		},
	},
	"var": {
		"log": {
			"sim.log": "[OK] Simulation kernel loaded\n[OK] Hostile drones armed\n[OK] Subject ADNEX connected\n[WARN] Subject deaths above expected value",
		},
	},
}
## Home directory (/home/adnex), where the terminal starts.
const HOME_PATH: Array = ["home", "adnex"]
const USER: String = "adnex"

const COLOR_DIR: String = "#40a4f4"
const COLOR_ERROR: String = "#ff6b6b"
const COLOR_OK: String = "#7dffb0"

## Fake Arch Linux upgrade: lines and pauses (seconds).
const PACMAN_LOG: Array = [
	"[sudo] password for adnex: ********", 0.6,
	":: Synchronizing package databases...", 0.4,
	" core is up to date",
	" extra    8.4 MiB  2.1 MiB/s [######] 100%", 0.3,
	" sim      1.2 MiB  980 KiB/s [######] 100%", 0.3,
	":: Starting full system upgrade...",
	"resolving dependencies...", 0.3,
	"looking for conflicting packages...", 0.3,
	"",
	"Packages (4) arena-sim-core-4.7.1-1",
	"  adnex-combat-ai-2.6.1-1",
	"  crt-shader-1.3-2  laser-gun-drv-0.9-1",
	"",
	"Total Download Size:    42.17 MiB",
	"Total Installed Size:  118.60 MiB",
	"",
	":: Proceed with installation? [Y/n] y", 0.6,
	":: Retrieving packages...",
	" arena-sim-core   31.4 MiB [######] 100%", 0.5,
	" adnex-combat-ai   7.9 MiB [######] 100%", 0.3,
	" crt-shader        1.6 MiB [######] 100%", 0.2,
	" laser-gun-drv     1.2 MiB [######] 100%", 0.2,
	"(4/4) checking keys in keyring   [######] 100%", 0.2,
	"(4/4) checking package integrity [######] 100%", 0.2,
	"(4/4) loading package files      [######] 100%", 0.2,
	"(4/4) checking for file conflicts [#####] 100%", 0.2,
	":: Processing package changes...",
	"(1/4) upgrading arena-sim-core   [######] 100%", 0.3,
	"(2/4) upgrading adnex-combat-ai  [######] 100%", 0.3,
	"(3/4) upgrading crt-shader       [######] 100%", 0.2,
	"(4/4) upgrading laser-gun-drv    [######] 100%", 0.2,
	":: Running post-transaction hooks...",
	"(1/2) Reloading simulation daemons...", 0.4,
	"(2/2) Re-arming hostile drones...", 0.4,
]

## fastfetch logo: ship 01 pointing up. Every row has the same length; spaces become
## invisible "#" so all columns are as wide as "#" (the font isn't monospaced).
const SHIP_ART: Array = [
	"         ^         ",
	"        /#\\        ",
	"       /###\\       ",
	"      /#(o)#\\      ",
	"    _/#######\\_    ",
	"  _/###/###\\###\\_  ",
	" /####/#####\\####\\ ",
	"/___/ \\_____/ \\___\\",
	"     \\/     \\/     ",
]
## Logo colours by character (anything else uses the outline colour).
const ART_COLORS: Dictionary = {
	"#": "#0fb8d6",
	"(": "#ff2fb0",
	"o": "#ff2fb0",
	")": "#ff2fb0",
}
const ART_OUTLINE: String = "#a2ffff"
## Colour swatches at the bottom of the fastfetch info.
const PALETTE: Array = ["#0a1418", "#ff6b6b", "#7dffb0", "#ffd36b", "#40a4f4", "#ff2fb0", "#0fb8d6", "#e8ffff"]

## Current directory, as path parts from the root.
var cwd: PackedStringArray = PackedStringArray(HOME_PATH)


## True when this terminal answers the command (its first word).
func handles(command_name: String) -> bool:
	return command_name in ["ls", "cd", "pwd", "cat", "sudo", "fastfetch", "neofetch"]


func run(args: PackedStringArray) -> Array:
	match args[0]:
		"ls":
			return _ls(args)
		"cd":
			return _cd(args)
		"pwd":
			return [esc("/" + "/".join(cwd))]
		"cat":
			return _cat(args)
		"sudo":
			return _sudo(args)
		"fastfetch", "neofetch":
			return [_fastfetch()]
	return []


## Short path for the input prompt: "~", "~/missions", "/sim/arenas".
func get_prompt() -> String:
	var path: String = "/" + "/".join(cwd)
	var home: String = "/" + "/".join(PackedStringArray(HOME_PATH))
	if path.begins_with(home):
		path = "~" + path.substr(home.length())
	return path + ">"


# --- Commands -----------------------------------------------------------------

## ls [-a] [path]: hidden entries (".name") only with a flag that has an "a" (-a, -la...).
func _ls(args: PackedStringArray) -> Array:
	var show_hidden: bool = false
	var target: String = ""
	for arg in args.slice(1):
		if arg.begins_with("-"):
			show_hidden = show_hidden or arg.contains("a")
		else:
			target = arg
	var parts: Variant = resolve(target)
	if parts == null:
		return [_error("ls: cannot access '%s': No such file or directory" % target)]
	var node: Variant = get_node_at(parts)
	if node is String:
		return [esc(target)]
	if (node as Dictionary).has(LOCKED):
		return [_error("ls: cannot open directory '%s': Permission denied" % target)]

	var names: Array = (node as Dictionary).keys()
	names.sort()
	var entries: PackedStringArray = []
	if show_hidden:
		entries.append_array([".", ".."])
	for entry_name in names:
		if String(entry_name).begins_with(".") and not show_hidden:
			continue
		var child: Variant = node[entry_name]
		if child is Dictionary:
			entries.append("[color=%s]%s/[/color]" % [COLOR_DIR, esc(entry_name)])
		else:
			entries.append(esc(entry_name))
	if entries.is_empty():
		return []
	# Three entries per line so they fit the panel
	var lines: Array = []
	for i in range(0, entries.size(), 3):
		lines.append("   ".join(entries.slice(i, i + 3)))
	return lines


## cd [path]: no path or "~" goes home. Like a real shell, success prints nothing.
func _cd(args: PackedStringArray) -> Array:
	var target: String = args[1] if args.size() > 1 else "~"
	var parts: Variant = resolve(target)
	if parts == null:
		return [_error("cd: no such file or directory: " + target)]
	var node: Variant = get_node_at(parts)
	if node is String:
		return [_error("cd: not a directory: " + target)]
	if (node as Dictionary).has(LOCKED):
		return [_error("cd: permission denied: " + target)]
	cwd = parts
	return []


func _cat(args: PackedStringArray) -> Array:
	if args.size() < 2:
		return [_error("cat: missing file operand")]
	var lines: Array = []
	for target in args.slice(1):
		var parts: Variant = resolve(target)
		var node: Variant = null if parts == null else get_node_at(parts)
		if node == null:
			lines.append(_error("cat: %s: No such file or directory" % target))
		elif node is Dictionary:
			lines.append(_error("cat: %s: Is a directory" % target))
		elif (node as String).is_empty():
			lines.append(_error("cat: %s: binary file, cannot display" % target))
		else:
			for line in (node as String).split("\n"):
				lines.append(esc(line))
	return lines


func _sudo(args: PackedStringArray) -> Array:
	if " ".join(args.slice(1)) == "pacman -syu":
		var lines: Array = []
		for entry in PACMAN_LOG:
			lines.append(esc(entry) if entry is String else entry)
		lines.append("[color=%s]:: System is up to date. Simulation patched.[/color]" % COLOR_OK)
		return lines
	return [
		esc("[sudo] password for %s: ********" % USER), 0.6,
		_error("%s is not in the sudoers file. This incident will be reported." % USER),
	]


## System info next to the ship 01 logo, as one BBCode table: one cell per logo
## character (so it lines up with a proportional font), two gap cells and the info line.
## Needs table_h/v_separation = 0 on the log (set in ai_console.tscn).
func _fastfetch() -> String:
	var title: String = "[color=%s]%s[/color]@[color=%s]sim-core[/color]" % [COLOR_DIR, USER, COLOR_DIR]
	var swatches: String = ""
	for color in PALETTE:
		swatches += "[color=%s]###[/color]" % color
	# At most ~10 lines: the whole block must fit the log's height, or auto-scroll hides
	# the top of the logo
	var info: Array = [
		title,
		"-------------",
		_field("OS", "SimOS (Arch) x86_64"),
		_field("Host", "Training Simulator"),
		_field("Kernel", "4.7.1-arena"),
		_field("Uptime", "%d mins" % int(Time.get_ticks_msec() / 60000.0)),
		_field("Packages", "1337 (pacman)"),
		_field("Ship", "SHIP %02d" % (SkinManager.equipped_ship_index + 1)),
		_field("Deaths", str(GameManager.deaths_count)),
		swatches,
	]
	var width: int = (SHIP_ART[0] as String).length()
	var rows: int = maxi(SHIP_ART.size(), info.size())
	var gap: String = _art_cell(" ") + _art_cell(" ")
	var table: String = "[table=%d]" % (width + 3)
	for row in rows:
		var art_row: String = SHIP_ART[row] if row < SHIP_ART.size() else ""
		for column in width:
			table += _art_cell(art_row[column] if column < art_row.length() else " ")
		table += gap
		table += "[cell]%s[/cell]" % (info[row] if row < info.size() else "")
	return table + "[/table]"


## "Key: value" with the key coloured like fastfetch.
func _field(key: String, value: String) -> String:
	return "[color=%s]%s:[/color] %s" % [COLOR_DIR, key, esc(value)]


## One logo character; spaces are an invisible "#" so every column keeps its width.
func _art_cell(character: String) -> String:
	if character == " ":
		return "[cell][color=#00000000]#[/color][/cell]"
	var color: String = ART_COLORS.get(character, ART_OUTLINE)
	return "[cell][color=%s]%s[/color][/cell]" % [color, esc(character)]


# --- Paths --------------------------------------------------------------------

## Path parts for a path relative to cwd ("", ".", "..", "~", "/abs", "a/../b"), or null
## when it doesn't exist. Locked directories resolve (opening them is what fails).
func resolve(path: String) -> Variant:
	var parts: PackedStringArray = cwd.duplicate()
	if path.begins_with("/"):
		parts = PackedStringArray()
	elif path == "~" or path.begins_with("~/"):
		parts = PackedStringArray(HOME_PATH)
		path = path.substr(1)
	for part in path.split("/", false):
		match part:
			".":
				pass
			"..":
				if not parts.is_empty():
					parts.remove_at(parts.size() - 1)
			_:
				var node: Variant = get_node_at(parts)
				if not (node is Dictionary) or (node as Dictionary).has(LOCKED) \
						or not (node as Dictionary).has(part):
					return null
				parts.append(part)
	return parts


## The directory Dictionary or file String at those parts, or null.
func get_node_at(parts: PackedStringArray) -> Variant:
	var node: Variant = FILES
	for part in parts:
		if not (node is Dictionary) or not (node as Dictionary).has(part):
			return null
		node = node[part]
	return node


func _error(text: String) -> String:
	return "[color=%s]%s[/color]" % [COLOR_ERROR, esc(text)]


## Escapes BBCode so "[####]" or "[sudo]" print as text.
static func esc(text: String) -> String:
	return text.replace("[", "[lb]")
