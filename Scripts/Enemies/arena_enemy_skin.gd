class_name ArenaEnemySkin
extends RefCounted
## Dresses the enemies in their arena's colour (GameManager.arena_enemy_colors): arena 1
## blue, arena 2 green. Arenas with no entry (arena 3) keep the original red art.
##
## Sprites: each red enemy texture has hand-drawn versions next to it, "<name>_blue.png"
## and "<name>_green.png" (ship_enemy, saw1, enemy_laser, ship_enemy_particles,
## sawparticle), which replace it. Particle colour ramps and lights (red gradients in the
## scenes) get their red channel swapped into the arena's channel (recolor()), so they keep
## exactly the red ones' look. Only looks change, never logic.
## Called by ship_enemy.gd and saw.gd in _ready, by enemy_laser.gd on every activate()
## (pooled lasers move between arenas, so it also puts the red back in arena 3) and on the
## particles they spawn.

## Textures that have arena versions.
const TEXTURES: Array[String] = [
	"res://Assets/Sprites/ship_enemy.png",
	"res://Assets/Sprites/saw1.png",
	"res://Assets/Sprites/enemy_laser.png",
	"res://Assets/Sprites/ship_enemy_particles.png",
	"res://Assets/Sprites/sawparticle.png",
]
## The original look of a node, kept once so it can be put back.
const META_ORIGINAL: StringName = &"_arena_skin_original"

## "resource id:arena" -> arena version (textures, particle materials, gradients).
static var _cache: Dictionary = {}


## Dresses `root` and everything under it for the current arena.
static func apply(root: Node) -> void:
	var arena: int = GameManager.current_arena_index
	var skin: Dictionary = GameManager.arena_enemy_colors.get(arena, {})
	_apply_node(root, arena, skin)


static func _apply_node(node: Node, arena: int, skin: Dictionary) -> void:
	if node is Sprite2D or node is GPUParticles2D or node is PointLight2D:
		_swap(node, &"texture", arena, skin)
	if node is GPUParticles2D:
		_swap(node, &"process_material", arena, skin)
	elif node is CPUParticles2D:
		for property: StringName in [&"texture", &"color_ramp", &"color_initial_ramp"]:
			_swap(node, property, arena, skin)
		_swap_color(node, &"color", skin)
	if node is PointLight2D:
		_swap_color(node, &"color", skin)
		# Each arena can tone the enemies' lights down (light_energy multiplier)
		var energy: float = _original(node, &"energy")
		node.energy = energy * float(skin.get("light_energy", 1.0))
	for child in node.get_children():
		_apply_node(child, arena, skin)


## Puts the arena version of a resource property (or the original back).
static func _swap(node: Node, property: StringName, arena: int, skin: Dictionary) -> void:
	var original: Variant = _original(node, property)
	if not original is Resource:
		return
	node.set(property, _version(original, arena, skin) if not skin.is_empty() else original)


static func _swap_color(node: Node, property: StringName, skin: Dictionary) -> void:
	var original: Color = _original(node, property)
	node.set(property, recolor(original, skin) if not skin.is_empty() else original)


static func _original(node: Node, property: StringName) -> Variant:
	var originals: Dictionary = node.get_meta(META_ORIGINAL, {})
	if not originals.has(property):
		originals[property] = node.get(property)
		node.set_meta(META_ORIGINAL, originals)
	return originals[property]


## The arena version of a texture, particle material or gradient (cached).
static func _version(resource: Resource, arena: int, skin: Dictionary) -> Resource:
	var key: String = "%d:%d" % [resource.get_instance_id(), arena]
	if _cache.has(key):
		return _cache[key]
	var result: Resource = resource
	if resource is Texture2D and TEXTURES.has(resource.resource_path):
		var path: String = resource.resource_path.get_basename() + "_" + skin["name"] + ".png"
		if ResourceLoader.exists(path):
			result = load(path)
	elif resource is GradientTexture2D or resource is GradientTexture1D:
		result = resource.duplicate()
		result.gradient = _version(resource.gradient, arena, skin)
	elif resource is Gradient:
		result = resource.duplicate()
		var colors: PackedColorArray = result.colors
		for i in colors.size():
			colors[i] = recolor(colors[i], skin)
		result.colors = colors
	elif resource is ParticleProcessMaterial:
		result = resource.duplicate()
		result.color = recolor(resource.color, skin)
		for ramp: StringName in [&"color_ramp", &"color_initial_ramp"]:
			if result.get(ramp) is Resource:
				result.set(ramp, _version(result.get(ramp), arena, skin))
	_cache[key] = result
	return result


## A colour of the scenes' ramps and lights in the arena's colour: the red channel trades
## places with the arena's channel (blue or green), so lights, trails and explosions look
## exactly like the red ones (same intensity, glow and fade), only in another colour.
## Whites, greys and black don't change.
static func recolor(color: Color, skin: Dictionary) -> Color:
	match skin.get("channel", ""):
		"blue":
			return Color(color.b, color.g, color.r, color.a)
		"green":
			return Color(color.g, color.r, color.b, color.a)
	return color
