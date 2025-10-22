extends Node
## This class lets you parse your .env file into [String].
## 


## Change the file path according to the position of your .env file.[br]
## Default looks for it in the root.
var file_path: String = "./.env"

func _ready() -> void:
	check_path()

## Checks if the file_path even exists.[br]
## Will throw an [color=red]error[/color] if file does not exist.[br]
## Gets called in [method Node._ready] and in [method parse].
func check_path() -> void:
	if !FileAccess.file_exists(file_path):
		push_error("File does not exist at: ", file_path)

## Returns the value of the key from the .env file.[br]
## Throws a [color=yellow]warning[/color] if the key is empty or does not exist.
func parse(key: String) -> String:
	check_path()
	
	var file: String = FileAccess.get_file_as_string(file_path)
	var lines: PackedStringArray = []
	
	lines = file.split("\n")
	var line: String = ""
	
	for l: String in lines:
		if l.contains(key):
			line = l
	
	if line == "":
		push_warning(key, " seems to have an empty value or does not exist.")
		return line
	
	var value: String = ""
	value = line.split("=")[1]
	return value
