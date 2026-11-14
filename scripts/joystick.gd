extends Control

signal vector_changed(value: Vector2)

var active_touch_id := -1
var current_vector := Vector2.ZERO
var knob_position := Vector2.ZERO
var radius := 58.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(156, 156)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch_id == -1:
			active_touch_id = event.index
			_update_vector(event.position)
			accept_event()
		elif not event.pressed and event.index == active_touch_id:
			active_touch_id = -1
			current_vector = Vector2.ZERO
			knob_position = size * 0.5
			vector_changed.emit(current_vector)
			queue_redraw()
			accept_event()
	elif event is InputEventScreenDrag and event.index == active_touch_id:
		_update_vector(event.position)
		accept_event()

func _update_vector(local_position: Vector2) -> void:
	var center := size * 0.5
	var offset := local_position - center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	knob_position = center + offset
	current_vector = Vector2(offset.x / radius, offset.y / radius)
	vector_changed.emit(current_vector)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	if active_touch_id == -1:
		knob_position = center
	draw_circle(center, radius + 12.0, Color(0.025, 0.04, 0.065, 0.30))
	draw_arc(center, radius + 11.0, 0.0, TAU, 48, Color(0.75, 0.86, 0.92, 0.35), 2.0)
	draw_circle(knob_position, 33.0, Color(0.40, 0.75, 0.73, 0.52))
	draw_arc(knob_position, 33.0, 0.0, TAU, 40, Color(0.78, 0.97, 0.91, 0.72), 2.0)
