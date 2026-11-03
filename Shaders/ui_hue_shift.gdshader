shader_type canvas_item;
// Rotates the hue of a UI element (see Scripts/UI/arena_ui_tint.gd). The UI is drawn in
// cyan/blue, so rotating the hue gives each arena its colour while keeping brightness:
// 0 = original, -60 = green, 180 = red.

uniform float hue_shift_degrees = 0.0;

// Rotation around the grey axis of the RGB cube (keeps greys and brightness)
vec3 hue_rotate(vec3 color, float angle) {
	const vec3 k = vec3(0.57735026);
	float c = cos(angle);
	return color * c + cross(k, color) * sin(angle) + k * dot(k, color) * (1.0 - c);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	col.rgb = clamp(hue_rotate(col.rgb, radians(hue_shift_degrees)), 0.0, 1.0);
	COLOR = col;
}
