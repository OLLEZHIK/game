class_name RTSCamera
extends Node3D

## RTS & Bug-Cam controller for macro insect warfare
@export var move_speed: float = 26.0
@export var zoom_speed: float = 4.0
@export var min_zoom: float = 8.0
@export var max_zoom: float = 38.0
@export var smooth_factor: float = 12.0
@export var rotate_speed: float = 2.2

@export var map_bounds_min: Vector2 = Vector2(-45.0, -28.0)
@export var map_bounds_max: Vector2 = Vector2(45.0, 28.0)

@onready var elevation_node: Node3D = $Elevation
@onready var camera_3d: Camera3D = $Elevation/Camera3D

var _target_position: Vector3 = Vector3(-8, 0, 0)
var _target_zoom: float = 16.0
var _current_zoom: float = 16.0
var _target_rotation_y: float = 0.0

# Mouse dragging
var is_dragging: bool = false
var drag_last_mouse_pos: Vector2 = Vector2.ZERO

# Bug-Cam tracking
var tracked_target: Node3D = null
var is_bug_cam: bool = false

func _ready() -> void:
	_target_position = global_position
	if camera_3d:
		_target_zoom = camera_3d.position.z
		_current_zoom = _target_zoom

func _process(delta: float) -> void:
	if is_bug_cam and is_instance_valid(tracked_target):
		_process_bug_cam(delta)
	else:
		_process_rts_navigation(delta)

func _process_rts_navigation(delta: float) -> void:
	var move_input = Vector2.ZERO
	
	# Check both physical and logical keys (works on Russian, English, any keyboard layout)
	var right_pressed = (
		Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D)
		or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right")
	)
	var left_pressed = (
		Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A)
		or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left")
	)
	var down_pressed = (
		Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_S)
		or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down")
	)
	var up_pressed = (
		Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_W)
		or Input.is_physical_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up")
	)

	if right_pressed:
		move_input.x += 1.0
	if left_pressed:
		move_input.x -= 1.0
	if down_pressed:
		move_input.y += 1.0
	if up_pressed:
		move_input.y -= 1.0

	if move_input.length_squared() > 0.001:
		move_input = move_input.normalized()
		var forward = -transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right = transform.basis.x
		right.y = 0.0
		right = right.normalized()

		var move_dir = (right * move_input.x + forward * -move_input.y)
		_target_position += move_dir * move_speed * delta

	# Clamp to map boundaries
	_target_position.x = clampf(_target_position.x, map_bounds_min.x, map_bounds_max.x)
	_target_position.z = clampf(_target_position.z, map_bounds_min.y, map_bounds_max.y)

	# Keyboard rotation (Q / E) - physical and logical
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_Q):
		_target_rotation_y += rotate_speed * delta
	if Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E):
		_target_rotation_y -= rotate_speed * delta

	# Smooth position & rotation
	global_position = global_position.lerp(_target_position, smooth_factor * delta)
	rotation.y = lerp_angle(rotation.y, _target_rotation_y, smooth_factor * delta)

	# Smooth zoom
	_current_zoom = lerpf(_current_zoom, _target_zoom, smooth_factor * delta)
	if camera_3d:
		camera_3d.position.z = _current_zoom

func _process_bug_cam(delta: float) -> void:
	var target_pos = tracked_target.global_position
	global_position = global_position.lerp(target_pos, 10.0 * delta)
	_current_zoom = lerpf(_current_zoom, 4.0, 8.0 * delta)
	if camera_3d:
		camera_3d.position.z = _current_zoom
	rotation.y = lerp_angle(rotation.y, tracked_target.rotation.y, 6.0 * delta)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
			_target_zoom = clampf(_target_zoom - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
			_target_zoom = clampf(_target_zoom + zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = event.is_pressed()
			drag_last_mouse_pos = event.position

	# Mouse drag panning
	elif event is InputEventMouseMotion and is_dragging:
		var delta_mouse = event.position - drag_last_mouse_pos
		drag_last_mouse_pos = event.position
		var right = transform.basis.x
		right.y = 0.0
		right = right.normalized()
		var forward = -transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var pan_factor = 0.04 * (_current_zoom / 16.0)
		_target_position -= (right * delta_mouse.x - forward * delta_mouse.y) * pan_factor
		_target_position.x = clampf(_target_position.x, map_bounds_min.x, map_bounds_max.x)
		_target_position.z = clampf(_target_position.z, map_bounds_min.y, map_bounds_max.y)

func set_target_focus(pos: Vector3) -> void:
	_target_position = pos
	_target_position.x = clampf(_target_position.x, map_bounds_min.x, map_bounds_max.x)
	_target_position.z = clampf(_target_position.z, map_bounds_min.y, map_bounds_max.y)

func pan_direction(dir: Vector2) -> void:
	var forward = -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right = transform.basis.x
	right.y = 0.0
	right = right.normalized()
	_target_position += (right * dir.x + forward * -dir.y) * 8.0
	_target_position.x = clampf(_target_position.x, map_bounds_min.x, map_bounds_max.x)
	_target_position.z = clampf(_target_position.z, map_bounds_min.y, map_bounds_max.y)

func adjust_zoom(amount: float) -> void:
	_target_zoom = clampf(_target_zoom + amount, min_zoom, max_zoom)

func toggle_bug_cam(target: Node3D) -> void:
	if is_bug_cam:
		exit_bug_cam()
	elif target != null:
		enter_bug_cam(target)

func enter_bug_cam(target: Node3D) -> void:
	tracked_target = target
	is_bug_cam = true

func exit_bug_cam() -> void:
	is_bug_cam = false
	tracked_target = null
	_target_zoom = 16.0
