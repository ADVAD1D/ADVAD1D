extends RefCounted
## Minigames hidden in the chat console's fake shell (SimTerminal), for players who know
## their way around code. They sit in /usr/games (vim in /usr/bin) and start by name or
## by path ("/usr/games/hack", "./hack" from that folder):
## - vim: get out of vim (it only takes vim's own ways out: :q, :wq, ZZ...).
## - wat: guess what a snippet prints (JavaScript, Python, C, GDScript, bash).
## - bin: base conversion speedrun (binary, hex, decimal) against the clock.
## - hack: crack a 4 digit hex key with Wordle-style hints.
## - bughunt: find the buggy line in a snippet.
##
## While a game runs the console sends every input line here (raw text, case kept)
## instead of the shell; quit, exit or :q leaves any game but vim. Output works like
## SimTerminal.run(): BBCode lines and float pauses.

const GAMES: PackedStringArray = ["bin", "bughunt", "hack", "vim", "wat"]
## Real-time games (Scripts/UI/Games/): found here too, but run by the console itself.
const ARCADE_GAMES: PackedStringArray = ["boom", "dash", "invasion"]
## Typed in any game except vim to leave it.
const QUIT_WORDS: PackedStringArray = ["quit", "exit", ":q", ":q!"]

const COLOR_TITLE: String = "#ffd36b"
const COLOR_CODE: String = "#e8ffff"
const COLOR_DIM: String = "#5f8f8f"
const COLOR_NEAR: String = "#ffd36b"

const WAT_ROUNDS: int = 5
const BUG_ROUNDS: int = 3
const BIN_ROUNDS: int = 6
const HACK_LENGTH: int = 4
const HACK_TRIES: int = 8
const HEX_DIGITS: String = "0123456789abcdef"

## vim's ways out (case-sensitive, like vim).
const VIM_EXITS: PackedStringArray = [
	":q", ":q!", ":qa", ":qa!", ":wq", ":wq!", ":wqa", ":x", ":x!", ":xa",
	":quit", ":quit!", ":exit", "ZZ", "ZQ",
]
## Typed in insert mode to go back to normal mode (the Esc key closes the console).
const VIM_ESCAPES: PackedStringArray = [
	"esc", "<esc>", "^[", "ctrl+[", "ctrl+c", "^c", "<c-[>", "<c-c>",
]
## Keys that enter insert mode.
const VIM_INSERT_KEYS: PackedStringArray = ["i", "a", "o", "I", "A", "O"]
const VIM_SPLASH: Array = [
	"~",
	"~          VIM - Vi IMproved",
	"~           version 9.1.0",
	"~     by Bram Moolenaar et al.",
	"~",
]

## Guess the output: language, snippet, accepted answers (compared in lowercase without
## spaces or quotes, see _clean) and why.
const WAT_QUESTIONS: Array = [
	{"lang": "JavaScript", "code": ["typeof NaN"], "answers": ["number"],
		"why": "Not a Number is a number."},
	{"lang": "JavaScript", "code": ["0.1 + 0.2 === 0.3"], "answers": ["false"],
		"why": "0.1 + 0.2 is 0.30000000000000004."},
	{"lang": "JavaScript", "code": ["[] + {}"], "answers": ["[object Object]"],
		"why": "Both become strings: '' + '[object Object]'."},
	{"lang": "JavaScript", "code": ["('b' + 'a' + +'a' + 'a').toLowerCase()"],
		"answers": ["banana"], "why": "+'a' is NaN."},
	{"lang": "JavaScript", "code": ["[1, 2, 10].sort()"], "answers": ["[1, 10, 2]", "1,10,2"],
		"why": "sort() compares them as strings."},
	{"lang": "JavaScript", "code": ["'5' - 3"], "answers": ["2"],
		"why": "Minus turns '5' into a number. Plus would give '53'."},
	{"lang": "JavaScript", "code": ["Math.max()"], "answers": ["-Infinity"],
		"why": "The max of nothing starts at -Infinity."},
	{"lang": "JavaScript", "code": ["null >= 0"], "answers": ["true"],
		"why": ">= turns null into 0. But null == 0 is false."},
	{"lang": "Python", "code": ["print(0.1 + 0.2)"], "answers": ["0.30000000000000004"],
		"why": "Floating point. Everywhere."},
	{"lang": "Python", "code": ["print(round(2.5))"], "answers": ["2"],
		"why": "Banker's rounding: ties go to the even number."},
	{"lang": "Python", "code": ["print(bool('False'))"], "answers": ["True"],
		"why": "Any non-empty string is True."},
	{"lang": "C", "code": ["printf(\"%d\", 7 / 2);"], "answers": ["3"],
		"why": "int / int drops the decimals."},
	{"lang": "C", "code": ["printf(\"%zu\", sizeof(char));"], "answers": ["1"],
		"why": "sizeof(char) is 1 by definition."},
	{"lang": "GDScript", "code": ["print(5 / 2)"], "answers": ["2"],
		"why": "int / int is integer division (and a warning)."},
	{"lang": "bash", "code": ["echo $((2**10))"], "answers": ["1024"],
		"why": "Bash arithmetic has ** too."},
]

## Find the bug: language, code lines, the line numbers that count as the bug, and why.
const BUGS: Array = [
	{"lang": "C", "lines": [3], "code": [
		"int sum(int *a, int n) {",
		"  int s = 0;",
		"  for (int i = 0; i <= n; i++)",
		"    s += a[i];",
		"  return s;",
		"}",
	], "why": "i <= n reads one past the end. Use i < n."},
	{"lang": "C", "lines": [3], "code": [
		"void hit(Player *p) {",
		"  p->lives--;",
		"  if (p->lives = 0)",
		"    game_over();",
		"}",
	], "why": "= assigns 0, so the check is always false. Use ==."},
	{"lang": "C", "lines": [3, 4], "code": [
		"switch (powerup) {",
		"  case SHIELD:",
		"    give_shield();",
		"  case SAW:",
		"    give_saw();",
		"    break;",
		"}",
	], "why": "No break after give_shield(): a shield also gives a saw."},
	{"lang": "C", "lines": [1, 2], "code": [
		"char name[5];",
		"strcpy(name, \"ADNEX\");",
		"printf(\"%s\", name);",
	], "why": "ADNEX needs 6 bytes: 5 letters plus the '\\0'."},
	{"lang": "Python", "lines": [1], "code": [
		"def spawn(enemy, wave=[]):",
		"    wave.append(enemy)",
		"    return wave",
	], "why": "The default list is made once and shared by every call."},
	{"lang": "Python", "lines": [1, 3], "code": [
		"for enemy in enemies:",
		"    if enemy.dead:",
		"        enemies.remove(enemy)",
	], "why": "Removing while iterating skips the next one. Loop over enemies[:]."},
	{"lang": "JavaScript", "lines": [1], "code": [
		"for (var i = 0; i < 3; i++) {",
		"  setTimeout(() => log(i), 0);",
		"}",
		"// prints 3 3 3",
	], "why": "var is function-scoped. let gives each loop its own i."},
	{"lang": "JavaScript", "lines": [2], "code": [
		"async function save() {",
		"  const res = fetch('/save');",
		"  return res.ok;",
		"}",
	], "why": "Missing await: res is a Promise, so res.ok is undefined."},
	{"lang": "GDScript", "lines": [2], "code": [
		"func _physics_process(delta):",
		"    velocity = velocity.lerp(target, 0.1)",
		"    move_and_slide()",
	], "why": "A fixed lerp factor depends on the frame rate. Use 1.0 - pow(0.9, delta * 60.0)."},
]

## Running game (a name in GAMES), "" when none.
var _game: String = ""
var _round: int = 0
var _score: int = 0
## Questions picked for this run (wat, bughunt).
var _queue: Array = []
## bin: the value asked for and the base the answer must be written in.
var _bin_value: int = 0
var _bin_base: int = 10
var _started_msec: int = 0
## hack: the key and the guesses used.
var _secret: String = ""
var _tries: int = 0
## vim: open file name, insert mode, inputs typed and failed commands.
var _vim_file: String = ""
var _vim_insert: bool = false
var _vim_inputs: int = 0
var _vim_fails: int = 0
var _vim_typed_quits: int = 0


func is_active() -> bool:
	return not _game.is_empty()


## The game this command starts (a name in GAMES or a path to one in /usr/games or
## /usr/bin), or "".
func find_game(command_name: String, terminal: SimTerminal) -> String:
	if command_name in GAMES or command_name in ARCADE_GAMES:
		return command_name
	if command_name.contains("/"):
		var parts: Variant = terminal.resolve(command_name)
		if parts is PackedStringArray and (parts as PackedStringArray).size() == 3 \
				and parts[0] == "usr" and parts[1] in ["games", "bin"] \
				and (parts[2] in GAMES or parts[2] in ARCADE_GAMES):
			return String(parts[2])
	return ""


func start(game: String, args: PackedStringArray) -> Array:
	_game = game
	_round = 0
	_score = 0
	match game:
		"vim":
			return _vim_start(args)
		"wat":
			return _wat_start()
		"bin":
			return _bin_start()
		"hack":
			return _hack_start()
	return _bug_start()


## One line typed while a game runs.
func input(text: String) -> Array:
	text = text.strip_edges()
	if _game != "vim" and text.to_lower() in QUIT_WORDS:
		var lines: Array = [_dim("%s: aborted." % _game)]
		_game = ""
		return lines
	match _game:
		"vim":
			return _vim_input(text)
		"wat":
			return _wat_input(text)
		"bin":
			return _bin_input(text)
		"hack":
			return _hack_input(text)
	return _bug_input(text)


## What the input prompt shows during the game.
func get_prompt() -> String:
	match _game:
		"vim":
			return "-- INSERT --" if _vim_insert else "~"
		"bughunt":
			return "line>"
		"hack":
			return "key>"
	return _game + ">"


# --- vim ----------------------------------------------------------------------

func _vim_start(args: PackedStringArray) -> Array:
	_vim_file = args[1] if args.size() > 1 else ""
	_vim_insert = false
	_vim_inputs = 0
	_vim_fails = 0
	_vim_typed_quits = 0
	var lines: Array = []
	for row in VIM_SPLASH:
		lines.append(_dim(row))
	if _vim_file.is_empty():
		lines.append(_dim("[No Name]"))
	else:
		lines.append(_dim("\"%s\" [readonly]" % _vim_file))
	return lines


func _vim_input(text: String) -> Array:
	_vim_inputs += 1
	var lines: Array = []
	if _vim_insert:
		# Insert mode: everything is text, even ":q"
		if text.to_lower() in VIM_ESCAPES:
			_vim_insert = false
		else:
			lines.append(_code(text))
			if text.begins_with(":"):
				_vim_typed_quits += 1
				if _vim_typed_quits == 2:
					lines.append(_dim("(that went into the file: insert mode. <Esc> leaves it)"))
	elif text in VIM_EXITS:
		_game = ""
		if _vim_inputs == 1:
			lines.append(_ok("Clean exit on the first try. A true vim user."))
		else:
			lines.append(_ok("You escaped vim in %d tries." % _vim_inputs))
	elif text in VIM_INSERT_KEYS:
		_vim_insert = true
	elif text == ":w":
		if _vim_file.is_empty():
			lines.append(_error("E32: No file name"))
		else:
			lines.append(_error("\"%s\" E45: 'readonly' option is set (add ! to override)" % _vim_file))
	else:
		_vim_fails += 1
		if text.begins_with(":"):
			lines.append(_error("E492: Not an editor command: " + text.substr(1)))
		else:
			lines.append(_dim("*beep*"))
		if _vim_fails % 3 == 0:
			lines.append(_dim("Type  :qa!  and press <Enter> to abandon all changes and exit Vim"))
	return lines


# --- wat ----------------------------------------------------------------------

func _wat_start() -> Array:
	_queue = _pick(WAT_QUESTIONS, WAT_ROUNDS)
	var lines: Array = [_title("WAT: what does it print?"), _dim("Type the output. quit leaves.")]
	lines.append_array(_wat_question())
	return lines


func _wat_question() -> Array:
	var question: Dictionary = _queue[_round]
	var lines: Array = ["", _dim("[%d/%d] %s" % [_round + 1, _queue.size(), question["lang"]])]
	for line in question["code"]:
		lines.append(_code("> " + line))
	return lines


func _wat_input(text: String) -> Array:
	var question: Dictionary = _queue[_round]
	var answers: Array = question["answers"]
	var correct: bool = false
	for answer in answers:
		correct = correct or _clean(answer) == _clean(text)
	var lines: Array = []
	if correct:
		_score += 1
		lines.append(_ok("Correct. " + question["why"]))
	else:
		lines.append(_error("Nope: %s. %s" % [answers[0], question["why"]]))
	_round += 1
	if _round < _queue.size():
		lines.append(0.4)
		lines.append_array(_wat_question())
	else:
		lines.append_array(_results(_score, _queue.size()))
	return lines


# --- bin ----------------------------------------------------------------------

func _bin_start() -> Array:
	_started_msec = Time.get_ticks_msec()
	var lines: Array = [
		_title("BIN: base conversion speedrun"),
		_dim("%d rounds against the clock. 0b / 0x prefixes optional." % BIN_ROUNDS),
	]
	lines.append_array(_bin_question())
	return lines


func _bin_question() -> Array:
	var question: String = ""
	match randi() % 4:
		0:
			_bin_value = randi_range(1, 255)
			_bin_base = 10
			question = "0b%s -> dec" % _to_bin(_bin_value, 8)
		1:
			_bin_value = randi_range(16, 255)
			_bin_base = 10
			question = "0x%X -> dec" % _bin_value
		2:
			_bin_value = randi_range(1, 63)
			_bin_base = 2
			question = "%d -> bin" % _bin_value
		_:
			_bin_value = randi_range(16, 255)
			_bin_base = 16
			question = "%d -> hex" % _bin_value
	return ["", _dim("[%d/%d] " % [_round + 1, BIN_ROUNDS]) + _code(question)]


func _bin_input(text: String) -> Array:
	var value: int = _parse_number(text, _bin_base)
	if value < 0:
		return [_error("That isn't a base %d number." % _bin_base)]
	var lines: Array = []
	if value == _bin_value:
		_score += 1
		lines.append(_ok("Correct."))
	else:
		lines.append(_error("Nope: " + _format_number(_bin_value, _bin_base)))
	_round += 1
	if _round < BIN_ROUNDS:
		lines.append_array(_bin_question())
		return lines
	var seconds: float = (Time.get_ticks_msec() - _started_msec) / 1000.0
	_game = ""
	lines.append("")
	lines.append(_title("SCORE %d/%d in %.1fs" % [_score, BIN_ROUNDS, seconds]))
	if _score == BIN_ROUNDS:
		lines.append(_dim("Human compiler." if seconds < 30.0 else "Correct, but the build is slow."))
	else:
		lines.append(_dim(_rating(_score, BIN_ROUNDS)))
	return lines


## The number written in that base, or -1 when it isn't a valid one.
func _parse_number(text: String, base: int) -> int:
	var digits: String = text.to_lower().replace(" ", "").replace("_", "")
	var prefix: String = {2: "0b", 16: "0x"}.get(base, "")
	if not prefix.is_empty() and digits.begins_with(prefix):
		digits = digits.substr(2)
	var valid: bool = not digits.is_empty() and digits.length() <= 16
	if base == 2:
		for character in digits:
			valid = valid and character in ["0", "1"]
	elif base == 16:
		valid = valid and digits.is_valid_hex_number()
	else:
		valid = valid and digits.is_valid_int()
	if not valid:
		return -1
	match base:
		2:
			return digits.bin_to_int()
		16:
			return digits.hex_to_int()
	return digits.to_int()


func _format_number(value: int, base: int) -> String:
	if base == 2:
		return "0b" + _to_bin(value, 0)
	if base == 16:
		return "0x%X" % value
	return str(value)


static func _to_bin(value: int, width: int) -> String:
	var bits: String = ""
	while value > 0:
		bits = str(value & 1) + bits
		value >>= 1
	if bits.is_empty():
		bits = "0"
	return bits.lpad(width, "0")


# --- hack ---------------------------------------------------------------------

func _hack_start() -> Array:
	var digits: Array = []
	for character in HEX_DIGITS:
		digits.append(character)
	digits.shuffle()
	_secret = "".join(PackedStringArray(digits.slice(0, HACK_LENGTH)))
	_tries = 0
	return [
		_dim("ssh root@sim-core -p 22"), 0.4,
		_title("FIREWALL: %d hex digits, no repeats. %d tries." % [HACK_LENGTH, HACK_TRIES]),
		"[color=%s]green[/color] = right spot, [color=%s]yellow[/color] = wrong spot."
				% [SimTerminal.COLOR_OK, COLOR_NEAR],
	]


func _hack_input(text: String) -> Array:
	var guess: String = text.to_lower().replace(" ", "")
	if guess.begins_with("0x"):
		guess = guess.substr(2)
	if guess.length() != HACK_LENGTH or not guess.is_valid_hex_number():
		return [_error("Key format: %d hex digits (0-9, a-f)." % HACK_LENGTH)]
	_tries += 1

	# Wordle marks: 2 = right spot, 1 = in the key elsewhere, 0 = not in the key
	var marks: Array = []
	var left: Dictionary = {}
	for i in HACK_LENGTH:
		marks.append(2 if guess[i] == _secret[i] else 0)
		if marks[i] == 0:
			left[_secret[i]] = int(left.get(_secret[i], 0)) + 1
	for i in HACK_LENGTH:
		if marks[i] == 0 and int(left.get(guess[i], 0)) > 0:
			marks[i] = 1
			left[guess[i]] -= 1
	var colors: Array = [COLOR_DIM, COLOR_NEAR, SimTerminal.COLOR_OK]
	var shown: String = ""
	for i in HACK_LENGTH:
		shown += "[color=%s]%s[/color] " % [colors[marks[i]], guess[i].to_upper()]

	var lines: Array = [_dim("[%d/%d]  " % [_tries, HACK_TRIES]) + shown]
	if guess == _secret:
		_game = ""
		lines.append_array([
			0.3, _ok("ACCESS GRANTED. Key 0x%s, cracked in %d tries." % [_secret.to_upper(), _tries]),
			0.4, _code("root@sim-core:~# "), 0.8, _error("Connection reset by peer."),
		])
	elif _tries >= HACK_TRIES:
		_game = ""
		lines.append_array([
			_error("INTRUSION DETECTED. The key was 0x%s." % _secret.to_upper()),
			_dim("Your IP has been logged. (It's 127.0.0.1.)"),
		])
	return lines


# --- bughunt ------------------------------------------------------------------

func _bug_start() -> Array:
	_queue = _pick(BUGS, BUG_ROUNDS)
	var lines: Array = [_title("BUGHUNT: type the line with the bug"), _dim("quit leaves.")]
	lines.append_array(_bug_question())
	return lines


func _bug_question() -> Array:
	var bug: Dictionary = _queue[_round]
	var code: Array = bug["code"]
	var lines: Array = ["", _dim("[%d/%d] %s" % [_round + 1, _queue.size(), bug["lang"]])]
	for i in code.size():
		lines.append(_dim("%d  " % (i + 1)) + _code(code[i]))
	return lines


func _bug_input(text: String) -> Array:
	if not text.is_valid_int():
		return [_error("Type the line number.")]
	var bug: Dictionary = _queue[_round]
	var bug_lines: Array = bug["lines"]
	var lines: Array = []
	if text.to_int() in bug_lines:
		_score += 1
		lines.append(_ok("Squashed. " + bug["why"]))
	else:
		lines.append(_error("Nope, line %d. %s" % [bug_lines[0], bug["why"]]))
	_round += 1
	if _round < _queue.size():
		lines.append(0.4)
		lines.append_array(_bug_question())
	else:
		lines.append_array(_results(_score, _queue.size()))
	return lines


# --- Helpers ------------------------------------------------------------------

## Ends the game and prints the score.
func _results(score: int, total: int) -> Array:
	_game = ""
	return ["", _title("SCORE %d/%d" % [score, total]), _dim(_rating(score, total))]


static func _rating(score: int, total: int) -> String:
	if score == total:
		return "Senior engineer. Ship it."
	if score * 5 >= total * 3:
		return "Works on my machine."
	if score > 0:
		return "Junior dev. Read the docs."
	return "Have you tried turning it off and on again?"


## A few random entries of the pool.
static func _pick(pool: Array, count: int) -> Array:
	var copy: Array = pool.duplicate()
	copy.shuffle()
	return copy.slice(0, mini(count, copy.size()))


## Answer as compared: lowercase, no spaces, no quotes.
static func _clean(text: String) -> String:
	return text.to_lower().replace(" ", "").replace("\"", "").replace("'", "")


static func _paint(color: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color, SimTerminal.esc(text)]


static func _title(text: String) -> String:
	return _paint(COLOR_TITLE, text)


static func _code(text: String) -> String:
	return _paint(COLOR_CODE, text)


static func _dim(text: String) -> String:
	return _paint(COLOR_DIM, text)


static func _ok(text: String) -> String:
	return _paint(SimTerminal.COLOR_OK, text)


static func _error(text: String) -> String:
	return _paint(SimTerminal.COLOR_ERROR, text)
