class_name ForestMap
extends Node3D

signal obstacle_cleared_event(lane_index: int)
signal lane_clicked(lane_index: int)
signal lane_hovered(lane_index: int, is_hovered: bool)

@onready var lane_manager: LaneManager = $LaneManager
@onready var mid_obstacle: LaneObstacle = $Obstacles/ObstacleLog
@onready var allied_base: Base3Tunnels = $Bases/AlliedBase if has_node("Bases/AlliedBase") else null
@onready var enemy_base: Base3Tunnels = $Bases/EnemyBase if has_node("Bases/EnemyBase") else null

var lane_areas: Array[Area3D] = []

func _ready() -> void:
	if mid_obstacle:
		mid_obstacle.obstacle_cleared.connect(_on_obstacle_cleared)
	_setup_lane_click_areas()

func _setup_lane_click_areas() -> void:
	var lane_z_coords = [-12.0, 0.0, 12.0]
	for i in range(3):
		var area = Area3D.new()
		area.name = "LaneClickArea_%d" % i
		area.input_ray_pickable = true
		area.collision_layer = 1
		
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(36.0, 0.8, 4.2)
		col.shape = box
		area.add_child(col)
		
		area.position = Vector3(7.0, 0.2, lane_z_coords[i])
		add_child(area)
		lane_areas.append(area)
		
		var lane_idx = i
		area.input_event.connect(func(_cam: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape: int):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				lane_clicked.emit(lane_idx)
		)
		area.mouse_entered.connect(func(): lane_hovered.emit(lane_idx, true))
		area.mouse_exited.connect(func(): lane_hovered.emit(lane_idx, false))

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
