shader_type canvas_item;
// Scene transition (Autoloads/scene_transition.gd): the simulation monitor loses its feed.
// `amount` 0 = the picture as it is, 1 = pure static. In between: rows tear sideways, the
// colour channels split, scanlines darken and pixel-sized static eats the picture. Runs at
// a stepped frame rate, like a low-fps feed.
// It keeps the scene's CRT screen shape: the static is curved, rounded off at the corners
// and darkened at the edges with the same warp / border / vignette as Shaders/CRT.gdshader
// (the script copies those parameters from the open scene's CRT overlay).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Static grain: cells across and down the screen (the game is 520x300).
uniform vec2 grain = vec2(260.0, 150.0);
// Colour of the static (a cold monitor glow).
uniform vec4 static_color : source_color = vec4(0.72, 0.95, 1.0, 1.0);
// Frames per second of the noise and the tearing.
uniform float feed_fps = 24.0;
// Phones and web: no colour split (one screen read instead of three).
uniform bool low_quality = false;
// The CRT overlay's screen shape (0 warp = a flat screen with no border), lighting and
// chromatic aberration, copied from it so the static looks like it's on the same monitor.
uniform float warp_amount = 0.0;
uniform float vignette_intensity = 0.4;
uniform float vignette_opacity = 0.5;
uniform float brightness = 1.0;
uniform float aberration = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Same as CRT.gdshader
vec2 warp(vec2 uv) {
	if (warp_amount < 0.06) { return uv; }
	vec2 delta = uv - 0.5;
	float delta2 = dot(delta, delta);
	return uv + delta * (delta2 * delta2 * warp_amount);
}

float border(vec2 uv) {
	if (warp_amount < 0.06) { return 1.0; }
	float radius = clamp(min(warp_amount, 0.08) * 2.0, 1e-5, 1.0);
	vec2 abs_uv = abs(uv * 2.0 - 1.0) - vec2(1.0) + radius;
	float dist = length(max(vec2(0.0), abs_uv)) / radius;
	return clamp(1.0 - smoothstep(0.96, 1.0, dist), 0.0, 1.0);
}

float vignette(vec2 uv) {
	uv *= 1.0 - uv;
	return pow(max(uv.x * uv.y * 15.0, 0.00001), vignette_intensity * vignette_opacity);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float frame = floor(TIME * feed_fps);

	// Tearing: some bands of rows slide sideways, more of them the stronger it is
	float band = floor(uv.y * 38.0);
	float torn = step(1.0 - amount * 0.7, hash(vec2(band * 1.7, frame + 3.0)));
	uv.x += (hash(vec2(band, frame)) - 0.5) * 0.16 * amount * torn;

	// The picture already went through the CRT (its split included): only the glitch's
	// extra split. The static gets the CRT's own split on top.
	float glitch_split = 0.012 * amount;
	float split = aberration * 0.1 + glitch_split;
	vec3 picture;
	if (low_quality) {
		picture = texture(screen_tex, uv).rgb;
	} else {
		picture.r = texture(screen_tex, uv + vec2(glitch_split, 0.0)).r;
		picture.g = texture(screen_tex, uv).g;
		picture.b = texture(screen_tex, uv - vec2(glitch_split, 0.0)).b;
	}

	// Pixel static on the curved screen, rolling bright rows through it; red and blue come
	// from cells shifted by the aberration, like the CRT splits the picture
	vec2 screen = warp(SCREEN_UV);
	vec2 seed = vec2(frame * 7.13, frame * 3.71);
	float noise = hash(floor(screen * grain) + seed);
	float noise_r = hash(floor((screen + vec2(split, 0.0)) * grain) + seed);
	float noise_b = hash(floor((screen - vec2(split, 0.0)) * grain) + seed);
	float roll = step(0.93, hash(vec2(floor(screen.y * grain.y * 0.25), frame * 0.5)));
	vec3 snow = static_color.rgb * mix(vec3(noise_r, noise, noise_b), vec3(1.0), roll * 0.5);
	// The CRT's lighting
	snow = clamp(snow * brightness, 0.0, 1.0);
	// The static wins slowly at first, then fast
	float cover = smoothstep(0.1, 1.0, amount);
	// Some static cells already break through the picture at low amounts
	cover = max(cover, step(1.0 - amount * 0.35, noise) * amount);
	vec3 col = mix(picture, snow, cover);

	// Scanlines
	float line = step(0.5, fract(screen.y * grain.y * 0.5));
	col *= 1.0 - 0.3 * amount * line;
	// The monitor's shape: black outside the rounded screen, darker towards its edges
	col *= border(screen) * mix(1.0, vignette(screen), cover);
	COLOR = vec4(col, 1.0);
}
