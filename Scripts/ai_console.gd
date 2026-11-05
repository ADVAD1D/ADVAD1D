extends Control
## Chat console with predefined replies only (no server, no AI): for easter eggs.
## Whatever the player types is matched against `replies` (see _normalize: case, extra
## spaces and edges don't matter); anything else gets `unknown_reply`.
## Replies are BBCode and also accept **bold**.
##
## Layout (ai_console.tscn): the credits panel frame (credits_panel.png) with the title in
## its top tab, close button top-left, the message log in the middle (it always follows
## new text) and the input row under a divider.

## Opened from the hidden button in the skin selector, so it goes back there.
var back_scene: String = "res://Scenes/skin_selector.tscn"

## Command -> reply. Keys are written in lowercase.
## ls, cd, pwd, cat and sudo are answered by the fake shell instead (SimTerminal).
@export var replies: Dictionary = {
	"hello": "Hello, pilot.",
	# Hint for the arena 2 code: base64 gives "deatharena", base58 is still missing
	"58": "ANOTHER DECODER IS STILL MISSING.",
	"who i am?": "ADNEX, special soldier in a trail simulator",
	"who i am": "ADNEX, special soldier in a trail simulator",
	"who am i?": "ADNEX, special soldier in a trail simulator",
	"who am i": "ADNEX, special soldier in a trail simulator",
	"whoami": "ADNEX, special soldier in a trail simulator",
	"rm -rf ./": "What are you trying to do???",
}
@export var unknown_reply: String = "UNKNOWN COMMAND."

## Secret code -> achievement id it unlocks. Codes are ciphers, so they must match
## exactly (case-sensitive, only the edges are trimmed).
## 6e9QhPsPapmHPv: arena 2's win code ">ZGVhdGhhcmVuYQ==" is base64 for "deatharena",
## and "deatharena" in base58 is this code (CODEBREAKER, rewards ship 07).
@export var achievement_codes: Dictionary = {
	"6e9QhPsPapmHPv": &"death_arena_code",
}
@export var code_accepted_reply: String = "ACCESS GRANTED. [wave]NEW SHIP UNLOCKED.[/wave]"
@export var code_used_reply: String = "CODE ALREADY USED."
## Name shown before each reply.
@export var reply_sender: String = "System"

# Message colours (cyan palette of the menus)
const COLOR_PLAYER: String = "#40a4f4"
const COLOR_REPLY: String = "#a2ffff"
const COLOR_SYSTEM: String = "#8db4ae"
const COLOR_TERMINAL: String = "#7fd8d8"
## Seconds per character of the typewriter effect on replies.
const TYPE_SPEED: float = 0.03
## Seconds between lines of shell output (ls, cat, the pacman log...).
const LINE_DELAY: float = 0.04

## Fake shell (filesystem, current directory) for the terminal commands.
var terminal: SimTerminal = SimTerminal.new()

@onready var close_button: TextureButton = %CloseButton
@onready var chat_display: RichTextLabel = %ChatLog
@onready var input_field: LineEdit = %InputField
@onready var send_button: Button = %SendButton
## Shows the shell's current directory ("~>", "~/missions>").
@onready var prompt_label: Label = $ChatTexture/InputRow/PromptLabel

@onready var back_sound: AudioStreamPlayer = $BackSound
@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var typing_sound: AudioStreamPlayer = $TypingSound


func _ready() -> void:
	GameManager.can_pause = false

	close_button.pressed.connect(_on_back_button_pressed)
	send_button.pressed.connect(send_message)
	input_field.text_submitted.connect(func(_text: String): send_message())
	# Hover / focus blip on every button (like the credits close button)
	for button in [close_button, send_button]:
		button.mouse_entered.connect(back_sound.play)
		button.focus_entered.connect(back_sound.play)

	input_field.context_menu_enabled = true
	# The log scrolls with the wheel; its bar stays hidden inside the frame
	chat_display.get_v_scroll_bar().modulate = Color.TRANSPARENT
	# Always follow new text, also while a reply types itself in
	chat_display.scroll_following = true
	chat_display.scroll_following_visible_characters = true
	chat_display.visible_characters = -1
	prompt_label.text = terminal.get_prompt()

	add_message("System", "Channel open. Type your message...", COLOR_SYSTEM)
	input_field.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_back_button_pressed()


func send_message() -> void:
	var text: String = input_field.text.strip_edges()
	if text.is_empty() or not input_field.editable:
		return

	input_field.clear()
	input_field.editable = false
	send_button.disabled = true

	# What the player types is shown as plain text (no BBCode)
	await add_message("You", SimTerminal.esc(text), COLOR_PLAYER)
	await _respond(text)

	input_field.editable = true
	send_button.disabled = false
	input_field.grab_focus()


## Secret codes first (exact match), then the shell commands, then the predefined replies.
func _respond(text: String) -> void:
	var code: String = text.strip_edges()
	if achievement_codes.has(code):
		await _reply(_run_code(code))
		return
	var args: PackedStringArray = _normalize(text).split(" ", false)
	if terminal.handles(args[0]):
		await _print_output(terminal.run(args))
		prompt_label.text = terminal.get_prompt()
		return
	await _reply(get_reply(text))


func _reply(message: String) -> void:
	await add_message(reply_sender, format_reply_text(message), COLOR_REPLY, true)


## Unlocks the code's achievement and returns what the console answers.
func _run_code(code: String) -> String:
	var id: StringName = StringName(achievement_codes[code])
	if AchievementManager.is_unlocked(id):
		return code_used_reply
	_log_message(["Secret code accepted:", id])
	AchievementManager.unlock(id)
	return code_accepted_reply


## Prints shell output one line at a time, without a sender. Floats in the output are
## pauses (see SimTerminal.run).
func _print_output(output: Array) -> void:
	if output.is_empty():
		return
	typing_sound.play()
	for entry in output:
		if entry is float:
			await get_tree().create_timer(entry).timeout
			continue
		chat_display.append_text("[color=%s]%s[/color]\n" % [COLOR_TERMINAL, entry])
		_scroll_to_bottom()
		await get_tree().create_timer(LINE_DELAY).timeout
	typing_sound.stop()

## Predefined reply for what the player typed, or unknown_reply.
func get_reply(text: String) -> String:
	var command: String = _normalize(text)
	for key in replies:
		if _normalize(str(key)) == command:
			return str(replies[key])
	return unknown_reply


## Lowercase, trimmed, single spaces: "  Hello   THERE " -> "hello there".
func _normalize(text: String) -> String:
	var words: PackedStringArray = text.to_lower().strip_edges().split(" ", false)
	return " ".join(words)


## **bold** -> [b]bold[/b]
func format_reply_text(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\*\\*(.*?)\\*\\*")
	return regex.sub(text, "[b]$1[/b]", true)


## Appends "Sender: message"; with animate, the message types itself in.
func add_message(sender: String, message: String, color: String, animate: bool = false) -> void:
	var chars_before: int = chat_display.get_total_character_count()
	if chat_display.visible_characters == -1:
		chat_display.visible_characters = chars_before
	chat_display.append_text("[b][color=%s]%s:[/color][/b] %s\n" % [color, sender, message])

	await get_tree().process_frame

	var chars_after: int = chat_display.get_total_character_count()
	_scroll_to_bottom()
	if animate:
		var tween: Tween = create_tween()
		tween.tween_property(chat_display, "visible_characters", chars_after,
				(chars_after - chars_before) * TYPE_SPEED).from(chars_before)
		typing_sound.play()
		await tween.finished
		typing_sound.stop()
	chat_display.visible_characters = -1
	_scroll_to_bottom()


## Jumps the log to its last line once the new text has been laid out (the next frame),
## on top of scroll_following, so long or wrapped output never stays below the view.
func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	var v_scrollbar: VScrollBar = chat_display.get_v_scroll_bar()
	v_scrollbar.value = v_scrollbar.max_value


func _on_back_button_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", back_scene)


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
