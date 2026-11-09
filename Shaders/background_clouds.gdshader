shader_type canvas_item;
// Two layers of pixel-art clouds drifting sideways over the empty dark area of an arena
// background, without touching the drawing: it goes on a copy of the background sprite
// (Scripts/background_waves.gd feeds it time and grayscale) and only draws where the
// background has its empty colour, read from `fill_texel` (a texel known to be empty),
// so the clouds stay behind the ladder, the lines and the room. Elsewhere it's transparent.
// Everything is in the texture's own pixel grid, like the drawing.

// Texel of the background that has the empty colour (gauntletdefinitivo5.png: bottom left)
uniform vec2 fill_texel = vec2(2.0, 597.0);
// Back layer (darker, slower) and front layer (brighter, faster)
uniform vec4 back_color : source_color = vec4(0.0, 0.125, 0.18, 1.0);
uniform vec4 front_color : source_color = vec4(0.0, 0.28, 0.4, 1.0);
// Texture row where each layer's top edge sits on average
uniform float back_top = 300.0;
uniform float front_top = 340.0;
// How far each top edge goes up and down (texture pixels)
uniform float back_height = 7.0;
uniform float front_height = 6.0;
// Drift speed (texture pixels per second, + = right)
uniform float back_speed = 1.5;
uniform float front_speed = 3.0;
// Width of each flat step of the outline (texture pixels)
uniform float step_width = 4.0;
// No clouds above this texture row (gauntletdefinitivo5.png: the room ends at ~270)
uniform float min_texture_y = 270.0;
// Follows the background's grayscale (arena won, time slow), set by the script
uniform float grayscale_amount : hint_range(0.0, 1.0) = 0.0;
// Game time from the script (not TIME, which keeps running while the game is paused)
uniform float time = 0.0;

// Top edge of a cloud layer at texture column x: a few sines, flattened into steps
float cloud_top(float x, float top, float height, float seed) {
	float sx = floor(x / step_width) * step_width;
	float h = sin(sx * 0.021 + seed) * 0.55
		+ sin(sx * 0.047 + seed * 2.3) * 0.3
		+ sin(sx * 0.11 + seed * 4.1) * 0.15;
	return top + floor(h * height + 0.5);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 p = floor(UV * tex_size);
	vec3 base = texture(TEXTURE, (p + 0.5) / tex_size).rgb;
	vec3 fill = texture(TEXTURE, (fill_texel + 0.5) / tex_size).rgb;
	vec4 result = vec4(0.0);

	if (p.y >= min_texture_y && distance(base, fill) < 0.012) {
		// Whole-pixel offsets, so the clouds move pixel by pixel like the drawing
		float back_x = p.x - floor(time * back_speed);
		float front_x = p.x - floor(time * front_speed);
		if (p.y >= cloud_top(front_x, front_top, front_height, 3.7)) {
			result = front_color;
		} else if (p.y >= cloud_top(back_x, back_top, back_height, 0.0)) {
			result = back_color;
		}
	}

	float gray = dot(result.rgb, vec3(0.299, 0.587, 0.114));
	result.rgb = mix(result.rgb, vec3(gray), grayscale_amount);
	COLOR = result;
}
