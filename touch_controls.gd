extends Control

signal move_changed(value: Vector2)
signal look_delta(delta: Vector2)
signal screen_tap(position: Vector2)
var right_moved := false

var left_finger := -1
var right_finger := -1
var joystick_origin := Vector2.ZERO
var joystick_value := Vector2.ZERO
var joystick_radius := 78.0

func _ready() -> void:
	set_process_input(true)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < size.x * 0.48 and left_finger == -1:
				left_finger = event.index
				joystick_origin = event.position
				_update_joystick(event.position)
			elif right_finger == -1:
				right_finger = event.index
				right_moved = false
		else:
			if event.index == left_finger:
				left_finger = -1
				joystick_value = Vector2.ZERO
				move_changed.emit(Vector2.ZERO)
				queue_redraw()
			if event.index == right_finger:
				if not right_moved:
					screen_tap.emit(event.position)
				right_finger = -1
		accept_event()

	elif event is InputEventScreenDrag:
		if event.index == left_finger:
			_update_joystick(event.position)
			accept_event()
		elif event.index == right_finger:
			if event.relative.length() > 5.0:
				right_moved = true
			look_delta.emit(event.relative)
			accept_event()

func _update_joystick(position: Vector2) -> void:
	var offset := position - joystick_origin
	if offset.length() > joystick_radius:
		offset = offset.normalized() * joystick_radius
	joystick_value = offset / joystick_radius
	move_changed.emit(joystick_value)
	queue_redraw()

func _draw() -> void:
	# Small fixed center reticle used for interaction and EDIT selection.
	var center := size * 0.5
	draw_circle(center, 4.0, Color(0.04, 0.05, 0.06, 0.85))
	draw_arc(center, 5.5, 0.0, TAU, 24, Color(0.96, 0.96, 0.90, 0.95), 1.4)
	var base := Vector2(105, size.y - 112)
	if left_finger != -1:
		base = joystick_origin
	draw_circle(base, joystick_radius, Color(0.10, 0.14, 0.18, 0.34))
	draw_arc(base, joystick_radius, 0.0, TAU, 48, Color(0.82, 0.88, 0.94, 0.55), 3.0)
	var knob := base + joystick_value * joystick_radius
	draw_circle(knob, 34.0, Color(0.78, 0.84, 0.90, 0.55))
	draw_arc(knob, 34.0, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 2.0)

	if right_finger == -1:
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 230, size.y - 28), "DRAG TO LOOK", HORIZONTAL_ALIGNMENT_CENTER, 190, 14, Color(1, 1, 1, 0.38))
