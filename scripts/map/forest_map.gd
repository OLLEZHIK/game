class_name ForestMap
extends Node3D

signal obstacle_cleared_event(lane_index: int)

@onready var lane_manager: LaneManager = $LaneManager
@onready var mid_obstacle: LaneObstacle = $Obstacles/ObstacleLog
@onready var allied_hive: BaseHive = $Bases/AlliedHive
@onready var enemy_hive: BaseHive = $Bases/EnemyHive
@onready var nectar_patch: Node3D = $Props/NectarGlade

func _ready() -> void:
	if mid_obstacle:
		mid_obstacle.obstacle_cleared.connect(_on_obstacle_cleared)

func _on_obstacle_cleared(obs: LaneObstacle) -> void:
	print("[ForestMap] Mid lane obstacle cleared! Lane 1 is now OPEN.")
	if lane_manager:
		lane_manager.set_lane_blocked(1, false)
	obstacle_cleared_event.emit(1)

func damage_obstacle(amount: float = 30.0) -> void:
	if mid_obstacle and not mid_obstacle.is_cleared:
		mid_obstacle.apply_sawing_damage(amount)

func get_allied_base_position() -> Vector3:
	return allied_hive.global_position if allied_hive else Vector3(-28, 0, 0)

func get_enemy_base_position() -> Vector3:
	return enemy_hive.global_position if enemy_hive else Vector3(28, 0, 0)
