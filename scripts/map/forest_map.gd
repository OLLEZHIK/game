class_name ForestMap
extends Node3D

signal obstacle_cleared_event(lane_index: int)

@onready var lane_manager: LaneManager = $LaneManager
@onready var mid_obstacle: LaneObstacle = $Obstacles/ObstacleLog
@onready var allied_base: Base3Tunnels = $Bases/AlliedBase if has_node("Bases/AlliedBase") else null
@onready var enemy_base: Base3Tunnels = $Bases/EnemyBase if has_node("Bases/EnemyBase") else null

func _ready() -> void:
	if mid_obstacle:
		mid_obstacle.obstacle_cleared.connect(_on_obstacle_cleared)

func _on_obstacle_cleared(_obs: LaneObstacle) -> void:
	print("[ForestMap] Mid lane obstacle cleared! Lane 1 is now OPEN.")
	if lane_manager:
		lane_manager.set_lane_blocked(1, false)
	obstacle_cleared_event.emit(1)

func damage_obstacle(amount: float = 35.0) -> void:
	if mid_obstacle and not mid_obstacle.is_cleared:
		mid_obstacle.apply_sawing_damage(amount)

func get_spawn_pos_for_lane(lane_idx: int) -> Vector3:
	if allied_base:
		return allied_base.get_tunnel_spawn_position(lane_idx)
	return Vector3(-24, 0, (lane_idx - 1) * 12.0)
