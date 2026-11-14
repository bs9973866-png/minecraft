extends CharacterBody3D

var game_ref
var world_ref
var camera: Camera3D
var move_input := Vector2.ZERO
var controls_enabled := false
var look_pitch := 0.0
var move_speed := 6.5
var acceleration := 22.0
var sprint_enabled := false
var jump_requested := false
var touch_look_id := -1
var last_touch_position := Vector2.ZERO
var hand: MeshInstance3D
var hand_material: StandardMaterial3D
var bob_time := 0.0
var base_camera_position := Vector3(0, 0.66, 0)

func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.82
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	add_child(collider)

	camera = Camera3D.new()
	camera.name = "FirstPersonCamera"
	camera.position = base_camera_position
	camera.current = true
	camera.fov = 76.0
	camera.near = 0.05
	add_child(camera)
	_create_first_person_hand()


func _create_first_person_hand() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.19, 0.48, 0.19)
	hand = MeshInstance3D.new()
	hand.name = "FirstPersonHand"
	hand.mesh = mesh
	hand.position = Vector3(0.36, -0.40, -0.62)
	hand.rotation_degrees = Vector3(-12, -8, -8)
	hand_material = StandardMaterial3D.new()
	hand_material.albedo_color = Color("#d6a17c")
	hand_material.roughness = 0.95
	hand.material_override = hand_material
	camera.add_child(hand)
	apply_saved_skin()

func apply_saved_skin() -> void:
	if FileAccess.file_exists("user://player_skin.png"):
		apply_skin("user://player_skin.png")

func apply_skin(path: String) -> void:
	var skin_image := Image.new()
	var error := skin_image.load(path)
	if error != OK:
		return
	if skin_image.get_width() < 48 or skin_image.get_height() < 32:
		return
	if skin_image.get_width() >= 64 and skin_image.get_height() >= 64:
		skin_image = skin_image.get_region(Rect2i(40, 20, 8, 12))
	skin_image.resize(16, 24, Image.INTERPOLATE_NEAREST)
	var skin_texture := ImageTexture.create_from_image(skin_image)
	if hand_material:
		hand_material.albedo_texture = skin_texture
		hand_material.albedo_color = Color.WHITE

func setup(game_node, world_node) -> void:
	game_ref = game_node
	world_ref = world_node

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	set_physics_process(enabled)
	if not enabled:
		move_input = Vector2.ZERO
		velocity = Vector3.ZERO
		sprint_enabled = false

func set_move_input(value: Vector2) -> void:
	move_input = value.limit_length(1.0)

func set_sprint(enabled: bool) -> void:
	sprint_enabled = enabled

func jump() -> void:
	jump_requested = true

func look_by(delta: Vector2, touch: bool = false) -> void:
	var sensitivity := 0.0042 if touch else 0.0026
	rotate_y(-delta.x * sensitivity)
	look_pitch = clampf(look_pitch - delta.y * sensitivity, -1.35, 1.35)
	camera.rotation.x = look_pitch

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_by(event.relative, false)
	elif event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.38:
			touch_look_id = event.index
			last_touch_position = event.position
		elif not event.pressed and event.index == touch_look_id:
			touch_look_id = -1
	elif event is InputEventScreenDrag and event.index == touch_look_id:
		look_by(event.relative, true)
		last_touch_position = event.position

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return

	var direction_input := move_input
	var keyboard_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard_input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard_input.y += 1.0
	if keyboard_input.length() > 0.1:
		direction_input = keyboard_input.normalized()

	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var move_direction := right * direction_input.x + forward * -direction_input.y
	move_direction.y = 0.0
	if move_direction.length() > 1.0:
		move_direction = move_direction.normalized()

	var current_speed := move_speed * (1.65 if sprint_enabled else 1.0)
	velocity.x = move_toward(velocity.x, move_direction.x * current_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * current_speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	elif jump_requested or Input.is_key_pressed(KEY_SPACE):
		velocity.y = 8.0
	jump_requested = false
	move_and_slide()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.2:
		bob_time += delta * minf(horizontal_speed * 1.8, 13.0)
	else:
		bob_time = move_toward(bob_time, 0.0, delta * 5.0)
	camera.position = base_camera_position + Vector3(0, sin(bob_time * 2.0) * 0.025, 0)
	if hand:
		hand.position.y = -0.40 + sin(bob_time * 2.0) * 0.035
		hand.rotation.x = sin(bob_time) * 0.035
	if global_position.y < -15.0 and game_ref:
		game_ref.player_hurt(10)

func raycast(max_distance: float = 6.0) -> Dictionary:
	if camera == null:
		return {}
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * max_distance)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 3
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func teleport_to_spawn(spawn_position: Vector3) -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	look_pitch = 0.0
	if camera:
		camera.rotation = Vector3.ZERO
