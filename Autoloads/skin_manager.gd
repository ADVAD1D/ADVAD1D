## Singleton that handles ship skin selection and stores the hardcoded catalog of all available ships.
## NOTE: Persistence (save/load of selected_ship_index) lives in GameManager.
extends Node

signal ship_selection_changed(new_ship_data)
## Colour 1 or 2 changed (see set_ship_color).
signal ship_colors_changed

## Ship colours, Geometry Dash style: the ship sprites are drawn in black and white
## (tools/make_bw_ships.py; originals in tools/ship_originals/) and SHIP_COLOR_SHADER
## paints them by grey value: black = outline, mid grey = colour 1 (body), light grey =
## colour 2 (details), darker grey = shadow; non-grey pixels keep their own colour.
## Colours are global (the same pair for every ship), picked from PALETTE and saved by
## GameManager.
const PALETTE: ShipColorPalette = preload("res://Resources/ship_color_palette.tres")
const SHIP_COLOR_SHADER: Shader = preload("res://Shaders/ship_color.gdshader")

## Array of dictionaries defining all available ship skins.
## Each dictionary contains "name" (String), "author" (String), and "texture" (Texture2D).
## The index in this array corresponds to the ship's ID used in save files.
var ship_data = [
	{
		"name": "ship1",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ship1.png")
	},

	{
		"name": "ship2",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship2.png")
	},

	{
		"name": "ship3",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship3.png")
	},

	{
		"name": "ship4",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship4.png")
	},

	{
		"name": "ship5",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship5.png")
	},

	{
		"name": "ship6",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship6.png")
	},

	{
		"name": "ship7",
		"author": "Tector9",
		"texture": preload("res://Assets/Sprites/Ships/ship7.png")
	},

	{
		"name": "ship8",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship8.png")
	},

	{
		"name": "ship9",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship9.png")
	},

	{
		"name": "ship10",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship10.png")
	},

	{
		"name": "ship11",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship11.png")
	},

	{
		"name": "ship12",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship12.png")
	},

	{
		"name": "ship13",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship13.png")
	},

	{
		"name": "ship14",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship14.png")
	},

	{
		"name": "ship15",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship15.png")
	},

	{
		"name": "ship16",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship16.png")
	},

	{
		"name": "ship17",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship17.png")
	},

	{
		"name": "ship18",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship18.png")
	},

	{
		"name": "ship19",
		"author": "Cro128",
		"texture": preload("res://Assets/Sprites/Ships/ship19.png")
	},

	{
		"name": "ship20",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship20.png")
	},

	{
		"name": "ship21",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship21.png")
	},

	{
		"name": "ship22",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship22.png")
	},

	{
		"name": "ship23",
		"author": "Odruu",
		"texture": preload("res://Assets/Sprites/Ships/ship23.png")
	},

	{
		"name": "ship24",
		"author": "Johnny224",
		"texture": preload("res://Assets/Sprites/Ships/ship24.png")
	},

	{
		"name": "ship25",
		"author": "Alva Majo",
		"texture": preload("res://Assets/Sprites/Ships/ship25.png")
	},

	{
		"name": "ship26",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship26.png")
	},

	{
		"name": "ship27",
		"author": "Tipito",
		"texture": preload("res://Assets/Sprites/Ships/ship27.png")
	},

	{
		"name": "ship28",
		"author": "Ringa Tech",
		"texture": preload("res://Assets/Sprites/Ships/ship28.png")
	},

	{
		"name": "ship29",
		"author": "Oliverandom",
		"texture": preload("res://Assets/Sprites/Ships/ship29.png")
	},

	{
		"name": "ship30",
		"author": "Sealex",
		"texture": preload("res://Assets/Sprites/Ships/ship30.png")
	},

	{
		"name": "ship31",
		"author": "ItsRodrigo",
		"texture": preload("res://Assets/Sprites/Ships/ship31.png")
	},

	{
		"name": "ship32",
		"author": "Kodomo",
		"texture": preload("res://Assets/Sprites/Ships/ship32.png")
	},

	{
		"name": "ship33",
		"author": "RobloxIris",
		"texture": preload("res://Assets/Sprites/Ships/ship33.png")
	},
	
	{
		"name": "ship34",
		"author": "Golty1p",
		"texture": preload("res://Assets/Sprites/Ships/ship34.png")
	},
	{
		"name": "ship35",
		"author": "TheJuan118GD",
		"texture": preload("res://Assets/Sprites/Ships/ship35.png")
	}
]

## Ship shown in the skin selector (it can be a locked one while browsing).
var selected_ship_index: int = 0
## Ship the player actually flies with and the one saved. Only unlocked ships get here.
var equipped_ship_index: int = 0

# --- Ship locks -------------------------------------------------------------
# Every ship is locked by default. A ship is unlocked when it's listed below, when the
# achievement that rewards it is unlocked (Achievement.reward_ship_index), when it was
# bought in the shop (ShopManager mystery ship), or when unlock_all_ships is on.

## Debug/dev switch: unlocks every ship at once.
var unlock_all_ships: bool = false
## Indexes in ship_data available from the start.
var default_unlocked_ships: Array[int] = [0]

# --- Ship colours -------------------------------------------------------------

## Debug/dev switch: unlocks every colour at once.
var unlock_all_colors: bool = false
## Palette indexes of the two colours (layer 1 = body, layer 2 = details).
var color1_index: int = PALETTE.default_color1
var color2_index: int = PALETTE.default_color2

func select_next_ship():
	selected_ship_index += 1

	if selected_ship_index >= ship_data.size():
		selected_ship_index = 0

	_equip_if_unlocked()
	ship_selection_changed.emit(ship_data[selected_ship_index])

func select_previous_ship():
	selected_ship_index -= 1

	if selected_ship_index < 0:
		selected_ship_index = ship_data.size() - 1

	_equip_if_unlocked()
	ship_selection_changed.emit(ship_data[selected_ship_index])

func is_ship_unlocked(index: int) -> bool:
	if unlock_all_ships or index in default_unlocked_ships:
		return true
	return AchievementManager.is_ship_reward_unlocked(index) or ShopManager.is_ship_owned(index)

func is_ship_locked(index: int) -> bool:
	return not is_ship_unlocked(index)

func _equip_if_unlocked() -> void:
	if not is_ship_locked(selected_ship_index):
		equipped_ship_index = selected_ship_index

## Called when leaving the skin selector, so a locked ship that was only being viewed
## doesn't stay selected.
func restore_equipped_ship() -> void:
	selected_ship_index = equipped_ship_index

## Sets the ship loaded from the save file, falling back to a default ship if it's locked.
func load_equipped_ship(index: int) -> void:
	if index < 0 or index >= ship_data.size() or is_ship_locked(index):
		index = default_unlocked_ships[0] if not default_unlocked_ships.is_empty() else 0
	equipped_ship_index = index
	selected_ship_index = index

func get_selected_ship_data() -> Dictionary:
	return ship_data[selected_ship_index]

## Texture of the equipped ship (the one used in gameplay).
func get_equipped_ship_texture() -> Texture2D:
	return ship_data[equipped_ship_index]["texture"]

# --- Ship colours -------------------------------------------------------------

func get_color(palette_index: int) -> Color:
	return PALETTE.colors[clampi(palette_index, 0, PALETTE.size() - 1)]

func is_color_unlocked(palette_index: int) -> bool:
	if palette_index < 0 or palette_index >= PALETTE.size():
		return false
	return unlock_all_colors or PALETTE.is_free(palette_index) \
		or ShopManager.is_color_owned(palette_index)

## Palette index of colour `layer` (1 or 2).
func get_ship_color_index(layer: int) -> int:
	return color1_index if layer == 1 else color2_index

## Sets colour `layer` (1 or 2). Returns false (and changes nothing) for locked colours.
func set_ship_color(layer: int, palette_index: int) -> bool:
	if not is_color_unlocked(palette_index):
		return false
	if layer == 1:
		color1_index = palette_index
	else:
		color2_index = palette_index
	ship_colors_changed.emit()
	return true

## Sets the colours loaded from the save file, falling back to the defaults if locked.
func load_ship_colors(saved_color1: int, saved_color2: int) -> void:
	color1_index = saved_color1 if is_color_unlocked(saved_color1) else PALETTE.default_color1
	color2_index = saved_color2 if is_color_unlocked(saved_color2) else PALETTE.default_color2

## Paints a Sprite2D/TextureRect that shows a ship with two palette colours
## (-1 = the player's colours). Reuses the node's ShaderMaterial when it already has one.
## The ship index isn't needed today (every sprite is black and white); it's kept so
## callers don't change if a ship ever needs its own settings.
func apply_ship_colors(item: CanvasItem, _ship_index: int, palette1: int = -1,
		palette2: int = -1) -> void:
	var mat: ShaderMaterial = item.material as ShaderMaterial
	if mat == null or mat.shader != SHIP_COLOR_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = SHIP_COLOR_SHADER
		item.material = mat
	mat.set_shader_parameter("color1", get_color(color1_index if palette1 < 0 else palette1))
	mat.set_shader_parameter("color2", get_color(color2_index if palette2 < 0 else palette2))
