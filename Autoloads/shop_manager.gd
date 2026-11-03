extends Node
## Shop service. Loads every ShopItem resource in SHOP_DIR, sells them for diamonds
## (CurrencyManager) and saves what was bought to its own file (not on web).
##
## Adding an item needs no code: create a ShopItem .tres in res://Resources/Shop/.
## - UPGRADE items raise a level; powerup spawners whose `upgrade_stat` matches spawn
##   more often in arcade mode (get_powerup_interval).
## - MYSTERY_SHIP items give a random locked ship that no achievement rewards; owned
##   ships count as unlocked in SkinManager.
## Registered before GameManager: GameManager.load_data() asks SkinManager which ships
## are unlocked, and that includes the ones bought here.

signal purchased(item: ShopItem, result: Dictionary)

enum Result { OK, NOT_ENOUGH_DIAMONDS, MAXED, SOLD_OUT, OWNED }

const SHOP_DIR: String = "res://Resources/Shop/"
const SAVE_PATH: String = "user://shop.json"
## Colour cards go after the .tres items (their order is this + palette index).
const COLOR_ITEMS_ORDER: int = 100
const COLOR_PURCHASE_LINE: String = "NEW COLOR ADDED\nTO YOUR PALETTE."

## Ships kept for future achievements: the mystery ship never gives them.
## Ship numbers as in their names ("ship28" = 28), not array indexes.
## When one of them gets its Achievement (reward_ship_index = number - 1) it can stay here.
var reserved_ship_numbers: Array[int] = [4, 13, 15, 17, 27, 28, 30, 31]

## All loaded items, sorted by `order`.
var items: Array[ShopItem] = []
var _by_id: Dictionary = {} # StringName -> ShopItem
var _levels: Dictionary = {} # String id -> int
var _owned_ships: Dictionary = {} # int ship index -> true
var _owned_colors: Dictionary = {} # int palette index -> true


func _ready() -> void:
	_load_items()
	_load_progress()


func _load_items() -> void:
	items.clear()
	_by_id.clear()
	# list_directory also resolves the .remap files of exported builds
	for file in ResourceLoader.list_directory(SHOP_DIR):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res: Resource = load(SHOP_DIR + file)
		if not (res is ShopItem):
			continue
		var item: ShopItem = res
		if item.id == &"" or _by_id.has(item.id):
			push_warning("Shop item without id or duplicated: " + file)
			continue
		items.append(item)
		_by_id[item.id] = item
	_add_color_items()
	items.sort_custom(func(a: ShopItem, b: ShopItem): return a.order < b.order)


## One card per paid colour of the palette (free colours are never sold).
func _add_color_items() -> void:
	var palette: ShipColorPalette = SkinManager.PALETTE
	for index in palette.size():
		if palette.is_free(index):
			continue
		var item: ShopItem = ShopItem.new()
		item.id = StringName("color_%02d" % index)
		item.title = palette.get_color_name(index)
		item.description = "SHIP\nCOLOR"
		item.kind = ShopItem.Kind.COLOR
		item.color_index = index
		var prices: Array[int] = [palette.get_price(index)]
		item.prices = prices
		item.purchase_line = COLOR_PURCHASE_LINE
		item.order = COLOR_ITEMS_ORDER + index
		items.append(item)
		_by_id[item.id] = item


func get_item(id: StringName) -> ShopItem:
	return _by_id.get(id)


# --- Prices and state ------------------------------------------------------------

func get_level(item: ShopItem) -> int:
	return int(_levels.get(String(item.id), 0))


## True when an upgrade is at max level, there are no mystery ships left or the colour
## is already owned.
func is_maxed(item: ShopItem) -> bool:
	match item.kind:
		ShopItem.Kind.MYSTERY_SHIP:
			return get_mystery_pool().is_empty()
		ShopItem.Kind.COLOR:
			return SkinManager.PALETTE.is_free(item.color_index) or is_color_owned(item.color_index)
	return get_level(item) >= item.max_level()


## Price of the next purchase, or -1 when nothing is left to buy.
func get_price(item: ShopItem) -> int:
	if is_maxed(item) or item.prices.is_empty():
		return -1
	if item.kind != ShopItem.Kind.UPGRADE:
		return item.prices[0]
	return item.prices[get_level(item)]


## Ships a mystery purchase can give: locked by default, not rewarded by an
## achievement, not reserved for one and not bought yet.
func get_mystery_pool() -> Array[int]:
	var pool: Array[int] = []
	for index in SkinManager.ship_data.size():
		if index in SkinManager.default_unlocked_ships or _owned_ships.has(index):
			continue
		if AchievementManager.get_achievement_for_ship(index) != null:
			continue
		if is_ship_reserved(index):
			continue
		pool.append(index)
	return pool


func is_ship_owned(index: int) -> bool:
	return _owned_ships.has(index)


func is_color_owned(palette_index: int) -> bool:
	return _owned_colors.has(palette_index)


## True for ships kept for future achievements (takes the ship_data index).
func is_ship_reserved(index: int) -> bool:
	return (index + 1) in reserved_ship_numbers


# --- Buying ------------------------------------------------------------------------

## Returns {"result": Result, "ship_index": int (mystery ship only), "price": int}.
func buy(item: ShopItem) -> Dictionary:
	if is_maxed(item):
		var why: Result = Result.SOLD_OUT
		if item.kind == ShopItem.Kind.UPGRADE:
			why = Result.MAXED
		elif item.kind == ShopItem.Kind.COLOR:
			why = Result.OWNED
		return {"result": why}
	var price: int = get_price(item)
	if not CurrencyManager.spend_diamonds(price):
		return {"result": Result.NOT_ENOUGH_DIAMONDS}
	var result: Dictionary = {"result": Result.OK, "price": price}
	match item.kind:
		ShopItem.Kind.UPGRADE:
			_levels[String(item.id)] = get_level(item) + 1
		ShopItem.Kind.MYSTERY_SHIP:
			var ship_index: int = get_mystery_pool().pick_random()
			_owned_ships[ship_index] = true
			result["ship_index"] = ship_index
		ShopItem.Kind.COLOR:
			_owned_colors[item.color_index] = true
			result["color_index"] = item.color_index
	_log_message(["Shop purchase:", item.id, result])
	save_progress()
	purchased.emit(item, result)
	return result


# --- Powerup upgrades -----------------------------------------------------------------

## Spawn interval for a powerup spawner: each level of the upgrades that target its
## stat adds spawn_rate_per_level to its spawn rate. Only in arcade mode.
func get_powerup_interval(stat: StringName, base_interval: float) -> float:
	if stat == &"" or not GameManager.arcade_mode_active:
		return base_interval
	var bonus: float = 0.0
	for item in items:
		if item.kind == ShopItem.Kind.UPGRADE and item.upgrade_stat == stat:
			bonus += get_level(item) * item.spawn_rate_per_level
	return base_interval / (1.0 + bonus)


# --- Persistence ---------------------------------------------------------------------

func save_progress() -> void:
	# Web builds only persist the pilot name (same rule as GameManager.save_data)
	if OS.has_feature("web"):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_log_message(["Error saving shop", FileAccess.get_open_error()])
		return
	var data: Dictionary = {
		"levels": _levels,
		"ships": _owned_ships.keys(),
		"colors": _owned_colors.keys(),
	}
	file.store_string(JSON.stringify(data))


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var levels: Variant = data.get("levels", {})
	if typeof(levels) == TYPE_DICTIONARY:
		for key in levels:
			_levels[String(key)] = int(levels[key])
	var ships: Variant = data.get("ships", [])
	if typeof(ships) == TYPE_ARRAY:
		for index in ships:
			_owned_ships[int(index)] = true
	var colors: Variant = data.get("colors", [])
	if typeof(colors) == TYPE_ARRAY:
		for index in colors:
			_owned_colors[int(index)] = true


## Clears levels and bought ships (debug).
func reset_progress() -> void:
	_levels.clear()
	_owned_ships.clear()
	_owned_colors.clear()
	save_progress()


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
