class_name FlowerProp
extends Node3D

signal nectar_dropped(drop_pos: Vector3, lane_idx: int)
signal nectar_harvested_by_bee()

@export var can_drop_nectar: bool = true
@export var drop_interval: float = 10.0
@export var associated_lane_index: int = 2
@export var drop_target_z: float = 12.0

var has_nectar: bool = true
var nectar_timer: float = 0.0

@onready var droplet_mesh: MeshInstance3D = $NectarDroplet if has_node("NectarDroplet") else null
@onready var nectar_light: OmniLight3D = $NectarLight if has_node("NectarLight") else null

var _initial_droplet_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	if droplet_mesh:
		_initial_droplet_scale = droplet_mesh.scale
	# Stagger initial timers so flowers don't drop at the exact same second
	nectar_timer = randf_range(2.0, 7.0)
	_update_visuals()

func _process(delta: float) -> void:
	if not can_drop_nectar:
		return

	if has_nectar:
		nectar_timer += delta
		
		# Visual growth and glowing pulse as nectar accumulates
		if droplet_mesh:
			var ratio = clampf(nectar_timer / drop_interval, 0.35, 1.0)
			var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.007) * 0.1
			droplet_mesh.scale = _initial_droplet_scale * ratio * pulse

		if nectar_light:
			nectar_light.light_energy = 0.6 + (nectar_timer / drop_interval) * 0.6

		# Once 10 seconds pass without a bee collecting, drop to the lane path!
		if nectar_timer >= drop_interval:
			drop_nectar_onto_path()

func drop_nectar_onto_path() -> void:
	has_nectar = false
	nectar_timer = 0.0
	_update_visuals()

	# Drop target coordinate on the dirt path of the lane
	var drop_pos = Vector3(global_position.x, 0.22, drop_target_z)
	
	var tree = get_tree()
	if tree:
		var main_node = tree.root.find_child("Main", true, false)
		if main_node and main_node.has_method("spawn_fallen_nectar_drop"):
			main_node.spawn_fallen_nectar_drop(drop_pos, associated_lane_index)

	nectar_dropped.emit(drop_pos, associated_lane_index)

	# Flower begins regenerating a new nectar drop after 4 seconds
	var tween = create_tween()
	tween.tween_interval(4.0)
	tween.tween_callback(func():
		has_nectar = true
		nectar_timer = 0.0
		_update_visuals()
	)

func harvest_by_bee() -> bool:
	if not has_nectar:
		return false

	has_nectar = false
	nectar_timer = 0.0
	_update_visuals()
	nectar_harvested_by_bee.emit()

	# Regrow nectar after gathering
	var tween = create_tween()
	tween.tween_interval(4.5)
	tween.tween_callback(func():
		has_nectar = true
		nectar_timer = 0.0
		_update_visuals()
	)
	return true

func _update_visuals() -> void:
	if droplet_mesh:
		droplet_mesh.visible = has_nectar
	if nectar_light:
		nectar_light.light_energy = 0.9 if has_nectar else 0.15
