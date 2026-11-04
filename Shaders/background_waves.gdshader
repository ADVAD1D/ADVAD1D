shader_type canvas_item;
// Subtle animated waves over the empty dark areas of an arena background, without touching
// the drawing: it goes on a copy of the background sprite (Scripts/background_waves.gd) and
// only draws where the background has `fill_color` (arena2.png: the #000c07 panels below
// the room), in that texture's own pixel grid. Everywhere else it's transparent.

// The empty colour to animate, and the two wave colours (already in arena2.png's palette)
uniform vec4 fill_color : source_color = vec4(0.0, 0.047, 0.027, 1.0);
uniform vec4 mid_color : source_color = vec4(0.0, 0.114, 0.071, 1.0);
uniform vec4 crest_color : source_color = vec4(0.008, 0.208, 0.125, 1.0);
// Only texture rows at or below this one (arena2.png: the room floor ends at 280)
uniform float min_texture_y = 280.0;
uniform float speed = 1.0;
// Wave lines per texture pixel (0.38 ~ one line every 16 px)
uniform float line_density = 0.38;
// Follows the background's grayscale (arena won, time slow), set by the script
uniform float grayscale_amount : hint_range(0.0, 1.0) = 0.0;
// Game time from the script (not TIME, which keeps running while the game is paused)
uniform float time = 0.0;

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 p = floor(UV * tex_size);
	vec3 base = texture(TEXTURE, (p + 0.5) / tex_size).rgb;
	vec4 result = vec4(0.0);

	if (p.y >= min_texture_y && distance(base, fill_color.rgb) < 0.012) {
		float t = time * speed;
		// Horizontal lines drifting down, waving along x
		float w = sin(p.y * line_density - t * 1.4 + 1.4 * sin(p.x * 0.09 + t * 0.5));
		// Broken into stretches, like light on water
		bool lit = sin(p.x * 0.07 - t * 0.35 + p.y * 0.03) > -0.35;
		if (lit && w > 0.93) {
			result = crest_color;
		} else if (lit && w > 0.78 && mod(p.x + p.y, 2.0) < 1.0) {
			result = mid_color; // dithered edge
		}
	}

	float gray = dot(result.rgb, vec3(0.299, 0.587, 0.114));
	result.rgb = mix(result.rgb, vec3(gray), grayscale_amount);
	COLOR = result;
}
