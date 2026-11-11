extends Node
## Diamonds wallet: the currency earned in arcade mode and spent in the shop.
## Everything that gives or takes diamonds goes through add_diamonds() / spend_diamonds(),
## and UI listens to diamonds_changed. Saved to its own file (not on web, like achievements).

signal diamonds_changed(total: int)

const SAVE_PATH: String = "user://wallet.json"
const AUTOSAVE_INTERVAL: float = 5.0
## Most diamonds the wallet holds: anything earned past it is lost.
const MAX_DIAMONDS: int = 1000000

var diamonds: int = 0
## Every diamond ever earned (spending doesn't lower it). Handy for stats/achievements.
var lifetime_diamonds: int = 0

var _dirty: bool = false
var _autosave_left: float = AUTOSAVE_INTERVAL


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_wallet()


func _process(delta: float) -> void:
	if _dirty:
		_autosave_left -= delta
		if _autosave_left <= 0.0:
			save_wallet()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _dirty:
			save_wallet()


func add_diamonds(amount: int) -> void:
	# Capped at MAX_DIAMONDS (a full wallet takes nothing)
	amount = mini(amount, MAX_DIAMONDS - diamonds)
	if amount <= 0:
		return
	diamonds += amount
	lifetime_diamonds += amount
	_dirty = true
	diamonds_changed.emit(diamonds)


func can_afford(cost: int) -> bool:
	return diamonds >= cost


## Takes the diamonds and returns true, or returns false and changes nothing.
func spend_diamonds(cost: int) -> bool:
	if cost < 0 or not can_afford(cost):
		return false
	diamonds -= cost
	diamonds_changed.emit(diamonds)
	save_wallet()
	return true


# --- Persistence ---------------------------------------------------------------

func save_wallet() -> void:
	_dirty = false
	_autosave_left = AUTOSAVE_INTERVAL
	# Web builds only persist the pilot name (same rule as GameManager.save_data)
	if OS.has_feature("web"):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_log_message(["Error saving wallet", FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({"diamonds": diamonds, "lifetime": lifetime_diamonds}))


func _load_wallet() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	diamonds = clampi(int(data.get("diamonds", 0)), 0, MAX_DIAMONDS)
	lifetime_diamonds = maxi(int(data.get("lifetime", diamonds)), diamonds)
	_log_message(["Wallet loaded:", diamonds, "diamonds"])


## Empties the wallet (debug).
func reset_wallet() -> void:
	diamonds = 0
	lifetime_diamonds = 0
	save_wallet()
	diamonds_changed.emit(diamonds)


func _log_message(message) -> void:
	if GameManager.is_debug_text == true:
		var final_string: String = ""
		if typeof(message) == TYPE_ARRAY:
			for arg in message:
				final_string += str(arg) + " "
			final_string = final_string.strip_edges()
		else:
			final_string = str(message)
		print_rich("[color=yellow][DEV LOG][/color] " + final_string)
