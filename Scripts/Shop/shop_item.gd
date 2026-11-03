class_name ShopItem
extends Resource
## One thing the shop sells. Drop a .tres of this type in res://Resources/Shop/ and the
## shop lists it (ShopManager loads the whole folder), sorted by `order`.

enum Kind {
	## Levels that make a powerup spawn more often in arcade mode.
	UPGRADE,
	## Gives a random locked ship (not one that an achievement rewards).
	MYSTERY_SHIP,
	## Unlocks one ship colour. ShopManager creates these from the colour palette;
	## no .tres needed.
	COLOR,
}

@export var id: StringName
@export var title: String = ""
## Two short lines under the icon (one line per row).
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var kind: Kind = Kind.UPGRADE
## UPGRADE: one price per level, so its size is the max level.
## MYSTERY_SHIP: only the first price is used, for every ship.
@export var prices: Array[int] = [10]
## UPGRADE: the stat it improves; matches `upgrade_stat` on the powerup spawners.
@export var upgrade_stat: StringName
## UPGRADE: extra spawn rate per level (0.1 = +10%).
@export var spawn_rate_per_level: float = 0.1
## COLOR: index in SkinManager.PALETTE.
@export var color_index: int = -1
## What the shopkeeper says after the purchase (one line per row, two rows max).
@export_multiline var purchase_line: String = ""
@export var order: int = 0


func max_level() -> int:
	return prices.size() if kind == Kind.UPGRADE else 0
