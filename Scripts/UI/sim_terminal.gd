class_name SimTerminal
extends RefCounted
## Fake shell behind the chat console (ai_console.gd): the training simulation's
## computer, logged in as ADNEX. A tiny read-only filesystem with ls, cd, pwd, cat, a
## fake `sudo pacman -Syu` and `sudo simflow train`: the simulator's AI (a TensorFlow-like
## log, lore of the cinematics) training on the soldier, with the save's real stats.
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
			".sim_history": "./simulate --arena 01\n./simulate --arena 01\n./simulate --arena 01 --retry\n./simulate --arena 01 --retry\n./simulate --arena 02\nvim orders.txt\nhow do i exit vim\nls /usr/games",
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
		"ai": {
			"readme": "SIMFLOW 2.6.1\nBehavioral learning framework of the simulator.\nEvery soldier's run trains the next trial.\nusage: sudo simflow train",
		},
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
	# Minigames (TerminalGames, terminal_games.gd): empty files, run by name or path
	"usr": {
		"bin": {
			"vim": "",
		},
		"games": {
			"readme": "Games for bored operators.\nRun one by name: wat, bin, hack, bughunt.\nquit or exit leaves. vim has no README.\nReal-time: invasion, dash, boom. Esc leaves.\nboom runs on everything. Even here.",
			"bin": "",
			"boom": "",
			"bughunt": "",
			"dash": "",
			"hack": "",
			"invasion": "",
			"wat": "",
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
const COLOR_WARN: String = "#ffd36b"

## Debug options run with sudo (_debug_command).
const DEBUG_COMMANDS: Array = ["hitbox_disable", "hitbox_enable", "debug_enable", "debug_disable"]

## SimFlow (sudo simflow train): the simulator's AI, training on the soldier.
const SIMFLOW_VERSION: String = "2.6.1"
const SIMFLOW_EPOCHS: int = 5
## Inputs of the fake model's first layer (for the params count).
const SIMFLOW_INPUTS: int = 12
## Layers of the fake model: name, type, units.
const SIMFLOW_LAYERS: Array = [
	["reaction_time", "Dense", 64],
	["dodge_patterns", "LSTM", 128],
	["aim_bias", "Conv1D", 32],
	["aggression", "Dense", 16],
	["next_trial", "Softmax", 3],
]
## Arenas in the subject profile (arena_<n>_clears, n = 1..ARENA_COUNT).
const ARENA_COUNT: int = 4

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
	return command_name in ["ls", "cd", "pwd", "cat", "sudo", "fastfetch", "neofetch", "simflow"]


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
		"simflow":
			return [_error("simflow: access to the subject's data requires root. Try sudo.")]
	return []


## Linux-style prompt with a short path: "adnex@sim:~$", "adnex@sim:~/missions$",
## "adnex@sim:/sim/arenas$".
func get_prompt() -> String:
	var path: String = "/" + "/".join(cwd)
	var home: String = "/" + "/".join(PackedStringArray(HOME_PATH))
	if path.begins_with(home):
		path = "~" + path.substr(home.length())
	return "%s@sim:%s$" % [USER, path]


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
	if args.size() > 1 and args[1] == "simflow":
		return _simflow(args.slice(1))
	if args.size() == 2 and args[1] in DEBUG_COMMANDS:
		return [esc("[sudo] password for %s: ********" % USER), 0.4, _debug_command(args[1])]
	return [
		esc("[sudo] password for %s: ********" % USER), 0.6,
		_error("%s is not in the sudoers file. This incident will be reported." % USER),
	]


## sudo hitbox_disable / hitbox_enable: the player's Hitbox collider off or back to normal
## (GameManager.debug_hitbox_disabled, read by player.gd). sudo debug_enable / debug_disable:
## the debug menu's master switch (GameManager.show_debug_menu, Tab in game) on, or back to
## what it was before. Session only.
func _debug_command(command: String) -> String:
	match command:
		"hitbox_disable":
			if GameManager.debug_hitbox_disabled:
				return esc("Player hitbox already disabled.")
			GameManager.debug_hitbox_disabled = true
			return _ok("[OK] Player hitbox disabled. Nothing can touch you.")
		"hitbox_enable":
			if not GameManager.debug_hitbox_disabled:
				return esc("Player hitbox already enabled.")
			GameManager.debug_hitbox_disabled = false
			return _ok("[OK] Player hitbox restored.")
		"debug_enable":
			if GameManager.show_debug_menu:
				return esc("Debug menu already enabled. Press Tab in game.")
			GameManager.show_debug_menu_before_console = GameManager.show_debug_menu
			GameManager.show_debug_menu = true
			return _ok("[OK] Debug menu enabled. Press Tab in game.")
		"debug_disable":
			if GameManager.show_debug_menu_before_console == null:
				return esc("Debug menu was not enabled from this console.")
			GameManager.show_debug_menu = GameManager.show_debug_menu_before_console
			GameManager.show_debug_menu_before_console = null
			return _ok("[OK] Debug menu restored.")
	return ""


# --- SimFlow ------------------------------------------------------------------

## sudo simflow train: loads the soldier's data (the save's real stats), trains the
## simulator's model on it epoch by epoch and prints the subject profile it learned. The
## accuracy grows with the player's progress (ships, arenas, achievements, GEMELA).
func _simflow(args: PackedStringArray) -> Array:
	var lines: Array = [esc("[sudo] password for %s: ********" % USER), 0.6]
	if args.size() < 2 or args[1] != "train":
		lines.append_array([
			"[color=%s]SimFlow %s[/color] - behavioral learning framework"
					% [COLOR_DIR, SIMFLOW_VERSION],
			esc("usage: sudo simflow train"),
		])
		return lines
	var stats: Dictionary = _subject_stats()
	var pilot: String = GameManager.player_name.strip_edges().to_upper()
	if pilot.is_empty():
		pilot = "ADNEX"
	var samples: int = stats.deaths + stats.saws + stats.guns + stats.clears + stats.gemela

	lines.append_array([
		"[color=%s]SimFlow %s[/color] (device: sim-core TPU x4)" % [COLOR_DIR, SIMFLOW_VERSION],
		esc("Loading subject: " + pilot), 0.4,
		esc("Collecting behavior dataset..."), 0.6,
		_ok("%d samples (deaths, kills, clears)" % samples), 0.3,
		esc("Building model \"commander_ai_v7\"..."), 0.4,
	])
	var layer_rows: Array = [[_key("Layer"), _key("Type"), _key("Units")]]
	var params: int = 0
	var inputs: int = SIMFLOW_INPUTS
	for layer in SIMFLOW_LAYERS:
		layer_rows.append([esc(layer[0]), esc(layer[1]), str(layer[2])])
		params += inputs * int(layer[2]) + int(layer[2])
		inputs = int(layer[2])
	lines.append(_table(layer_rows))
	lines.append_array([esc("Total params: %s" % _thousands(params)), 0.5, ""])

	# Same save, same numbers: the noise is seeded by the stats
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(stats)
	var final_accuracy: float = lerpf(0.42, 0.97, _subject_progress(stats))
	var steps: int = maxi(1, ceili(samples / 32.0))
	for epoch in SIMFLOW_EPOCHS:
		var t: float = float(epoch + 1) / SIMFLOW_EPOCHS
		var accuracy: float = final_accuracy
		if epoch < SIMFLOW_EPOCHS - 1:
			accuracy = lerpf(0.18, final_accuracy, 1.0 - pow(1.0 - t, 2.0)) \
					+ rng.randf_range(-0.015, 0.015)
		var loss: float = (1.0 - accuracy) * 1.8 + rng.randf_range(0.0, 0.03)
		lines.append_array([
			esc("Epoch %d/%d" % [epoch + 1, SIMFLOW_EPOCHS]), 0.5,
			esc("%d/%d [==========] loss: %.4f - acc: %.4f" % [steps, steps, loss, accuracy]),
		])

	lines.append_array([0.4, "", "[color=%s]SUBJECT PROFILE[/color]" % COLOR_DIR])
	lines.append(_table([
		[_key("Deaths"), str(stats.deaths)],
		[_key("Ships unlocked"), "%d/%d" % [stats.ships, stats.ships_total]],
		[_key("Arenas cleared"),
				"%d/%d (%d clears)" % [stats.arenas, ARENA_COUNT, stats.clears]],
		[_key("Achievements"), "%d/%d" % [stats.achievements, stats.achievements_total]],
		[_key("GEMELA defeated"), str(stats.gemela)],
		[_key("Saws destroyed"), str(stats.saws)],
		[_key("Laser guns destroyed"), str(stats.guns)],
	]))
	lines.append("")
	if stats.gemela > 0:
		lines.append(_warn("GEMELA beaten %d time(s). Retraining GEMELA on this subject."
				% stats.gemela))
	else:
		lines.append(esc("GEMELA undefeated. Boss weights unchanged."))
	if stats.deaths >= 100:
		lines.append(_warn("Subject dies often and keeps coming back. Persistence: HIGH."))
	elif stats.deaths > 0:
		lines.append(esc("Subject learns from every death."))
	else:
		lines.append(esc("No deaths recorded. Subject not tested yet."))
	lines.append_array([
		0.5,
		_ok("[OK] Weights saved to /sim/core.bin"), 0.3,
		_ok("[OK] Future trials adapted for the next soldier."),
	])
	return lines


## The save's real numbers for the subject profile.
func _subject_stats() -> Dictionary:
	var ships: int = 0
	for index in SkinManager.ship_data.size():
		if SkinManager.is_ship_unlocked(index):
			ships += 1
	var arenas: int = 0
	var clears: int = 0
	for arena in range(1, ARENA_COUNT + 1):
		var stat: StringName = StringName("arena_%d_clears" % arena)
		var arena_clears: int = int(AchievementManager.get_stat(stat))
		clears += arena_clears
		if arena_clears > 0:
			arenas += 1
	return {
		"deaths": GameManager.deaths_count,
		"ships": ships,
		"ships_total": SkinManager.ship_data.size(),
		"arenas": arenas,
		"clears": clears,
		"achievements": AchievementManager.get_unlocked_count(),
		"achievements_total": AchievementManager.achievements.size(),
		"gemela": int(AchievementManager.get_stat(&"gemela_kills")),
		"saws": int(AchievementManager.get_stat(&"saws_destroyed")),
		"guns": int(AchievementManager.get_stat(&"laser_guns_destroyed")),
	}


## 0 to 1: average of ships, arenas and achievements unlocked, and GEMELA beaten once.
func _subject_progress(stats: Dictionary) -> float:
	var progress: float = float(stats.ships) / maxi(stats.ships_total, 1) \
			+ float(stats.arenas) / ARENA_COUNT \
			+ float(stats.achievements) / maxi(stats.achievements_total, 1) \
			+ (1.0 if stats.gemela > 0 else 0.0)
	return clampf(progress / 4.0, 0.0, 1.0)


## Rows of cells (already BBCode) as one table, so columns line up with the proportional
## font; an invisible "##" after each cell but the last keeps the columns apart.
func _table(rows: Array) -> String:
	var columns: int = (rows[0] as Array).size()
	var table: String = "[table=%d]" % columns
	for row in rows:
		for column in columns:
			var pad: String = "[color=#00000000]##[/color]" if column < columns - 1 else ""
			table += "[cell]%s%s[/cell]" % [row[column], pad]
	return table + "[/table]"


## 98816 -> "98,816"
func _thousands(value: int) -> String:
	var digits: String = str(value)
	var out: String = ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out


func _ok(text: String) -> String:
	return "[color=%s]%s[/color]" % [COLOR_OK, esc(text)]


func _warn(text: String) -> String:
	return "[color=%s]%s[/color]" % [COLOR_WARN, esc(text)]


func _key(text: String) -> String:
	return "[color=%s]%s[/color]" % [COLOR_DIR, esc(text)]


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
