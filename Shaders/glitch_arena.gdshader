shader_type canvas_item;
// Arena 4 (arena4.tscn / tutorial_arena4.tscn): the whole room is drawn here, there is no
// background image. The sprite only gives it its size (world_origin / world_size must match
// the sprite's rect in world units). The walls drawn here follow the scene's colliders: a
// pointy-top hexagon of hex_radius around the origin, with a corridor out of its bottom
// corner (gate_half_width wide, from gate_top to corridor_end).
//
// The simulation is breaking: floor cells drop out into raw data (corruption, which
// Scripts/glitch_arena.gd raises with the phase), wall blocks flicker into their ghost colour,
// and glitch bursts (burst / burst_seed, also from the script) slide bands of the picture
// sideways and split its colours. Everything stays on this background layer, under the
// ships, so the enemies are always clear. grayscale_amount is the arenas' usual parameter
// (main.gd / PhaseManager turn the arena grey once it's won).

uniform float grayscale_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 world_origin = vec2(-2600.0, -2400.0);
uniform vec2 world_size = vec2(5200.0, 5400.0);
// World units per art pixel (the arenas' camera shows 4 world units per screen pixel)
uniform float pixel_size = 8.0;
// 1400: the same floor area as arena 3's triangle
uniform float hex_radius = 1400.0;
uniform float gate_half_width = 220.0;
uniform float gate_top = 1200.0;
uniform float corridor_end = 2500.0;
uniform float wall_width = 56.0;
// Width of the floor's hex cells
uniform float cell_size = 150.0;
uniform vec4 floor_color : source_color = vec4(0.035, 0.012, 0.06, 1.0);
uniform vec4 grid_color : source_color = vec4(0.17, 0.04, 0.24, 1.0);
uniform vec4 wall_color : source_color = vec4(1.0, 0.18, 0.82, 1.0);
uniform vec4 ghost_color : source_color = vec4(0.15, 0.95, 1.0, 1.0);
uniform vec4 void_color : source_color = vec4(0.008, 0.0, 0.016, 1.0);
uniform float corruption : hint_range(0.0, 1.0) = 0.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform float burst_seed = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Distance to a pointy-top hexagon (corners up and down) of circumradius r on the origin.
float sd_hex(vec2 p, float r) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	float apothem = r * 0.866025404;
	p = abs(p.yx);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * apothem, k.z * apothem), apothem);
	return length(p) * sign(p.y);
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// The room: the hexagon plus the corridor. Negative inside.
float sd_room(vec2 p) {
	float hex = sd_hex(p, hex_radius);
	float half_len = (corridor_end - gate_top) * 0.5;
	float corridor = sd_box(p - vec2(0.0, gate_top + half_len), vec2(gate_half_width, half_len));
	return min(hex, corridor);
}

// Pointy-top hex tiling of unit width: xy = position in the cell, zw = cell id.
vec4 hex_cell(vec2 uv) {
	const vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	return vec4(gv, uv - gv);
}

// 0 at the centre of a cell, 0.5 on its edge.
float hex_edge(vec2 gv) {
	gv = abs(gv);
	return max(dot(gv, vec2(0.5, 0.8660254)), gv.x);
}

vec3 floor_at(vec2 p, float t) {
	vec4 cell = hex_cell(p / cell_size);
	// About 2 art pixels wide (thinner lines break up on the pixel grid)
	float line = step(0.44, hex_edge(cell.xy));
	// A slow pulse running out from the centre along the grid
	float wave = smoothstep(0.88, 1.0, sin(length(p) * 0.004 - t * 1.6) * 0.5 + 0.5);
	vec3 col = mix(floor_color.rgb, grid_color.rgb * (1.0 + wave * 1.3), line);
	// Corrupted cells: the floor drops out into raw data, kept dim so the ships stay clear
	float h = hash(cell.zw + floor(t * 2.0) * 0.137);
	if (h < corruption * 0.22) {
		vec2 bits = floor(p / (pixel_size * 2.0));
		float n = hash(bits + floor(t * 12.0));
		vec3 data = mix(wall_color.rgb, ghost_color.rgb, step(0.5, hash(cell.zw)));
		col = mix(void_color.rgb, data * 0.32, step(0.8, n));
		col = mix(col, data * 0.55, line);
	}
	return col;
}

vec3 room_at(vec2 p, float t) {
	float d = sd_room(p);
	if (d < 0.0) {
		vec3 col = floor_at(p, t);
		// The wall's glow on the floor
		col += wall_color.rgb * (1.0 - smoothstep(0.0, 160.0, -d)) * 0.16;
		return col;
	}
	if (d < wall_width) {
		// Bright core line on a darker body; some blocks flicker into the ghost colour
		float core = 1.0 - smoothstep(0.0, wall_width * 0.3, abs(d - wall_width * 0.3));
		vec3 col = mix(wall_color.rgb * 0.35, wall_color.rgb, core);
		float flick = hash(floor(p / 96.0) + floor(t * 9.0) * 0.71);
		if (flick < corruption * 0.12 + burst * 0.35) {
			col = ghost_color.rgb * (0.45 + 0.55 * core);
		}
		return col;
	}
	// Outside: the void, with columns of data falling through it
	float column = floor(p.x / (pixel_size * 3.0));
	float speed = 200.0 + hash(vec2(column, 3.1)) * 500.0;
	float row = floor((p.y - t * speed) / (pixel_size * 3.0));
	float bit = step(0.93, hash(vec2(column, row)));
	float fade = 1.0 - smoothstep(wall_width, wall_width + 900.0, d);
	vec3 data = mix(wall_color.rgb, ghost_color.rgb, hash(vec2(column, 7.0)));
	vec3 col = void_color.rgb + data * bit * 0.25 * fade;
	col += wall_color.rgb * (1.0 - smoothstep(wall_width, wall_width + 120.0, d)) * 0.15;
	return col;
}

void fragment() {
	float t = TIME;
	vec2 world = world_origin + UV * world_size;
	world = (floor(world / pixel_size) + 0.5) * pixel_size;

	// Bands of the picture slide sideways: a lot during a burst, now and then with corruption
	float band = floor(world.y / 64.0);
	float shift = 0.0;
	if (hash(vec2(band, burst_seed)) < burst * 0.6) {
		shift = (hash(vec2(burst_seed, band)) - 0.5) * 360.0 * burst;
	}
	float tear_step = floor(t * 3.0);
	if (hash(vec2(band, tear_step)) < corruption * 0.03) {
		shift += (hash(vec2(band, tear_step + 9.0)) - 0.5) * 120.0;
	}
	vec2 p = world + vec2(shift, 0.0);

	vec3 col = room_at(p, t);
	// Colour split during a burst
	if (burst > 0.01) {
		float split = 24.0 * burst;
		col = vec3(room_at(p + vec2(split, 0.0), t).r, col.g, room_at(p - vec2(split, 0.0), t).b);
	}

	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(col, vec3(grey), grayscale_amount), 1.0);
}
