class_name SpanishTextures
extends Node
## Child of a TextureButton or TextureRect whose image has English text drawn in it (the
## main menu's PLAY / CREDITS / QUIT, the shop's BUY button and sign). It keeps the
## parent's own textures as the English ones and swaps in these while the game is in
## Spanish (GameManager.language), also when the language changes with the menu open.
## Empty slots keep the English texture.

@export var normal: Texture2D
@export var hover: Texture2D
@export var pressed: Texture2D
@export var focused: Texture2D
@export var disabled: Texture2D
## For a TextureRect parent.
@export var texture: Texture2D

## Parent property -> Spanish export, for the properties the parent has.
const SLOTS: Dictionary = {
	&"texture_normal": &"normal",
	&"texture_hover": &"hover",
	&"texture_pressed": &"pressed",
	&"texture_focused": &"focused",
	&"texture_disabled": &"disabled",
	&"texture": &"texture",
}

var _english: Dictionary = {}


func _ready() -> void:
	var target: Node = get_parent()
	for property: StringName in SLOTS:
		if property in target:
			_english[property] = target.get(property)
	GameManager.language_changed.connect(_apply.unbind(1))
	_apply()


func _apply() -> void:
	var target: Node = get_parent()
	var spanish: bool = GameManager.language == "es"
	for property: StringName in _english:
		var localized: Texture2D = get(SLOTS[property])
		target.set(property, localized if spanish and localized else _english[property])
