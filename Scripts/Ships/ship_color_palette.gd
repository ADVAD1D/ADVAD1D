class_name ShipColorPalette
extends Resource
## The colours ships can be painted with.
## SkinManager loads res://Resources/ship_color_palette.tres.
## The three arrays go together by index: colors[i] is called names[i] and costs prices[i]
## diamonds. Price 0 = unlocked from the start; the rest are sold in the shop
## (ShopManager builds one card per paid colour). The selector shows them in rows of
## `columns`, in this order. Appending a colour is safe; reordering changes saved choices.

@export var colors: Array[Color] = []
@export var names: Array[String] = []
@export var prices: Array[int] = []
## Colours a fresh save starts with (indexes into `colors`).
@export var default_color1: int = 0
@export var default_color2: int = 1
@export var columns: int = 8


func size() -> int:
	return colors.size()


func get_color_name(index: int) -> String:
	return names[index] if index >= 0 and index < names.size() else "COLOR %d" % (index + 1)


func get_price(index: int) -> int:
	return prices[index] if index >= 0 and index < prices.size() else 0


func is_free(index: int) -> bool:
	return get_price(index) <= 0
