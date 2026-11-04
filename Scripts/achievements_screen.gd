extends Control
## Achievements board (its own scene, opened from the main menu). One row per achievement,
## built from AchievementManager, so new achievements show up with no changes here.
## Row layout follows the 448x50 row sprites in Assets/Sprites/Achievements/.

const ROW_SIZE: Vector2 = Vector2(448, 50)
const ROW_TEXTURES: Dictionary = {
	"pending": preload("res://Assets/Sprites/Achievements/ach_row_pending.png"),
	"done": preload("res://Assets/Sprites/Achievements/ach_row_done.png"),
	"secret": preload("res://Assets/Sprites/Achievements/ach_row_secret.png"),
	"locked": preload("res://Assets/Sprites/Achievements/ach_row_locked.png"),
}
const LOCK_TEXTURE: Texture2D = preload("res://Assets/Sprites/Achievements/icon_lock.png")

const CYAN: Color = Color("04daff")
const CYAN_LIGHT: Color = Color("a2ffff")
const CYAN_OUTLINE: Color = Color(0.13725491, 1, 1)
const MAGENTA: Color = Color("ff2fb0")
const MAGENTA_LIGHT: Color = Color("ffd0ee")
const DARK_FILL: Color = Color(0, 0.11372549, 0.11372549)
const TEXT_DIM: Color = Color("8db4ae")
const TEXT_OFF: Color = Color("35494b")
const TEXT_OFF_FILL: Color = Color("0d1414")
const TEXT_REWARD: Color = Color("528080")

var back_scene: String = "res://Scenes/main_menu.tscn"

@onready var board: Control = $Board
@onready var list: VBoxContainer = %List
@onready var counter_label: Label = %CounterLabel
@onready var back_button: TextureButton = $Board/BackButton
@onready var button_sound: AudioStreamPlayer = $ButtonSound


func _ready() -> void:
	GameManager.can_pause = false
	back_button.pressed.connect(_go_back)
	back_button.mouse_entered.connect(button_sound.play)
	_build()
	# Same as the skin selector: in mobile mode the background stretches with the
	# viewport (anchored full rect) and the 520px board is re-centred on top of it
	if GameManager.mobile_mode_active:
		get_tree().root.size_changed.connect(_on_window_resized)
		_on_window_resized()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file(back_scene)


func _on_window_resized() -> void:
	# The original layout is designed for 520x300 (centre = 260)
	board.position.x = get_viewport().get_visible_rect().size.x / 2.0 - 260.0


func _build() -> void:
	var achievements: Array[Achievement] = AchievementManager.achievements
	var unlocked: int = 0
	for i in achievements.size():
		var achievement: Achievement = achievements[i]
		if AchievementManager.is_unlocked(achievement.id):
			unlocked += 1
		list.add_child(_make_row(achievement, i))
	counter_label.text = "%02d/%02d" % [unlocked, achievements.size()]


## pending / done / secret (hidden and unlocked) / locked (hidden, not found yet)
func _row_state(achievement: Achievement) -> String:
	var done: bool = AchievementManager.is_unlocked(achievement.id)
	if achievement.hidden:
		return "secret" if done else "locked"
	return "done" if done else "pending"


func _make_row(achievement: Achievement, index: int) -> Control:
	var state: String = _row_state(achievement)
	var revealed: bool = state != "locked"
	var secret: bool = state == "secret"
	var accent: Color = MAGENTA if secret else CYAN
	var accent_light: Color = MAGENTA_LIGHT if secret else CYAN_LIGHT

	var row: Control = Control.new()
	row.custom_minimum_size = ROW_SIZE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Content lives in a child so it can slide in without fighting the VBox layout
	var slide: Control = Control.new()
	slide.size = ROW_SIZE
	slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slide)

	_add_texture(slide, ROW_TEXTURES[state], Vector2.ZERO, ROW_SIZE)
	var icon: Texture2D = achievement.icon if revealed else LOCK_TEXTURE
	_add_texture(slide, icon, Vector2(4, 4), Vector2(42, 42))

	# Title and description
	var title: String = achievement.title if revealed else "???"
	var title_outline: Color = MAGENTA if secret else (CYAN_OUTLINE if revealed else TEXT_OFF)
	var title_fill: Color = DARK_FILL if revealed else TEXT_OFF_FILL
	_add_label(slide, title, Vector2(56, 5), 16, title_fill, title_outline)
	var desc: String = achievement.description if revealed else "KEEP PLAYING TO REVEAL"
	_add_label(slide, desc, Vector2(56, 21), 12, TEXT_DIM if revealed else TEXT_OFF)

	# Progress bar inside the row sprite's track (x 57..287, y 37). The bar is always drawn
	# (full once unlocked, also for MANUAL achievements with no stat); the text only when
	# the achievement has a progress format.
	if revealed:
		var width: float = roundf(230.0 * AchievementManager.progress_ratio(achievement))
		if width > 0.0:
			_add_rect(slide, Vector2(57, 37), Vector2(width, 4), accent)
			_add_rect(slide, Vector2(57, 37), Vector2(width, 1), accent_light)
		if achievement.progress_format != Achievement.ProgressFormat.NONE:
			var progress: String = AchievementManager.progress_text(achievement)
			_add_label(slide, progress, Vector2(292, 33), 12, accent_light)

	# Reward column and slot (x 398..444)
	var reward: String = achievement.reward_text()
	var done: bool = state == "done" or secret
	var right: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not revealed:
		_add_label(slide, "???", Vector2(398, 15), 18, TEXT_OFF_FILL, TEXT_OFF, 46,
				HORIZONTAL_ALIGNMENT_CENTER)
	elif reward != "":
		var status: String = "UNLOCKED" if done else "REWARD"
		var status_color: Color = accent_light if done else TEXT_REWARD
		_add_label(slide, status, Vector2(300, 9), 12, status_color, Color.TRANSPARENT, 92, right)
		var name_outline: Color = accent if done else TEXT_REWARD
		_add_label(slide, reward, Vector2(300, 22), 16, DARK_FILL, name_outline, 92, right)
		var ship_index: int = achievement.reward_ship_index
		var ship: Texture2D = SkinManager.ship_data[ship_index]["texture"]
		var slot: TextureRect = _add_texture(slide, ship if done else LOCK_TEXTURE,
				Vector2(398, 4), Vector2(46, 42))
		if done:
			# Ships are black and white sprites: show them with the player's colours
			SkinManager.apply_ship_colors(slot, ship_index)

	_slide_in(slide, index)
	return row


func _slide_in(slide: Control, index: int) -> void:
	slide.modulate.a = 0.0
	slide.position.x = 80.0
	var tween: Tween = create_tween()
	tween.tween_interval(0.08 + index * 0.08)
	tween.tween_callback(func(): slide.modulate.a = 1.0)
	# Stepped slide, like the rest of the pixel UI
	var step: Callable = func(p: float): slide.position.x = (1.0 - floorf(p * 3.0) / 3.0) * 80.0
	tween.tween_method(step, 0.0, 1.0, 0.18)


func _add_texture(parent: Control, texture: Texture2D, pos: Vector2, box: Vector2) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.position = pos
	rect.size = box
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _add_rect(parent: Control, pos: Vector2, rect_size: Vector2, color: Color) -> void:
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.position = pos
	rect.size = rect_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)


## A transparent outline means no outline. width > 0 gives the label a fixed width so
## `align` can right-align or centre the text inside it.
func _add_label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color,
		outline: Color = Color.TRANSPARENT, width: float = 0.0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var settings: LabelSettings = LabelSettings.new()
	settings.font = FontManager.PIXEL_FONT
	settings.font_size = font_size
	settings.font_color = color
	if outline.a > 0.0:
		settings.outline_size = 2
		settings.outline_color = outline
	var label: Label = Label.new()
	label.text = text
	label.label_settings = settings
	label.position = pos
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		label.size = Vector2(width, font_size)
	label.horizontal_alignment = align
	parent.add_child(label)
