extends Control
## Diamond shop (its own scene, opened from the main menu). Shows CARDS_PER_PAGE items
## at a time with arrows to page through the rest. Cards are built from ShopManager.items,
## so new ShopItem .tres files in res://Resources/Shop/ show up with no changes here.
##
## Buying takes two presses on the same card: the first one makes the shopkeeper quote
## the price, the second one confirms (no accidental purchases, works the same on touch).
## The shopkeeper is a simulation NPC: same face always, only the mouth moves, and only
## while a line is being typed.

const CARDS_PER_PAGE: int = 3
const CARD_SIZE: Vector2 = Vector2(84, 124)
const CARD_X: Array[float] = [18.0, 104.0, 190.0]
const CARD_Y: float = 46.0
const TYPE_CPS: float = 40.0
const MOUTH_FRAME_TIME: float = 0.07

const LINE_WELCOME: String = "HI, HERE YOU CAN GET UPGRADES\nAND SHIP DESIGNS."
const LINE_CONFIRM: String = "%s FOR %d DIAMONDS.\nPRESS AGAIN TO CONFIRM."
const LINE_PRICE: String = "%s FOR %d DIAMONDS.\nPRESS BUY TO GET IT."
const LINE_NOT_ENOUGH: String = "YOU NEED MORE DIAMONDS.\nTHEY ARE EARNED IN ARCADE MODE."
const LINE_MAXED: String = "THIS UPGRADE IS FULLY INSTALLED."
const LINE_SOLD_OUT: String = "NO SHIP DESIGNS LEFT."
const LINE_OWNED: String = "THIS COLOR IS ALREADY\nIN YOUR PALETTE."
## Tag on the upgrade cards: upgrades only apply in arcade mode.
const ARCADE_TAG: String = "ONLY ARCADE"

const CARD_TEXTURE: Texture2D = preload("res://Assets/Sprites/Shop/shop_card.png")
const CARD_SELECTED_TEXTURE: Texture2D = preload("res://Assets/Sprites/Shop/shop_card_sel.png")
const GEM_TEXTURE: Texture2D = preload("res://Assets/Sprites/Arcade/diamond.png")
const MOUTH_TEXTURES: Dictionary = {
	"idle": preload("res://Assets/Sprites/Shop/shopkeeper_idle.png"),
	"talk1": preload("res://Assets/Sprites/Shop/shopkeeper_talk1.png"),
	"talk2": preload("res://Assets/Sprites/Shop/shopkeeper_talk2.png"),
}
const MOUTH_CYCLE: Array[String] = ["talk1", "talk2", "idle", "talk1"]

const CYAN: Color = Color("04daff")
const CYAN_LIGHT: Color = Color("a2ffff")
const CYAN_OUTLINE: Color = Color("23ffff")
const DARK_FILL: Color = Color("001c1c")
const TEXT_DIM: Color = Color("8db4ae")
const TEXT_OFF: Color = Color("528080")
const TEXT_LINE: Color = Color("d0ffff")
const PIP_OFF: Color = Color("1f2e2c")
const ORANGE: Color = Color("ffb44a")

## Where the diamonds fly from (balance gem) and to (the counter), in board pixels.
const GEM_FROM: Vector2 = Vector2(122, 18)
const GEM_TO: Vector2 = Vector2(318, 104)

var back_scene: String = "res://Scenes/main_menu.tscn"

var _page: int = 0
## Index in ShopManager.items of the highlighted card.
var _selected: int = 0
## Card waiting for the confirming press (-1 = none).
var _armed: int = -1
var _cards: Dictionary = {} # item index -> card Control (current page only)
var _line_rows: PackedStringArray = []
var _line_length: int = 0
var _typed: float = 0.0
var _time: float = 0.0
var _shown_balance: int = 0
var _balance_tween: Tween
## Touch layout: cards only select, the BUY button under them buys.
var _mobile: bool = false

@onready var board: Control = $Board
@onready var keeper: TextureRect = $Board/Keeper
@onready var player_ship: TextureRect = $Board/PlayerShip
@onready var cards_root: Control = $Board/Cards
@onready var cursor: Control = $Board/Cursor
@onready var prev_button: TextureButton = $Board/PrevButton
@onready var next_button: TextureButton = $Board/NextButton
@onready var page_label: Label = $Board/PageLabel
@onready var buy_button: TextureButton = $Board/BuyButton
@onready var dialog_box: TextureRect = $Board/DialogBox
@onready var line_labels: Array[Label] = [%Line1, %Line2]
@onready var next_line_arrow: Control = $Board/DialogBox/NextLineArrow
@onready var balance_label: Label = $Board/BalanceLabel
@onready var back_button: TextureButton = $Board/BackButton
@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var buy_sound: AudioStreamPlayer = $BuySound
@onready var error_sound: AudioStreamPlayer = $ErrorSound


func _ready() -> void:
	GameManager.can_pause = false
	_mobile = GameManager.mobile_mode_active
	buy_button.visible = _mobile
	buy_button.pressed.connect(_on_buy_pressed)
	# They show part of an already translated line while it's being typed (_say)
	for label in line_labels:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if _mobile:
		# The page counter moves to the right of the BUY button
		page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		page_label.position.x = buy_button.position.x + buy_button.size.x + 6.0
		page_label.position.y = buy_button.position.y + 2.0
		page_label.size.x = 40.0
	for button in [back_button, prev_button, next_button, buy_button]:
		# Keyboard/gamepad drive the cards; buttons must not steal ui_accept
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_entered.connect(button_sound.play)
	back_button.pressed.connect(_go_back)
	prev_button.pressed.connect(func(): _turn_page(-1))
	next_button.pressed.connect(func(): _turn_page(1))

	_build_cursor()
	_build_next_line_arrow()
	player_ship.texture = SkinManager.get_equipped_ship_texture()
	SkinManager.apply_ship_colors(player_ship, SkinManager.equipped_ship_index)
	# Own copy: the balance flashes white on purchases without touching other labels
	balance_label.label_settings = balance_label.label_settings.duplicate()
	_shown_balance = CurrencyManager.diamonds
	balance_label.text = str(_shown_balance)
	_show_page(0, true)
	_open_dialog_box()

	# Same as the achievements board: in mobile mode the background stretches with the
	# viewport and the 520px board is re-centred on top of it
	if GameManager.mobile_mode_active:
		get_tree().root.size_changed.connect(_on_window_resized)
		_on_window_resized()


func _process(delta: float) -> void:
	_time += delta
	# Player ship hovering over the floor
	player_ship.position.y = 182.0 + roundf(sin(_time * 3.2) * 2.0)
	cursor.position.y = 36.0 + float(int(_time / 0.2) % 2)

	# Typewriter; the mouth only moves while it types
	var typing: bool = _typed < _line_length
	if typing:
		_typed = minf(_typed + delta * TYPE_CPS, _line_length)
		_update_line_labels()
		keeper.texture = MOUTH_TEXTURES[MOUTH_CYCLE[int(_time / MOUTH_FRAME_TIME) % 4]]
	else:
		keeper.texture = MOUTH_TEXTURES["idle"]
	next_line_arrow.visible = not typing and _line_length > 0
	next_line_arrow.position.y = 80.0 + float(int(_time / 0.4) % 2)


func _input(event: InputEvent) -> void:
	# Mark the event handled before acting: going back changes the scene right away,
	# and after that this node has no viewport anymore.
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_go_back()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("Move_Left"):
		get_viewport().set_input_as_handled()
		_move_selection(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("Move_Right"):
		get_viewport().set_input_as_handled()
		_move_selection(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("Shoot"):
		get_viewport().set_input_as_handled()
		if _mobile:
			_on_buy_pressed()
		else:
			_activate(_selected)


func _go_back() -> void:
	get_tree().change_scene_to_file(back_scene)


func _on_window_resized() -> void:
	# The original layout is designed for 520x300 (centre = 260)
	board.position.x = get_viewport().get_visible_rect().size.x / 2.0 - 260.0


# --- Pages and selection --------------------------------------------------------------

func _page_count() -> int:
	return maxi(1, ceili(float(ShopManager.items.size()) / CARDS_PER_PAGE))


func _turn_page(direction: int) -> void:
	var page: int = clampi(_page + direction, 0, _page_count() - 1)
	if page == _page:
		return
	button_sound.play()
	_selected = page * CARDS_PER_PAGE
	_armed = -1
	_show_page(page, true)


func _move_selection(direction: int) -> void:
	var count: int = ShopManager.items.size()
	if count == 0:
		return
	var index: int = clampi(_selected + direction, 0, count - 1)
	if index == _selected:
		return
	_selected = index
	_armed = -1
	button_sound.play()
	@warning_ignore("integer_division")
	var page: int = index / CARDS_PER_PAGE
	if page != _page:
		_show_page(page, true)
	else:
		_refresh_selection()


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	_armed = -1
	button_sound.play()
	_refresh_selection()


## Rebuilds the cards of a page. `animate` makes them rise in like in the trailer.
func _show_page(page: int, animate: bool) -> void:
	_page = clampi(page, 0, _page_count() - 1)
	for child in cards_root.get_children():
		child.queue_free()
	_cards.clear()
	var first: int = _page * CARDS_PER_PAGE
	for slot in CARDS_PER_PAGE:
		var index: int = first + slot
		if index >= ShopManager.items.size():
			break
		var card: Control = _make_card(ShopManager.items[index], index)
		card.position = Vector2(CARD_X[slot], CARD_Y)
		cards_root.add_child(card)
		_cards[index] = card
		if animate:
			_rise_in(card, slot)
	if not _cards.has(_selected) and not _cards.is_empty():
		_selected = first
	_refresh_selection()
	prev_button.disabled = _page == 0
	next_button.disabled = _page >= _page_count() - 1
	page_label.text = "%d/%d" % [_page + 1, _page_count()]


func _refresh_selection() -> void:
	for index in _cards:
		var card: Control = _cards[index]
		var selected: bool = index == _selected
		(card.get_node("Bg") as TextureRect).texture = (
			CARD_SELECTED_TEXTURE if selected else CARD_TEXTURE
		)
		var head: Label = card.get_node("Head")
		head.label_settings.outline_color = CYAN_LIGHT if selected else CYAN_OUTLINE
	cursor.visible = _cards.has(_selected)
	if cursor.visible:
		cursor.position.x = _cards[_selected].position.x + 38.0
	# BUY greys out for maxed upgrades / no ships left (a short wallet still gets an answer)
	if _selected < ShopManager.items.size():
		buy_button.disabled = ShopManager.is_maxed(ShopManager.items[_selected])


func _rise_in(card: Control, slot: int) -> void:
	card.modulate.a = 0.0
	var tween: Tween = card.create_tween()
	tween.tween_interval(0.1 + slot * 0.1)
	tween.tween_callback(func(): card.modulate.a = 1.0)
	# Stepped, like the rest of the pixel UI
	var step: Callable = func(p: float):
		card.position.y = CARD_Y + (1.0 - floorf(p * 3.0) / 3.0) * 40.0
	tween.tween_method(step, 0.0, 1.0, 0.15)


# --- Cards -----------------------------------------------------------------------------

func _make_card(item: ShopItem, index: int) -> Control:
	var card: Control = Control.new()
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(_select.bind(index))
	card.gui_input.connect(_on_card_input.bind(index))

	var bg: TextureRect = _add_texture(card, CARD_TEXTURE, Vector2.ZERO, CARD_SIZE)
	bg.name = "Bg"
	var icon: TextureRect = _add_texture(card, item.icon, Vector2(17, 22), Vector2(50, 50))
	icon.name = "Icon"
	if item.kind == ShopItem.Kind.COLOR:
		# The player's ship wearing that colour as colour 1
		icon.texture = SkinManager.get_equipped_ship_texture()
		SkinManager.apply_ship_colors(icon, SkinManager.equipped_ship_index, item.color_index)
	var head: Label = _add_label(card, item.title, Vector2(0, 3), 11, DARK_FILL, CYAN_OUTLINE,
			CARD_SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	head.name = "Head"
	var rows: PackedStringArray = tr(item.description).split("\n")
	for r in mini(rows.size(), 2):
		_add_label(card, rows[r], Vector2(0, 74 + r * 7), 9, TEXT_DIM, Color.TRANSPARENT,
				CARD_SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)

	if item.kind == ShopItem.Kind.UPGRADE:
		_add_level_pips(card, item)
		_add_arcade_tag(card)
	elif item.kind == ShopItem.Kind.COLOR:
		# Swatch where the level pips go
		var swatch: Color = SkinManager.get_color(item.color_index)
		_add_rect(card, Vector2(13, 93), Vector2(58, 6), swatch)
		_add_rect(card, Vector2(13, 93), Vector2(58, 1), swatch.lightened(0.4))
	else:
		_add_label(card, "???", Vector2(0, 90), 8, TEXT_OFF, Color.TRANSPARENT, CARD_SIZE.x,
				HORIZONTAL_ALIGNMENT_CENTER)

	# Price row: gem + price, or why it can't be bought anymore
	var price: int = ShopManager.get_price(item)
	if price < 0:
		var done: String = "SOLD OUT"
		if item.kind == ShopItem.Kind.UPGRADE:
			done = "MAX"
		elif item.kind == ShopItem.Kind.COLOR:
			done = "OWNED"
		_add_label(card, done, Vector2(0, 106), 13, DARK_FILL, CYAN_LIGHT, CARD_SIZE.x,
				HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_add_texture(card, GEM_TEXTURE, Vector2(20, 108), Vector2(9, 11))
		# Dim price when the wallet can't pay it
		var outline: Color = CYAN_OUTLINE if CurrencyManager.can_afford(price) else TEXT_OFF
		_add_label(card, str(price), Vector2(32, 106), 13, DARK_FILL, outline)
	return card


func _add_level_pips(card: Control, item: ShopItem) -> void:
	var count: int = item.max_level()
	var level: int = ShopManager.get_level(item)
	var x0: float = roundf((CARD_SIZE.x - (count * 12 - 2)) / 2.0)
	for k in count:
		var pos: Vector2 = Vector2(x0 + k * 12, 94)
		var on: bool = k < level
		_add_rect(card, pos, Vector2(10, 4), CYAN if on else PIP_OFF)
		if on:
			_add_rect(card, pos, Vector2(10, 1), CYAN_LIGHT)


## Upgrades only work in arcade mode (ShopManager.get_powerup_interval), so their cards
## get an orange strip over the bottom of the icon saying so.
func _add_arcade_tag(card: Control) -> void:
	var pos: Vector2 = Vector2(17, 63)
	var tag_size: Vector2 = Vector2(50, 9)
	_add_rect(card, pos, tag_size, DARK_FILL)
	_add_rect(card, pos, Vector2(tag_size.x, 1), ORANGE)
	_add_rect(card, pos + Vector2(0, tag_size.y - 1), Vector2(tag_size.x, 1), ORANGE)
	var tag: Label = _add_label(card, ARCADE_TAG, Vector2(0, pos.y - 1), 9, ORANGE,
			Color.TRANSPARENT, CARD_SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	tag.name = "ArcadeTag"


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if _mobile:
			_select(index)
			_quote(index)
		else:
			_activate(index)


# --- Buying ---------------------------------------------------------------------------

## Desktop: press a card once to get the price quoted, again to buy it.
func _activate(index: int) -> void:
	if index < 0 or index >= ShopManager.items.size():
		return
	_select(index)
	if not _can_buy(index):
		return
	if _armed != index:
		var item: ShopItem = ShopManager.items[index]
		_armed = index
		button_sound.play()
		_say(tr(LINE_CONFIRM) % [item.title, ShopManager.get_price(item)])
		return
	_armed = -1
	_purchase(index)


## Mobile: tapping a card only selects it and the shopkeeper quotes the price.
func _quote(index: int) -> void:
	var item: ShopItem = ShopManager.items[index]
	if ShopManager.is_maxed(item):
		_say(_maxed_line(item))
	else:
		_say(tr(LINE_PRICE) % [item.title, ShopManager.get_price(item)])


## Mobile BUY button: buys the selected card in one press.
func _on_buy_pressed() -> void:
	if _can_buy(_selected):
		_purchase(_selected)


## False (with the shopkeeper's reason and a card shake) when it can't be bought now.
func _can_buy(index: int) -> bool:
	if index < 0 or index >= ShopManager.items.size():
		return false
	var item: ShopItem = ShopManager.items[index]
	if ShopManager.is_maxed(item):
		_refuse(index, _maxed_line(item))
		return false
	if not CurrencyManager.can_afford(ShopManager.get_price(item)):
		_refuse(index, LINE_NOT_ENOUGH)
		return false
	return true


func _purchase(index: int) -> void:
	var item: ShopItem = ShopManager.items[index]
	var result: Dictionary = ShopManager.buy(item)
	if result["result"] != ShopManager.Result.OK:
		_refuse(index, LINE_NOT_ENOUGH)
		return
	_on_purchased(item, index, result)


func _refuse(index: int, line: String) -> void:
	_armed = -1
	error_sound.play()
	_say(line)
	if _cards.has(index):
		var card: Control = _cards[index]
		var x: float = card.position.x
		var tween: Tween = card.create_tween()
		for offset in [-2.0, 2.0, -1.0, 0.0]:
			tween.tween_callback(func(): card.position.x = x + offset)
			tween.tween_interval(0.04)


func _on_purchased(item: ShopItem, index: int, result: Dictionary) -> void:
	buy_sound.play()
	_animate_balance(CurrencyManager.diamonds, int(result["price"]))
	_fly_gems()
	# Rebuild the page so levels, prices and affordability are up to date
	_show_page(_page, false)
	var card: Control = _cards.get(index)
	var line: String = item.purchase_line
	var floating: String = "+%d%%" % roundi(item.spawn_rate_per_level * 100.0)
	if item.kind == ShopItem.Kind.MYSTERY_SHIP:
		floating = "NEW SHIP"
		var ship_index: int = int(result["ship_index"])
		if card:
			_reveal_ship(card, ship_index)
	elif item.kind == ShopItem.Kind.COLOR:
		floating = "NEW COLOR"
	_say(line)
	if card:
		_purchase_feedback(card, floating)


## The mystery card shows the ship that came out for a moment.
func _reveal_ship(card: Control, ship_index: int) -> void:
	var icon: TextureRect = card.get_node("Icon")
	var original: Texture2D = icon.texture
	icon.texture = SkinManager.ship_data[ship_index]["texture"]
	# Shown with the player's colours, like it will look in game
	SkinManager.apply_ship_colors(icon, ship_index)
	icon.pivot_offset = icon.size / 2.0
	var tween: Tween = icon.create_tween()
	tween.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.08)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.12)
	tween.tween_interval(2.2)
	tween.tween_callback(func():
		icon.texture = original
		icon.material = null
	)


func _maxed_line(item: ShopItem) -> String:
	match item.kind:
		ShopItem.Kind.UPGRADE:
			return LINE_MAXED
		ShopItem.Kind.COLOR:
			return LINE_OWNED
	return LINE_SOLD_OUT


func _purchase_feedback(card: Control, floating: String) -> void:
	# Press, white flash and the floating label, as in the trailer
	card.position.y = CARD_Y + 2.0
	var press: Tween = card.create_tween()
	press.tween_interval(0.1)
	press.tween_callback(func(): card.position.y = CARD_Y)

	var flash: ColorRect = _add_rect(card, Vector2.ZERO, CARD_SIZE, Color(0.82, 1.0, 1.0, 0.8))
	var fade: Tween = flash.create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.12)
	fade.tween_callback(flash.queue_free)

	var label: Label = _add_label(board, floating, card.position + Vector2(0, 32), 16,
			DARK_FILL, Color.WHITE, CARD_SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	var rise: Tween = label.create_tween()
	rise.tween_property(label, "position:y", label.position.y - 26.0, 0.8)
	rise.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	rise.tween_callback(label.queue_free)


## Counts the balance down to the new value and shows "-price" under it.
func _animate_balance(target: int, price: int) -> void:
	if _balance_tween:
		_balance_tween.kill()
	var start: int = _shown_balance
	var settings: LabelSettings = balance_label.label_settings
	settings.outline_color = Color.WHITE
	_balance_tween = create_tween()
	var count: Callable = func(p: float):
		_shown_balance = roundi(lerpf(start, target, floorf(p * 10.0) / 10.0))
		balance_label.text = str(_shown_balance)
	_balance_tween.tween_method(count, 0.0, 1.0, 0.3)
	_balance_tween.tween_callback(func(): settings.outline_color = CYAN_OUTLINE)

	# Right of the balance (below it would cover the cursor of the middle card)
	var minus: Label = _add_label(board, "-" + str(price), Vector2(196, 12), 12, ORANGE)
	var drop: Tween = minus.create_tween()
	drop.tween_property(minus, "position:y", 18.0, 0.7)
	drop.parallel().tween_property(minus, "modulate:a", 0.0, 0.3).set_delay(0.4)
	drop.tween_callback(minus.queue_free)


## Diamonds jump from the balance into the counter.
func _fly_gems() -> void:
	for k in 5:
		var gem: TextureRect = _add_texture(board, GEM_TEXTURE, GEM_FROM, Vector2(9, 11))
		gem.visible = false
		var target: Vector2 = GEM_TO + Vector2(k * 26, 0)
		var arc: Callable = func(u: float):
			gem.visible = true
			gem.position = (GEM_FROM.lerp(target, u) - Vector2(0, sin(u * PI) * 18.0)).round()
		var tween: Tween = gem.create_tween()
		tween.tween_interval(k * 0.04)
		tween.tween_method(arc, 0.0, 1.0, 0.35)
		tween.tween_callback(gem.queue_free)


# --- Dialogue --------------------------------------------------------------------------

func _open_dialog_box() -> void:
	# Opens in steps, then the welcome line
	dialog_box.pivot_offset = dialog_box.size / 2.0
	dialog_box.scale.y = 0.0
	var tween: Tween = create_tween()
	tween.tween_interval(0.2)
	var step: Callable = func(p: float): dialog_box.scale.y = maxf(0.02, floorf(p * 3.0) / 3.0)
	tween.tween_method(step, 0.0, 1.0, 0.12)
	tween.tween_callback(func(): _say(LINE_WELCOME))


## Starts typing a line (two rows max, separated by \n), translated (Localization/es.po).
func _say(text: String) -> void:
	_line_rows = tr(text).split("\n")
	_line_length = 0
	for row in _line_rows:
		_line_length += row.length()
	_typed = 0.0
	_update_line_labels()


func _update_line_labels() -> void:
	var left: int = int(_typed)
	for r in line_labels.size():
		var row: String = _line_rows[r] if r < _line_rows.size() else ""
		line_labels[r].text = row.substr(0, maxi(0, left))
		left -= row.length()


# --- Node helpers ----------------------------------------------------------------------

## Down-pointing pixel arrow over the selected card.
func _build_cursor() -> void:
	_add_rect(cursor, Vector2(-1, -1), Vector2(11, 3), Color("0d1414"))
	for k in 5:
		_add_rect(cursor, Vector2(k, k), Vector2(9 - 2 * k, 1), CYAN)
	_add_rect(cursor, Vector2.ZERO, Vector2(9, 1), CYAN_LIGHT)


## Small arrow in the dialog box corner once a line is fully typed.
func _build_next_line_arrow() -> void:
	for k in 4:
		_add_rect(next_line_arrow, Vector2(k, k), Vector2(7 - 2 * k, 1), CYAN)


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


func _add_rect(parent: Control, pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.position = pos
	rect.size = rect_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## A transparent outline means no outline. width > 0 gives the label a fixed width so
## `align` can right-align or centre the text inside it.
func _add_label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color,
		outline: Color = Color.TRANSPARENT, width: float = 0.0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
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
	return label
