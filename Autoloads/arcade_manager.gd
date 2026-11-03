extends Node
## Arcade mode: arena 1 with no phase limit. A run lasts until the player dies or runs
## out of time, and then starts over from phase 1.
##
## Phase length, score goal and difficulty past the last table phase are extrapolated by
## PhaseManager (see _get_phase_requirement / _get_phase_duration / apply_difficulty).
## This autoload keeps the run itself:
## - Run score: every point the arena gives (GameManager.points_added) times the multiplier.
## - Multiplier: chaining kills (each one less than combo_window apart) raises it one step
##   every kills_per_step kills, up to max_multiplier. Letting the combo run out resets it.
## - Diamonds: every points_per_diamond run points pay one diamond into CurrencyManager,
##   right away, so dying never takes back what was earned.
## The phase goal still uses the raw GameManager.score, so the multiplier never makes a
## phase shorter: it only pays more.

signal run_score_changed(run_score: int)
signal multiplier_changed(multiplier: int)
signal diamonds_earned(amount: int, run_diamonds: int)
signal run_started
signal run_ended(results: Dictionary)

const SAVE_PATH: String = "user://arcade.json"
## Arena index played in arcade mode (main.tscn).
const ARENA_INDEX: int = 0

# --- Tuning ---------------------------------------------------------------------
## Seconds a kill keeps the combo alive.
var combo_window: float = 2.5
## Chained kills needed for each multiplier step.
var kills_per_step: int = 5
var max_multiplier: int = 8
## Clearing phase N pays N * phase_clear_bonus base points (times the multiplier).
var phase_clear_bonus: int = 250
## Run points that pay one diamond.
var points_per_diamond: int = 1000

# --- Current run ------------------------------------------------------------------
var run_score: int = 0
var multiplier: int = 1
var chain: int = 0
var combo_time_left: float = 0.0
var current_phase: int = 0
var run_diamonds: int = 0

# --- Records ----------------------------------------------------------------------
var best_score: int = 0
var best_phase: int = 0

## Results of the run that just ended. The HUD shows them once after the reload.
var last_results: Dictionary = {}

var _run_active: bool = false
## The run summary only shows after the first death of each arcade session.
var _summary_shown: bool = false


func _ready() -> void:
	GameManager.points_added.connect(_on_points_added)
	_load_records()


func _process(delta: float) -> void:
	# Pausable: the combo doesn't run out while the game is paused.
	if not _run_active or chain == 0:
		return
	combo_time_left -= delta
	if combo_time_left <= 0.0:
		_break_combo()


# --- Run lifecycle ------------------------------------------------------------------

## Called by the main menu's arcade button, right before loading the arena.
func start_run() -> void:
	GameManager.reset_game_state()
	GameManager.arcade_mode_active = true
	last_results = {}
	_summary_shown = false
	_begin_run()


## Called by PhaseManager when a phase begins. The first phase after a death starts a new run.
func on_phase_started(phase: int) -> void:
	if not _run_active:
		_begin_run()
	current_phase = phase


## Called by PhaseManager when the phase goal is reached.
func on_phase_cleared(phase: int) -> void:
	if not _run_active:
		return
	_add_run_points(phase * phase_clear_bonus * multiplier)


## Called on death or when the phase timer runs out. Saves the records, keeps the
## results for the HUD and makes the next load start from phase 1.
func end_run() -> void:
	GameManager.phase_to_start = 1
	if not _run_active:
		return
	_run_active = false
	var new_best: bool = run_score > best_score
	best_score = maxi(best_score, run_score)
	best_phase = maxi(best_phase, current_phase)
	last_results = {
		"score": run_score,
		"phase": current_phase,
		"diamonds": run_diamonds,
		"best_score": best_score,
		"new_best": new_best,
	}
	_log_message(["Arcade run over:", last_results])
	save_records()
	CurrencyManager.save_wallet()
	_break_combo()
	run_ended.emit(last_results)


## Called when the main menu opens: closes a run that was left from the pause menu.
func leave_arcade() -> void:
	if GameManager.arcade_mode_active:
		end_run()
	last_results = {}
	GameManager.arcade_mode_active = false


## Returns the results of the last run for the HUD summary. Only the first death of an
## arcade session gets one; after that it returns empty (nothing to show).
func take_last_results() -> Dictionary:
	var results: Dictionary = last_results
	last_results = {}
	if results.is_empty() or _summary_shown:
		return {}
	_summary_shown = true
	return results


func is_run_active() -> bool:
	return _run_active


## 0..1, how much of the combo window is left (for the HUD bar).
func get_combo_ratio() -> float:
	if chain == 0 or combo_window <= 0.0:
		return 0.0
	return clampf(combo_time_left / combo_window, 0.0, 1.0)


func _begin_run() -> void:
	run_score = 0
	run_diamonds = 0
	current_phase = 0
	chain = 0
	combo_time_left = 0.0
	multiplier = 1
	_run_active = true
	run_score_changed.emit(run_score)
	multiplier_changed.emit(multiplier)
	run_started.emit()


# --- Points, multiplier and diamonds -------------------------------------------------

func _on_points_added(points: int) -> void:
	if not GameManager.arcade_mode_active or not _run_active or not GameManager.can_add_score:
		return
	chain += 1
	combo_time_left = combo_window
	var new_multiplier: int = clampi(1 + floori(float(chain) / kills_per_step), 1, max_multiplier)
	if new_multiplier != multiplier:
		multiplier = new_multiplier
		multiplier_changed.emit(multiplier)
	_add_run_points(points * multiplier)


func _add_run_points(points: int) -> void:
	if points <= 0:
		return
	run_score += points
	run_score_changed.emit(run_score)
	var earned_total: int = floori(float(run_score) / points_per_diamond)
	if earned_total > run_diamonds:
		var gained: int = earned_total - run_diamonds
		run_diamonds = earned_total
		CurrencyManager.add_diamonds(gained)
		diamonds_earned.emit(gained, run_diamonds)


func _break_combo() -> void:
	chain = 0
	combo_time_left = 0.0
	if multiplier != 1:
		multiplier = 1
		multiplier_changed.emit(multiplier)


# --- Persistence ---------------------------------------------------------------------

func save_records() -> void:
	# Web builds only persist the pilot name (same rule as GameManager.save_data)
	if OS.has_feature("web"):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_log_message(["Error saving arcade records", FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({"best_score": best_score, "best_phase": best_phase}))


func _load_records() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	best_score = maxi(int(data.get("best_score", 0)), 0)
	best_phase = maxi(int(data.get("best_phase", 0)), 0)


## Clears the records (debug).
func reset_records() -> void:
	best_score = 0
	best_phase = 0
	save_records()


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
