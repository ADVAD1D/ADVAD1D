shader_type canvas_item;
// Paints a black-and-white ship sprite with two colours, Geometry Dash style
// (see SkinManager.apply_ship_colors). The ship sprites are drawn in grey bands
// (tools/make_bw_ships.py), and the grey value of a pixel says what happens to it:
//   black (up to OUTLINE)       outline, stays black
//   mid grey (B1_LO..B1_HI)     colour 1 (body); darker grey = shadow
//   light grey (B2_LO..1.0)     colour 2 (details); darker grey = shadow
//   any non-grey pixel          keeps its own colour (eyes, faces...)
// Modulate (death red, dash flash...) still applies on top.

const float OUTLINE = 24.0 / 255.0;
const float B1_LO = 48.0 / 255.0;
const float B1_HI = 140.0 / 255.0;
const float B2_LO = 160.0 / 255.0;
const float B2_HI = 1.0;
const float SPLIT = (B1_HI + B2_LO) * 0.5;
const float MIN_SHADE = 0.6;
const float GREY_TOLERANCE = 6.0 / 255.0;

uniform vec4 color1 : source_color = vec4(0.55, 0.55, 0.55, 1.0);
uniform vec4 color2 : source_color = vec4(1.0);
uniform bool enabled = true;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 rgb = base.rgb;
	float spread = max(rgb.r, max(rgb.g, rgb.b)) - min(rgb.r, min(rgb.g, rgb.b));
	float v = rgb.r;
	if (enabled && spread <= GREY_TOLERANCE && v > OUTLINE) {
		bool body = v <= SPLIT;
		float k = body ? (v - B1_LO) / (B1_HI - B1_LO) : (v - B2_LO) / (B2_HI - B2_LO);
		float shade = MIN_SHADE + (1.0 - MIN_SHADE) * clamp(k, 0.0, 1.0);
		rgb = (body ? color1.rgb : color2.rgb) * shade;
	}
	COLOR = vec4(rgb, base.a) * COLOR;
}
