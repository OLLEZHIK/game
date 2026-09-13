class_name FlowerProp
extends Node3D

signal nectar_dropped(drop_pos: Vector3, lane_idx: int)
signal nectar_harvested_by_bee()

@export var can_drop_nectar: bool = true
@export var drop_interval: float = 10.0
@export var reload_time: float = 8.0
@export var associated_lane_index: int = 2
@export var drop_target_z: float = 12.0

var has_nectar: bool = true
var is_reloading: bool = false
var nectar_timer: float = 0.0

# Bee single-reservation system: only 1 bee can target this flower!
var is_reserved_by_bee: bool = false
var reserving_bee: Node = null

@onready var droplet_mesh: MeshInstance3D = $NectarDroplet if has_node("NectarDroplet") else null
@onready var nectar_light: OmniLight3D = $NectarLight if has_node("NectarLight") else null

var _initial_droplet_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	if droplet_mesh:
		_initial_droplet_scale = droplet_mesh.scale
	# Read balance settings if available
	drop_interval = GameBalance.FLOWER_DROP_INTERVAL
	reload_time = GameBalance.FLOWER_RELOAD_TIME
	# Stagger initial timers so flowers don't drop at the exact same second
	nectar_timer = randf_range(2.0, 7.0)
	_update_visuals()

func can_be_targeted_by_bee() -> bool:
	return has_nectar and not is_reserved_by_bee

func reserve_for_bee(bee: Node) -> bool:
	if not can_be_targeted_by_bee():
		return false
	is_reserved_by_bee = true
	reserving_bee = bee
	return true

func release_bee_reservation(bee: Node = null) -> void:
	if reserving_bee == bee or bee == null:
		is_reserved_by_bee = false
		reserving_bee = null

func _process(delta: float) -> void:
	if not can_drop_nectar:
		return

	# If reserving bee died or became invalid, release reservation
	if is_reserved_by_bee and not is_instance_valid(reserving_bee):
		release_bee_reservation()

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
	release_bee_reservation()
	_update_visuals()

	# Drop target coordinate on the dirt path of the lane
	var drop_pos = Vector3(global_position.x, 0.22, drop_target_z)
	
	var tree = get_tree()
	if tree:
		var main_node = tree.root.find_child("Main", true, false)
		if main_node and main_node.has_method("spawn_fallen_nectar_drop"):
			main_node.spawn_fallen_nectar_drop(drop_pos, associated_lane_index)

	nectar_dropped.emit(drop_pos, associated_lane_index)

	# Flower begins reload cooldown before new nectar appears
	is_reloading = true
	var tween = create_tween()
	tween.tween_interval(reload_time)
	tween.tween_callback(func():
		has_nectar = true
		is_reloading = false
		nectar_timer = 0.0
		_update_visuals()
	)

func harvest_by_bee() -> bool:
	if not has_nectar:
		return false

	has_nectar = false
	is_reloading = true
	nectar_timer = 0.0
	release_bee_reservation()
	_update_visuals()
	nectar_harvested_by_bee.emit()

	# Reload cooldown before regenerating new nectar
	var tween = create_tween()
	tween.tween_interval(reload_time)
	tween.tween_callback(func():
		has_nectar = true
		is_reloading = false
		nectar_timer = 0.0
		_update_visuals()
	)
	return true

func _update_visuals() -> void:
	if droplet_mesh:
		droplet_mesh.visible = has_nectar
	if nectar_light:
		nectar_light.light_energy = 0.9 if has_nectar else 0.15
