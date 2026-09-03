## Singleton that handles ship skin selection and stores the hardcoded catalog of all available ships.
## NOTE: Persistence (save/load of selected_ship_index) lives in GameManager.
extends Node

signal ship_selection_changed(new_ship_data)

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
	}
]

var selected_ship_index: int = 0

func select_next_ship():
	selected_ship_index += 1

	if selected_ship_index >= ship_data.size():
		selected_ship_index = 0

	ship_selection_changed.emit(ship_data[selected_ship_index])

func select_previous_ship():
	selected_ship_index -= 1

	if selected_ship_index < 0:
		selected_ship_index = ship_data.size() - 1

	ship_selection_changed.emit(ship_data[selected_ship_index])

func get_selected_ship_data() -> Dictionary:
	return ship_data[selected_ship_index]

func get_selected_ship_texture() -> Texture2D:
	return ship_data[selected_ship_index]["texture"]
