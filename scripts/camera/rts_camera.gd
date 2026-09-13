class_name RTSCamera
extends Node3D

## BugBits tactical overview camera (Fixed high-angle perspective)
@export var is_fixed_overview: bool = true
@export var move_speed: float = 16.0
@export var rotate_speed: float = 0.8
@export var smooth_factor: float = 8.0
@export var max_rotation_degrees: float = 15.0

@onready var elevation_node: Node3D = $Elevation
@onready var camera_3d: Camera3D = $Elevation/Camera3D

var default_position: Vector3 = Vector3(5.0, 0, 3.0)
var _target_position: Vector3 = Vector3(5.0, 0, 3.0)
var _target_zoom: float = 38.0
var _current_zoom: float = 38.0
var _target_rotation_y: float = 0.0

# Bug-Cam tracking
var tracked_target: Node3D = null
var is_bug_cam: bool = false

func _ready() -> void:
	default_position = global_position
	_target_position = default_position
	_target_rotation_y = rotation.y
	if camera_3d:
		_target_zoom = camera_3d.position.z
		_current_zoom = _target_zoom

func _process(delta: float) -> void:
	if is_bug_cam and is_instance_valid(tracked_target):
		_process_bug_cam(delta)
	else:
		_process_overview(delta)

func _process_overview(delta: float) -> void:
	# Subtle optional nudge with WASD or mouse drag
	var move_input = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		move_input.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		move_input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		move_input.y += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		move_input.y -= 1.0

	if move_input.length_squared() > 0.001:
		move_input = move_input.normalized()
		_target_position.x += move_input.x * move_speed * delta
		_target_position.z += move_input.y * move_speed * delta
		_target_position.x = clampf(_target_position.x, -8.0, 18.0)
		_target_position.z = clampf(_target_position.z, -8.0, 14.0)
	elif is_fixed_overview:
		# Gently drift back to center overview
		_target_position = _target_position.lerp(default_position, 2.0 * delta)

	# Keyboard rotation with Q / E (max 15 degrees)
	var rot_input: float = 0.0
	var q_pressed: bool = Input.is_physical_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_Q)
	var e_pressed: bool = Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)
	
	if q_pressed and e_pressed:
		_target_rotation_y = lerpf(_target_rotation_y, 0.0, 6.0 * delta)
	elif q_pressed:
		rot_input += 1.0
	elif e_pressed:
		rot_input -= 1.0

	var max_rot_rad: float = deg_to_rad(max_rotation_degrees)
	if rot_input != 0.0:
		_target_rotation_y += rot_input * rotate_speed * delta
		_target_rotation_y = clampf(_target_rotation_y, -max_rot_rad, max_rot_rad)

	global_position = global_position.lerp(_target_position, smooth_factor * delta)
	rotation.y = lerp_angle(rotation.y, _target_rotation_y, smooth_factor * delta)
	_current_zoom = lerpf(_current_zoom, _target_zoom, smooth_factor * delta)
	if camera_3d:
		camera_3d.position.z = _current_zoom

func _process_bug_cam(delta: float) -> void:
	var target_pos = tracked_target.global_position
	global_position = global_position.lerp(target_pos, 10.0 * delta)
	_current_zoom = lerpf(_current_zoom, 4.0, 8.0 * delta)
	if camera_3d:
		camera_3d.position.z = _current_zoom

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom - 2.5, 22.0, 52.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom + 2.5, 22.0, 52.0)

func reset_to_overview() -> void:
	is_bug_cam = false
	tracked_target = null
	_target_position = default_position
	_target_zoom = 38.0
	_target_rotation_y = 0.0

func toggle_bug_cam(target: Node3D) -> void:
	if is_bug_cam:
		reset_to_overview()
	elif target != null:
		tracked_target = target
		is_bug_cam = true
