class_name Achievement
extends Resource
## One achievement, defined as data. To add a new achievement:
##   1. In the FileSystem dock, right click res://Resources/Achievements/
##      > New Resource > Achievement.
##   2. Fill the fields below in the Inspector and save it as a .tres in that folder.
##   3. From gameplay code, feed its stat: AchievementManager.add_stat(&"my_stat")
##      or AchievementManager.submit_best_time(&"my_stat", seconds).
## AchievementManager loads every resource in that folder automatically.

## How the stat is compared against `goal`.
enum GoalType {
	AT_LEAST, ## Counters: unlocked when the stat reaches `goal` (e.g. destroy 5 saws).
	AT_MOST, ## Best times: unlocked when a recorded value is <= `goal` (e.g. under 8:00).
	MANUAL, ## No stat: unlocked only with AchievementManager.unlock(id) (e.g. secrets).
}

## How the progress text is shown in the achievements panel.
enum ProgressFormat {
	COUNT, ## "3/5"
	TIME, ## "07:42.18 / 08:00"
	NONE, ## No progress text
}

## Unique key, also used in the save file. Never rename it once released.
@export var id: StringName
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## Stat key this achievement watches (ignored for MANUAL).
@export var stat: StringName
@export var goal_type: GoalType = GoalType.AT_LEAST
## Target value: a count for AT_LEAST, seconds for AT_MOST.
@export var goal: float = 1.0
@export var progress_format: ProgressFormat = ProgressFormat.COUNT
## Index in SkinManager.ship_data unlocked by this achievement (-1 = no ship reward).
## Ships are locked by default; this is one of the ways to unlock them.
@export var reward_ship_index: int = -1
## Hidden achievements (secrets) are not listed until they are unlocked.
@export var hidden: bool = false
## Position in the achievements panel (lower first).
@export var order: int = 0


## True when `value` satisfies the goal. `has_value` is false when the stat was never recorded.
func is_met(value: float, has_value: bool) -> bool:
	match goal_type:
		GoalType.AT_LEAST:
			return value >= goal
		GoalType.AT_MOST:
			return has_value and value <= goal
	return false


## Progress between 0 and 1 for the panel's bar.
func progress_ratio(value: float, has_value: bool) -> float:
	match goal_type:
		GoalType.AT_LEAST:
			return clampf(value / maxf(goal, 0.0001), 0.0, 1.0)
		GoalType.AT_MOST:
			if not has_value:
				return 0.0
			return clampf(goal / maxf(value, 0.0001), 0.0, 1.0)
	return 0.0


func progress_text(value: float, has_value: bool) -> String:
	match progress_format:
		ProgressFormat.COUNT:
			return "%d/%d" % [mini(int(value), int(goal)), int(goal)]
		ProgressFormat.TIME:
			var best: String = format_time(value) if has_value else "--:--.--"
			return "%s / %s" % [best, format_time(goal, false)]
	return ""


## Ship this achievement unlocks as "SHIP 03", or "" when there's no ship reward.
func reward_text() -> String:
	if reward_ship_index < 0 or reward_ship_index >= SkinManager.ship_data.size():
		return ""
	return tr("SHIP %02d") % (reward_ship_index + 1)


static func format_time(seconds: float, with_cents: bool = true) -> String:
	var total: int = int(seconds)
	@warning_ignore("integer_division")
	var minutes: int = total / 60
	var secs: int = total % 60
	if not with_cents:
		return "%02d:%02d" % [minutes, secs]
	var cents: int = int((seconds - total) * 100.0)
	return "%02d:%02d.%02d" % [minutes, secs, cents]
