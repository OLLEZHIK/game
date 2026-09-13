class_name LaneManager
extends Node3D

signal lane_blocked_state_changed(lane_index: int, is_blocked: bool)

@export var top_path: Path3D
@export var mid_path: Path3D
@export var bot_path: Path3D

var lane_paths: Array[Path3D] = []
var lane_blocked: Array[bool] = [false, true, false] # Mid starts blocked by fallen log

func _ready() -> void:
	lane_paths = [top_path, mid_path, bot_path]

func get_lane_path(lane_index: int) -> Path3D:
	if lane_index >= 0 and lane_index < lane_paths.size():
		return lane_paths[lane_index]
	return null

func get_lane_count() -> int:
	return lane_paths.size()

func is_lane_blocked(lane_index: int) -> bool:
	if lane_index >= 0 and lane_index < lane_blocked.size():
		return lane_blocked[lane_index]
	return false

func set_lane_blocked(lane_index: int, blocked: bool) -> void:
	if lane_index >= 0 and lane_index < lane_blocked.size():
		lane_blocked[lane_index] = blocked
		lane_blocked_state_changed.emit(lane_index, blocked)

func get_position_at_ratio(lane_index: int, ratio: float) -> Vector3:
	var path = get_lane_path(lane_index)
	if not path or not path.curve:
		return Vector3.ZERO
	var total_len = path.curve.get_baked_length()
	var offset = clampf(ratio, 0.0, 1.0) * total_len
	var local_pos = path.curve.sample_baked(offset)
	return path.to_global(local_pos)

func get_lane_length(lane_index: int) -> float:
	var path = get_lane_path(lane_index)
	if path and path.curve:
		return path.curve.get_baked_length()
	return 0.0
