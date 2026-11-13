extends AnimatedSprite2D

## Spritesheet of each arena's portals (arena index -> texture); arenas without an entry
## (arena 1) keep the original cyan one, PortalAnimation.png.
const ARENA_SHEETS: Dictionary = {
	1: preload("res://Assets/Sprites/PortalAnimation_green.png"),
	2: preload("res://Assets/Sprites/PortalAnimation_red.png"),
}

## The original cyan sheet, read once from the frames.
static var _original_sheet: Texture2D


func _ready() -> void:
	_apply_arena_sheet()
	scale = Vector2.ZERO
	play()
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(5, 5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.1)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	tween.finished.connect(queue_free)


## Points the frames (AtlasTextures shared by every portal) at the current arena's sheet.
func _apply_arena_sheet() -> void:
	var frame_count: int = sprite_frames.get_frame_count(animation)
	var first: AtlasTexture = sprite_frames.get_frame_texture(animation, 0) as AtlasTexture
	if first == null:
		return
	if _original_sheet == null:
		_original_sheet = first.atlas
	var sheet: Texture2D = ARENA_SHEETS.get(GameManager.current_arena_index, _original_sheet)
	if first.atlas == sheet:
		return
	for i in frame_count:
		var frame: AtlasTexture = sprite_frames.get_frame_texture(animation, i) as AtlasTexture
		if frame:
			frame.atlas = sheet
