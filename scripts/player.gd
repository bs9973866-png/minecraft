extends CharacterBody3D

var game_ref
var world_ref
var camera: Camera3D
var move_input := Vector2.ZERO
var controls_enabled := false
var look_pitch := 0.0
var move_speed := 6.5
var acceleration := 22.0
var jump_requested := false
var touch_look_id := -1
var last_touch_position := Vector2.ZERO

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
	camera.position = Vector3(0, 0.66, 0)
	camera.current = true
	camera.fov = 76.0
	camera.near = 0.05
	add_child(camera)

func setup(game_node, world_node) -> void:
	game_ref = game_node
	world_ref = world_node

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	set_physics_process(enabled)
	if not enabled:
		move_input = Vector2.ZERO
		velocity = Vector3.ZERO

func set_move_input(value: Vector2) -> void:
	move_input = value.limit_length(1.0)

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

	velocity.x = move_toward(velocity.x, move_direction.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * move_speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	elif jump_requested or Input.is_key_pressed(KEY_SPACE):
		velocity.y = 8.0
	jump_requested = false
	move_and_slide()

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
