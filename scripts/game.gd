extends Node3D

const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const MobScript = preload("res://scripts/mob.gd")
const HUDScript = preload("res://scripts/hud.gd")
const SAVE_PATH := "user://blockbound_world.json"

const HOTBAR_DEFAULT := [
	"dirt", "stone", "wood", "planks",
	"sand", "crafting_table", "furnace", "cobblestone"
]

const PLACEABLE_BLOCKS := [
	"grass", "dirt", "stone", "sand", "wood", "leaves",
	"planks", "cobblestone", "crafting_table", "furnace"
]

const ITEM_TITLES := {
	"grass": "Трава",
	"dirt": "Земля",
	"stone": "Камень",
	"sand": "Песок",
	"wood": "Бревно",
	"leaves": "Листва",
	"coal_ore": "Угольная руда",
	"iron_ore": "Железная руда",
	"copper_ore": "Медная руда",
	"gold_ore": "Золотая руда",
	"diamond_ore": "Алмазная руда",
	"coal": "Уголь",
	"raw_iron": "Железо-сырец",
	"raw_copper": "Медь-сырец",
	"raw_gold": "Золото-сырец",
	"diamond": "Алмаз",
	"planks": "Доски",
	"sticks": "Палки",
	"cobblestone": "Булыжник",
	"crafting_table": "Верстак",
	"furnace": "Печь",
	"wooden_pickaxe": "Деревянная кирка",
	"iron_ingot": "Железный слиток",
	"torch": "Факел",
	"slime_gel": "Слизь",
	"raw_meat": "Сырое мясо"
}

const ITEM_SHORT_NAMES := {
	"grass": "Трава",
	"dirt": "Земля",
	"stone": "Камень",
	"sand": "Песок",
	"wood": "Бревно",
	"leaves": "Листья",
	"planks": "Доски",
	"cobblestone": "Булыж.",
	"crafting_table": "Верстак",
	"furnace": "Печь",
	"coal": "Уголь",
	"raw_iron": "Железо",
	"raw_copper": "Медь",
	"raw_gold": "Золото",
	"diamond": "Алмаз",
	"sticks": "Палки",
	"wooden_pickaxe": "Кирка",
	"torch": "Факел"
}

const RECIPES := [
	{"id": "planks", "label": "4 доски", "input": {"wood": 1}, "output": "planks", "count": 4},
	{"id": "sticks", "label": "4 палки", "input": {"planks": 2}, "output": "sticks", "count": 4},
	{"id": "crafting_table", "label": "Верстак", "input": {"planks": 4}, "output": "crafting_table", "count": 1},
	{"id": "wooden_pickaxe", "label": "Деревянная кирка", "input": {"planks": 3, "sticks": 2}, "output": "wooden_pickaxe", "count": 1},
	{"id": "furnace", "label": "Печь", "input": {"cobblestone": 8}, "output": "furnace", "count": 1},
	{"id": "torch", "label": "4 факела", "input": {"coal": 1, "sticks": 1}, "output": "torch", "count": 4},
	{"id": "iron_ingot", "label": "Железный слиток", "input": {"raw_iron": 1, "coal": 1}, "output": "iron_ingot", "count": 1}
]

var world
var player
var hud
var mode := "survival"
var health := 10
var inventory: Dictionary = {}
var hotbar: Array = HOTBAR_DEFAULT.duplicate()
var selected_slot := 0
var world_seed := 0
var game_active := false
var autosave_timer := 0.0
var attack_cooldown := 0.0

func _ready() -> void:
	_setup_environment()

	world = WorldScript.new()
	world.name = "VoxelWorld"
	add_child(world)
	world_seed = int(Time.get_unix_time_from_system())
	world.generate_world(world_seed)

	player = PlayerScript.new()
	add_child(player)
	player.setup(self, world)
	player.teleport_to_spawn(world.get_spawn_position())
	player.visible = false
	player.set_controls_enabled(false)

	hud = HUDScript.new()
	add_child(hud)
	hud.setup(self)
	hud.show_menu(FileAccess.file_exists(SAVE_PATH))
	set_process(true)

func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#315a7a")
	sky_material.sky_horizon_color = Color("#b4cbd4")
	sky_material.ground_bottom_color = Color("#263b44")
	sky_material.ground_horizon_color = Color("#80959a")
	sky.sky_material = sky_material
	environment.sky = sky

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b4d0d7")
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#9eb9c4")
	environment.fog_density = 0.0018

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48, -32, 0)
	sunlight.light_color = Color("#fff0d9")
	sunlight.light_energy = 1.15
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 64.0
	add_child(sunlight)

func start_new_world(selected_mode: String) -> void:
	mode = selected_mode if selected_mode in ["survival", "creative"] else "survival"
	health = 10
	world_seed = int(Time.get_unix_time_from_system()) + randi_range(1, 99999)
	autosave_timer = 0.0
	selected_slot = 0
	hotbar = HOTBAR_DEFAULT.duplicate()
	inventory.clear()

	if mode == "survival":
		inventory = {
			"wood": 4,
			"dirt": 12,
			"stone": 8,
			"planks": 4
		}
	else:
		for block_id in PLACEABLE_BLOCKS:
			inventory[block_id] = 999
		inventory["wooden_pickaxe"] = 999
		inventory["torch"] = 999

	world.generate_world(world_seed)
	_clear_mobs()
	player.teleport_to_spawn(world.get_spawn_position())
	_spawn_mobs()
	game_active = true
	hud.show_game()
	hud.refresh_inventory()
	save_game()

func continue_world() -> void:
	var data := _load_save()
	if data.is_empty():
		hud.show_menu(false)
		return

	mode = str(data.get("mode", "survival"))
	health = int(data.get("health", 10))
	world_seed = int(data.get("seed", int(Time.get_unix_time_from_system())))
	var saved_inventory = data.get("inventory", {})
	inventory = saved_inventory.duplicate(true) if saved_inventory is Dictionary else {}
	var saved_hotbar = data.get("hotbar", HOTBAR_DEFAULT)
	hotbar = saved_hotbar.duplicate() if saved_hotbar is Array and saved_hotbar.size() == 8 else HOTBAR_DEFAULT.duplicate()
	selected_slot = clampi(int(data.get("selected_slot", 0)), 0, 7)
	var saved_edits = data.get("edits", {})
	world.generate_world(world_seed, saved_edits if saved_edits is Dictionary else {})
	_clear_mobs()
	var saved_position = data.get("player_position", [])
	if saved_position is Array and saved_position.size() == 3:
		player.teleport_to_spawn(Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2])))
	else:
		player.teleport_to_spawn(world.get_spawn_position())
	_spawn_mobs()
	game_active = true
	autosave_timer = 0.0
	hud.show_game()
	hud.refresh_inventory()

func _process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if game_active:
		autosave_timer += delta
		if autosave_timer >= 45.0:
			autosave_timer = 0.0
			save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not game_active:
		return
	if hud and hud.inventory_layer.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			hud.toggle_inventory()
		elif event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_F:
			try_attack()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			select_hotbar_slot(event.keycode - KEY_1)

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT:
			try_break_block()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			place_selected_block()

func _spawn_mobs() -> void:
	for index in range(5):
		var deer = MobScript.new()
		deer.setup("deer", self)
		add_child(deer)
		deer.global_position = world.random_surface_position(8, 20)
	for index in range(3):
		var slime = MobScript.new()
		slime.setup("slime", self)
		add_child(slime)
		slime.global_position = world.random_surface_position(9, 19)

func _clear_mobs() -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()

func get_item_title(item_id: String) -> String:
	return str(ITEM_TITLES.get(item_id, item_id))

func get_item_short_name(item_id: String) -> String:
	return str(ITEM_SHORT_NAMES.get(item_id, ITEM_TITLES.get(item_id, item_id)))

func is_placeable(item_id: String) -> bool:
	return PLACEABLE_BLOCKS.has(item_id)

func get_item_count(item_id: String) -> int:
	if mode == "creative" and is_placeable(item_id):
		return 999
	return int(inventory.get(item_id, 0))

func get_recipes() -> Array:
	return RECIPES

func can_craft(recipe: Dictionary) -> bool:
	if mode == "creative":
		return true
	var inputs: Dictionary = recipe["input"]
	for item_id in inputs.keys():
		if get_item_count(str(item_id)) < int(inputs[item_id]):
			return false
	return true

func get_recipe_description(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	var inputs: Dictionary = recipe["input"]
	for item_id in inputs.keys():
		parts.append("%s ×%d" % [get_item_title(str(item_id)), int(inputs[item_id])])
	return "%s   ←   %s" % [str(recipe["label"]), ", ".join(parts)]

func craft_recipe(recipe_id: String) -> void:
	for recipe in RECIPES:
		if str(recipe["id"]) != recipe_id:
			continue
		if not can_craft(recipe):
			return
		if mode != "creative":
			var inputs: Dictionary = recipe["input"]
			for item_id in inputs.keys():
				inventory[str(item_id)] = get_item_count(str(item_id)) - int(inputs[item_id])
		add_item(str(recipe["output"]), int(recipe["count"]))
		hud.refresh_inventory()
		return

func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	inventory[item_id] = get_item_count(item_id) + amount
	if hud:
		hud.refresh_hud()

func select_hotbar_slot(index: int) -> void:
	selected_slot = clampi(index, 0, hotbar.size() - 1)
	if hud:
		hud.refresh_hud()

func try_break_block() -> void:
	if not game_active or hud.inventory_layer.visible:
		return
	var hit: Dictionary = player.raycast(6.0)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if collider and collider.is_in_group("mobs"):
		return

	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var block_position := Vector3i(
		int(floor(point.x - normal.x * 0.015)),
		int(floor(point.y - normal.y * 0.015)),
		int(floor(point.z - normal.z * 0.015))
	)
	var block_type := world.get_block(block_position)
	if block_type.is_empty() or block_type == "bedrock":
		return
	if not world.remove_block(block_position):
		return
	if mode == "survival":
		add_item(_get_block_drop(block_type), 1 if not block_type.ends_with("_ore") else 2)
	hud.refresh_hud()

func _get_block_drop(block_type: String) -> String:
	match block_type:
		"stone":
			return "cobblestone"
		"coal_ore":
			return "coal"
		"iron_ore":
			return "raw_iron"
		"copper_ore":
			return "raw_copper"
		"gold_ore":
			return "raw_gold"
		"diamond_ore":
			return "diamond"
		_:
			return block_type

func place_selected_block() -> void:
	if not game_active or hud.inventory_layer.visible:
		return
	var item_id := str(hotbar[selected_slot])
	if not is_placeable(item_id):
		return
	if mode != "creative" and get_item_count(item_id) <= 0:
		return

	var hit: Dictionary = player.raycast(6.0)
	if hit.is_empty():
		return
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var target := Vector3i(
		int(floor(point.x + normal.x * 0.015)),
		int(floor(point.y + normal.y * 0.015)),
		int(floor(point.z + normal.z * 0.015))
	)
	var player_block := Vector3(player.global_position.x, player.global_position.y - 0.7, player.global_position.z)
	if Vector3(target).distance_to(player_block) < 1.35:
		return
	if world.add_block(target, item_id):
		if mode != "creative":
			inventory[item_id] = get_item_count(item_id) - 1
		hud.refresh_hud()

func try_attack() -> void:
	if not game_active or attack_cooldown > 0.0 or hud.inventory_layer.visible:
		return
	var hit: Dictionary = player.raycast(3.5)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if collider and collider.is_in_group("mobs") and collider.has_method("take_damage"):
		collider.take_damage(1)
		attack_cooldown = 0.38

func player_hurt(amount: int = 1) -> void:
	if mode == "creative" or not game_active:
		return
	health = max(0, health - amount)
	if hud:
		hud.refresh_hud()
	if health <= 0:
		health = 10
		player.teleport_to_spawn(world.get_spawn_position())
		if hud:
			hud.refresh_hud()

func on_mob_defeated(kind: String, _position: Vector3) -> void:
	if kind == "slime":
		add_item("slime_gel", 1)
	else:
		add_item("raw_meat", 1)

func save_game() -> void:
	if not game_active or not world or not player:
		return
	var data := {
		"seed": world_seed,
		"mode": mode,
		"health": health,
		"inventory": inventory,
		"hotbar": hotbar,
		"selected_slot": selected_slot,
		"player_position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"edits": world.edits
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
