extends Node3D

const HALF_SIZE := 24
const TextureFactoryScript = preload("res://scripts/texture_factory.gd")
const WATER_SHADER = preload("res://shaders/water.gdshader")
const SEA_LEVEL := 9

const FACE_DEFS := [
	{"normal": Vector3i(1, 0, 0), "corners": [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)], "shade": 0.84},
	{"normal": Vector3i(-1, 0, 0), "corners": [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)], "shade": 0.78},
	{"normal": Vector3i(0, 1, 0), "corners": [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)], "shade": 1.0},
	{"normal": Vector3i(0, -1, 0), "corners": [Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], "shade": 0.57},
	{"normal": Vector3i(0, 0, 1), "corners": [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)], "shade": 0.91},
	{"normal": Vector3i(0, 0, -1), "corners": [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)], "shade": 0.72}
]

const BLOCK_COLORS := {
	"grass": [Color("#659b45"), Color("#8dbb56")],
	"dirt": [Color("#8a5b3d"), Color("#a87850")],
	"stone": [Color("#777e87"), Color("#969da5")],
	"sand": [Color("#d8c17b"), Color("#f0d99a")],
	"snow": [Color("#e2edf2"), Color("#ffffff")],
	"wood": [Color("#805534"), Color("#ae7b4d")],
	"leaves": [Color("#3f8750"), Color("#65a95d")],
	"coal_ore": [Color("#747b83"), Color("#303740")],
	"iron_ore": [Color("#858b91"), Color("#c48b70")],
	"copper_ore": [Color("#858b91"), Color("#d7834e")],
	"gold_ore": [Color("#858b91"), Color("#f3ca55")],
	"diamond_ore": [Color("#858b91"), Color("#63d8d5")],
	"bedrock": [Color("#323943"), Color("#4b525c")],
	"planks": [Color("#b78652"), Color("#d5a76b")],
	"cobblestone": [Color("#737a83"), Color("#a1a8ae")],
	"crafting_table": [Color("#9d673d"), Color("#d4a05b")],
	"furnace": [Color("#5f6871"), Color("#8c969f")]
}

var seed_value: int = 0
var blocks: Dictionary = {}
var edits: Dictionary = {}
var height_map: Dictionary = {}
var _materials: Dictionary = {}
var _world_mesh: ArrayMesh
var _mesh_instance: MeshInstance3D
var _static_body: StaticBody3D
var _water_node: MeshInstance3D
var _rng := RandomNumberGenerator.new()

func generate_world(new_seed: int, saved_edits: Dictionary = {}) -> void:
	_clear_generated_nodes()
	seed_value = new_seed
	blocks.clear()
	height_map.clear()
	_materials.clear()
	edits = saved_edits.duplicate(true)
	_rng.seed = seed_value

	var terrain := FastNoiseLite.new()
	terrain.seed = seed_value
	terrain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain.frequency = 0.035
	terrain.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain.fractal_octaves = 5
	terrain.fractal_gain = 0.52

	var detail := FastNoiseLite.new()
	detail.seed = seed_value + 421
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = 0.11

	var temperature := FastNoiseLite.new()
	temperature.seed = seed_value + 991
	temperature.noise_type = FastNoiseLite.TYPE_SIMPLEX
	temperature.frequency = 0.023

	var caves := FastNoiseLite.new()
	caves.seed = seed_value + 7717
	caves.noise_type = FastNoiseLite.TYPE_SIMPLEX
	caves.frequency = 0.085
	caves.fractal_type = FastNoiseLite.FRACTAL_FBM
	caves.fractal_octaves = 3

	for x in range(-HALF_SIZE, HALF_SIZE):
		for z in range(-HALF_SIZE, HALF_SIZE):
			var n := terrain.get_noise_2d(float(x), float(z))
			var d := detail.get_noise_2d(float(x), float(z))
			var surface_y := clampi(int(round(12.0 + n * 7.0 + d * 2.4)), 5, 22)
			height_map[Vector2i(x, z)] = surface_y

			var top_type := "grass"
			if surface_y <= SEA_LEVEL + 1:
				top_type = "sand"
			elif temperature.get_noise_2d(float(x), float(z)) < -0.38 and surface_y > 16:
				top_type = "snow"

			for y in range(0, surface_y + 1):
				if y == 0:
					blocks[Vector3i(x, y, z)] = "bedrock"
				elif y < surface_y - 3:
					if y > 2 and caves.get_noise_3d(float(x), float(y), float(z)) > 0.48:
						continue
					blocks[Vector3i(x, y, z)] = "stone"
				elif y < surface_y:
					blocks[Vector3i(x, y, z)] = "dirt" if top_type == "grass" else "sand"
				else:
					blocks[Vector3i(x, y, z)] = top_type

	_generate_ore_veins()
	_generate_trees()
	_apply_saved_edits()
	_rebuild_world_mesh()
	_create_water()

func _clear_generated_nodes() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_mesh_instance = null
	_static_body = null
	_water_node = null

func _generate_ore_veins() -> void:
	for attempt in range(230):
		var x := _rng.randi_range(-HALF_SIZE + 2, HALF_SIZE - 3)
		var z := _rng.randi_range(-HALF_SIZE + 2, HALF_SIZE - 3)
		var max_y: int = int(height_map.get(Vector2i(x, z), 12)) - 4
		if max_y < 3:
			continue
		var y := _rng.randi_range(2, max_y)
		var ore_type := "coal_ore"
		if y <= 5 and _rng.randf() < 0.16:
			ore_type = "diamond_ore"
		elif y <= 8 and _rng.randf() < 0.22:
			ore_type = "gold_ore"
		elif y <= 13 and _rng.randf() < 0.34:
			ore_type = "iron_ore"
		elif y <= 17 and _rng.randf() < 0.34:
			ore_type = "copper_ore"

		var vein_size := _rng.randi_range(3, 6)
		for i in range(vein_size):
			var p := Vector3i(
				x + _rng.randi_range(-1, 1),
				y + _rng.randi_range(-1, 1),
				z + _rng.randi_range(-1, 1)
			)
			if str(blocks.get(p, "")) == "stone":
				blocks[p] = ore_type

func _generate_trees() -> void:
	for x in range(-HALF_SIZE + 2, HALF_SIZE - 2):
		for z in range(-HALF_SIZE + 2, HALF_SIZE - 2):
			var surface_y: int = int(height_map.get(Vector2i(x, z), 0))
			if surface_y <= SEA_LEVEL + 2:
				continue
			if str(blocks.get(Vector3i(x, surface_y, z), "")) != "grass":
				continue
			if _rng.randf() < 0.024:
				_add_tree(Vector3i(x, surface_y + 1, z))

func _add_tree(origin: Vector3i) -> void:
	var trunk_height := _rng.randi_range(3, 5)
	for y in range(trunk_height):
		blocks[origin + Vector3i(0, y, 0)] = "wood"
	for dy in range(1, 4):
		var radius := 2 if dy < 3 else 1
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if abs(dx) + abs(dz) + (1 if dy == 1 else 0) > 4:
					continue
				var p := origin + Vector3i(dx, trunk_height - 2 + dy, dz)
				if not blocks.has(p):
					blocks[p] = "leaves"
	blocks[origin + Vector3i(0, trunk_height + 2, 0)] = "leaves"

func _apply_saved_edits() -> void:
	for key in edits.keys():
		var parts := str(key).split(",")
		if parts.size() != 3:
			continue
		var p := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		var value := str(edits[key])
		if value.is_empty():
			blocks.erase(p)
		else:
			blocks[p] = value

func _rebuild_world_mesh() -> void:
	if is_instance_valid(_mesh_instance):
		remove_child(_mesh_instance)
		_mesh_instance.free()
	if is_instance_valid(_static_body):
		remove_child(_static_body)
		_static_body.free()
	var grouped: Dictionary = {}
	for p in blocks.keys():
		var block_type := str(blocks[p])
		if not grouped.has(block_type):
			grouped[block_type] = {
				"vertices": PackedVector3Array(),
				"normals": PackedVector3Array(),
				"uvs": PackedVector2Array(),
				"colors": PackedColorArray(),
				"indices": PackedInt32Array()
			}
		for face in FACE_DEFS:
			var neighbour: Vector3i = p + face["normal"]
			if blocks.has(neighbour):
				var neighbour_type := str(blocks[neighbour])
				if not (block_type == "leaves" and neighbour_type == "leaves"):
					continue

			var data: Dictionary = grouped[block_type]
			var base_index: int = data["vertices"].size()
			var corners: Array = face["corners"]
			var normal: Vector3 = Vector3(face["normal"])
			var shade: float = float(face["shade"])
			var uv_values := [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
			for corner_index in range(4):
				data["vertices"].append(Vector3(p) + corners[corner_index])
				data["normals"].append(normal)
				data["uvs"].append(uv_values[corner_index])
				data["colors"].append(Color(shade, shade, shade, 1.0))
			data["indices"].append_array(PackedInt32Array([
				base_index, base_index + 1, base_index + 2,
				base_index, base_index + 2, base_index + 3
			]))

	_world_mesh = ArrayMesh.new()
	for block_type in grouped.keys():
		var data: Dictionary = grouped[block_type]
		if data["vertices"].is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
		arrays[Mesh.ARRAY_NORMAL] = data["normals"]
		arrays[Mesh.ARRAY_TEX_UV] = data["uvs"]
		arrays[Mesh.ARRAY_COLOR] = data["colors"]
		arrays[Mesh.ARRAY_INDEX] = data["indices"]
		_world_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_world_mesh.surface_set_material(_world_mesh.get_surface_count() - 1, _get_block_material(str(block_type)))

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "VoxelTerrain"
	_mesh_instance.mesh = _world_mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh_instance)

	_static_body = StaticBody3D.new()
	_static_body.name = "TerrainCollision"
	_static_body.collision_layer = 1
	_static_body.collision_mask = 1
	var collision := CollisionShape3D.new()
	collision.shape = _world_mesh.create_trimesh_shape()
	_static_body.add_child(collision)
	add_child(_static_body)

func _get_block_material(block_type: String) -> StandardMaterial3D:
	if _materials.has(block_type):
		return _materials[block_type]

	var palette: Array = BLOCK_COLORS.get(block_type, [Color("#8c949c"), Color("#b0b7be")])
	var base: Color = palette[0]
	var accent: Color = palette[1]
	var texture_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var texture_rng := RandomNumberGenerator.new()
	texture_rng.seed = abs(hash(block_type))
	for y in range(16):
		for x in range(16):
			var strength := texture_rng.randf_range(0.82, 1.12)
			var pixel := base.lerp(accent, texture_rng.randf_range(0.0, 0.34)) * strength
			if texture_rng.randf() < 0.08:
				pixel = accent
			texture_image.set_pixel(x, y, pixel)

	var texture := TextureFactoryScript.get_texture(block_type, abs(hash(block_type)) % 10)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[block_type] = material
	return material

func _create_water() -> void:
	if is_instance_valid(_water_node):
		remove_child(_water_node)
		_water_node.free()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(70, 70)
	var water := MeshInstance3D.new()
	water.name = "OceanSurface"
	_water_node = water
	water.mesh = water_mesh
	water.position = Vector3(0, SEA_LEVEL + 0.08, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	water.material_override = material
	add_child(water)

func get_block(position: Vector3i) -> String:
	return str(blocks.get(position, ""))

func remove_block(position: Vector3i) -> bool:
	var block_type := get_block(position)
	if block_type.is_empty() or block_type == "bedrock":
		return false
	blocks.erase(position)
	edits[_position_key(position)] = ""
	_rebuild_world_mesh()
	_create_water()
	return true

func add_block(position: Vector3i, block_type: String) -> bool:
	if blocks.has(position):
		return false
	var allowed := ["grass", "dirt", "stone", "sand", "wood", "leaves", "planks", "cobblestone", "crafting_table", "furnace"]
	if not allowed.has(block_type):
		return false
	blocks[position] = block_type
	edits[_position_key(position)] = block_type
	_rebuild_world_mesh()
	_create_water()
	return true

func _position_key(position: Vector3i) -> String:
	return "%d,%d,%d" % [position.x, position.y, position.z]

func get_spawn_position() -> Vector3:
	var surface_y: int = int(height_map.get(Vector2i(0, 0), 12))
	return Vector3(0.5, float(surface_y) + 1.91, 0.5)

func get_surface_height(x: int, z: int) -> int:
	return int(height_map.get(Vector2i(x, z), 12))

func random_surface_position(min_radius: int = 7, max_radius: int = 18) -> Vector3:
	for attempt in range(30):
		var x := _rng.randi_range(-max_radius, max_radius)
		var z := _rng.randi_range(-max_radius, max_radius)
		if Vector2(x, z).length() < float(min_radius):
			continue
		var h := get_surface_height(x, z)
		if h > SEA_LEVEL + 1:
			return Vector3(float(x) + 0.5, float(h) + 1.0, float(z) + 0.5)
	return get_spawn_position() + Vector3(8, 0, 8)
