extends Node
## Central font access. Preloads the game's pixel font and builds ready-made
## LabelSettings so scripts don't recreate them from scratch.

const PIXEL_FONT: FontFile = preload("res://Assets/Fonts/Kenney Pixel.ttf")

#global font, can use in future cases

##import with color: my_label.label_settings = FontManager.pixel_label_settings(20)
##import without color: my_label.add_theme_font_override("font", FontManager.PIXEL_FONT)

# Pixel style matching the FPS label: teal fill, cyan outline, shadow.
func pixel_label_settings(size: int = 15) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font = PIXEL_FONT
	settings.font_size = size
	settings.font_color = Color(0, 0.14569733, 0.14569727, 1)
	settings.outline_size = 2
	settings.outline_color = Color(0, 1, 1, 1)
	settings.shadow_size = 3
	settings.shadow_color = Color(0, 0.31618276, 0.32560238, 1)
	return settings
