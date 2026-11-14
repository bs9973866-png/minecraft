extends CharacterBody3D

var game_ref
var mob_kind := "deer"
var mob_health := 3
var move_speed := 1.7
var roam_target := Vector3.ZERO
var roam_timer := 0.0
var attack_timer := 0.0
var animation_time := 0.0
var model_root: Node3D

func setup(kind: String, game_node) -> void:
	mob_kind = kind
	game_ref = game_node
	name = "Mob_" + kind
	add_to_group("mobs")
	collision_layer = 2
	collision_mask = 1
	if kind == "slime":
		mob_health = 4
		move_speed = 2.8
	_build_collision()
	_build_model()
	_choose_roam_target()

func _build_collision() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42 if mob_kind == "slime" else 0.34
	shape.height = 1.15 if mob_kind == "slime" else 1.45
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.66
	add_child(collider)

func _build_model() -> void:
	model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)

	if mob_kind == "slime":
		_add_box(Vector3(0.92, 0.78, 0.92), Vector3(0, 0.46, 0), Color("#72c77d"))
		_add_box(Vector3(0.13, 0.13, 0.06), Vector3(-0.22, 0.55, -0.47), Color("#203d35"))
		_add_box(Vector3(0.13, 0.13, 0.06), Vector3(0.22, 0.55, -0.47), Color("#203d35"))
		_add_box(Vector3(0.32, 0.07, 0.06), Vector3(0, 0.31, -0.48), Color("#285a43"))
	else:
		_add_box(Vector3(0.58, 0.72, 0.92), Vector3(0, 0.77, 0), Color("#bd9a70"))
		_add_box(Vector3(0.48, 0.48, 0.48), Vector3(0, 1.18, -0.48), Color("#d2b28c"))
		_add_box(Vector3(0.10, 0.10, 0.08), Vector3(-0.13, 1.25, -0.72), Color("#27343a"))
		_add_box(Vector3(0.10, 0.10, 0.08), Vector3(0.13, 1.25, -0.72), Color("#27343a"))
		_add_box(Vector3(0.12, 0.45, 0.12), Vector3(-0.18, 1.64, -0.43), Color("#d9d0b4"))
		_add_box(Vector3(0.12, 0.45, 0.12), Vector3(0.18, 1.64, -0.43), Color("#d9d0b4"))
		for leg_x in [-0.19, 0.19]:
			for leg_z in [-0.29, 0.29]:
				_add_box(Vector3(0.16, 0.46, 0.16), Vector3(leg_x, 0.23, leg_z), Color("#8b6b50"))

func _add_box(dimensions: Vector3, at: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	instance.mesh = box
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	instance.material_override = material
	model_root.add_child(instance)

func _choose_roam_target() -> void:
	var angle := randf() * TAU
	var distance := randf_range(2.0, 6.5)
	roam_target = global_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
	roam_timer = randf_range(2.0, 5.0)

func _physics_process(delta: float) -> void:
	if game_ref == null or not is_instance_valid(game_ref.player):
		return
	animation_time += delta
	roam_timer -= delta
	attack_timer = maxf(0.0, attack_timer - delta)
	if model_root:
		model_root.position.y = sin(animation_time * (4.0 if mob_kind == "slime" else 2.5)) * (0.045 if mob_kind == "slime" else 0.018)

	var player_position: Vector3 = game_ref.player.global_position
	var to_player := player_position - global_position
	to_player.y = 0.0
	var direction := Vector3.ZERO
	var current_speed := move_speed

	if mob_kind == "slime" and to_player.length() < 15.0:
		direction = to_player.normalized()
		current_speed = move_speed
		if to_player.length() < 1.45 and attack_timer <= 0.0:
			game_ref.player_hurt(1)
			attack_timer = 1.5
	else:
		if roam_timer <= 0.0 or global_position.distance_to(roam_target) < 0.8:
			_choose_roam_target()
		var to_target := roam_target - global_position
		to_target.y = 0.0
		direction = to_target.normalized()
		current_speed = move_speed * 0.65

	if direction.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 5.0)
	velocity.x = move_toward(velocity.x, direction.x * current_speed, 8.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * current_speed, 8.0 * delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.2
	move_and_slide()

func take_damage(amount: int = 1) -> void:
	mob_health -= amount
	if mob_health <= 0:
		if game_ref:
			game_ref.on_mob_defeated(mob_kind, global_position)
		queue_free()
