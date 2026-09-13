class_name BugUnit
extends CharacterBody3D

signal unit_selected(unit: BugUnit)
signal unit_died(unit: BugUnit)

enum UnitRole {
	HARVESTER,   # Рабочий: идет за нектаром, возвращается в улей
	TANK,        # Танк (Жук-носорог): держит линию, поглощает урон
	WOODCUTTER,  # Лесоруб (Жук-усач): пилит поваленные бревна
	SOLDIER      # Воин термитов: атакует врагов и базу
}

enum UnitState {
	MARCHING,
	HARVESTING,
	SAWING,
	FIGHTING,
	RETURNING,
	DEAD
}

@export var unit_name: String = "Муравей-Рабочий"
@export var role: UnitRole = UnitRole.HARVESTER
@export var is_enemy: bool = false
@export var max_health: float = 60.0
@export var move_speed: float = 3.5
@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 1.0

var current_health: float = 60.0
var current_state: UnitState = UnitState.MARCHING
var lane_index: int = 1

var path_curve: Curve3D = null
var progress_dist: float = 0.0
var path_total_len: float = 1.0
var march_direction: float = 1.0 # 1.0 for Allied (West -> East), -1.0 for Enemy

var carried_nectar: int = 0
var target_obstacle: LaneObstacle = null
var target_enemy: BugUnit = null
var _attack_timer: float = 0.0

@onready var body_mesh: Node3D = $Visuals/BodyMesh
@onready var hp_label: Label3D = $HpLabel
@onready var selection_ring: Decal = $SelectionRing if has_node("SelectionRing") else null

var _walk_anim_time: float = 0.0

func _ready() -> void:
	current_health = max_health
	input_ray_pickable = true
	input_event.connect(_on_input_event)
	_update_hp_display()

func initialize_on_lane(curve: Curve3D, lane_idx: int, enemy: bool) -> void:
	path_curve = curve
	lane_index = lane_idx
	is_enemy = enemy
	march_direction = -1.0 if is_enemy else 1.0
	
	if path_curve:
		path_total_len = path_curve.get_baked_length()
		progress_dist = path_total_len if is_enemy else 0.0
		_update_position_from_progress()

func _process(delta: float) -> void:
	if current_state == UnitState.DEAD:
		return

	_walk_anim_time += delta * move_speed * 4.0
	_attack_timer = maxf(0.0, _attack_timer - delta)

	match current_state:
		UnitState.MARCHING:
			_process_marching(delta)
		UnitState.HARVESTING:
			_process_harvesting(delta)
		UnitState.RETURNING:
			_process_returning(delta)
		UnitState.SAWING:
			_process_sawing(delta)
		UnitState.FIGHTING:
			_process_fighting(delta)

func _process_marching(delta: float) -> void:
	# Check for obstacle on Mid lane for woodcutters
	if role == UnitRole.WOODCUTTER and target_obstacle and not target_obstacle.is_cleared:
		var dist_to_obs = global_position.distance_to(target_obstacle.global_position)
		if dist_to_obs <= 2.8:
			current_state = UnitState.SAWING
			return

	# Harvester: check for fallen nectar on this lane path
	if role == UnitRole.HARVESTER and not is_enemy:
		var drop = _find_nearest_fallen_drop()
		if drop:
			carried_nectar = drop.collect(self)
			current_state = UnitState.RETURNING
			march_direction = -1.0 # head back to base
			_update_hp_display()
			var main_game = get_tree().root.find_child("Main", true, false)
			if main_game and main_game.has_method("show_notice"):
				main_game.show_notice("🐜 Муравей подобрал упавший нектар (+%d🍯)!" % carried_nectar, Color(0.4, 1.0, 0.5))
			return

		# Also check if reached flower glade on bottom lane
		if lane_index == 2 and progress_dist >= path_total_len * 0.48:
			current_state = UnitState.HARVESTING
			_attack_timer = 2.5 # harvesting duration
			return

	# Check for enemy encounter
	var enemy = _find_nearest_enemy_on_lane()
	if enemy:
		target_enemy = enemy
		current_state = UnitState.FIGHTING
		return

	# Move along curve
	progress_dist += march_direction * move_speed * delta
	progress_dist = clampf(progress_dist, 0.0, path_total_len)
	_update_position_from_progress()
	_apply_procedural_walk()

	# Reached end of path
	if (not is_enemy and progress_dist >= path_total_len) or (is_enemy and progress_dist <= 0.0):
		# Reached opposing base
		queue_free()

func _find_nearest_fallen_drop() -> Area3D:
	var tree = get_tree()
	if not tree:
		return null
	var main_node = tree.root.find_child("Main", true, false)
	if not main_node or not ("fallen_nectar_drops" in main_node):
		return null
	
	for drop in main_node.fallen_nectar_drops:
		if is_instance_valid(drop) and not drop.is_collected:
			if drop.lane_index == lane_index:
				if global_position.distance_to(drop.global_position) <= 2.5:
					return drop
	return null

func _find_nearest_enemy_on_lane() -> CharacterBody3D:
	var tree = get_tree()
	if not tree:
		return null
	var main_node = tree.root.find_child("Main", true, false)
	if not main_node or not ("active_units" in main_node):
		return null
	
	for other in main_node.active_units:
		if is_instance_valid(other) and other != self:
			if ("is_enemy" in other) and (other.is_enemy != is_enemy):
				if ("lane_index" in other) and other.lane_index == lane_index:
					if ("current_state" in other) and other.current_state != UnitState.DEAD:
						if global_position.distance_to(other.global_position) <= 2.2:
							return other
	return null

func _process_harvesting(delta: float) -> void:
	# Wobble animation while drinking nectar
	if body_mesh:
		body_mesh.position.y = sin(_walk_anim_time * 2.0) * 0.06
		body_mesh.rotation.z = cos(_walk_anim_time * 2.0) * 0.08
	
	if _attack_timer <= 0.0:
		carried_nectar = 25
		current_state = UnitState.RETURNING
		march_direction = -1.0 # head back to base
		_update_hp_display()

func _process_returning(delta: float) -> void:
	progress_dist += march_direction * (move_speed * 0.85) * delta # carrying load
	progress_dist = clampf(progress_dist, 0.0, path_total_len)
	_update_position_from_progress()
	_apply_procedural_walk()

	if progress_dist <= 0.0:
		# Returned to base!
		var main_game = get_tree().root.find_child("Main", true, false)
		if main_game and "nectar" in main_game:
			main_game.nectar += carried_nectar
			main_game._update_hud()
		# Turn back to gather again
		carried_nectar = 0
		march_direction = 1.0
		current_state = UnitState.MARCHING
		_update_hp_display()

func _process_sawing(delta: float) -> void:
	if not target_obstacle or target_obstacle.is_cleared:
		current_state = UnitState.MARCHING
		return
		
	# Sawing animation: rapid forward and backward jaw motion
	if body_mesh:
		body_mesh.position.z = sin(_walk_anim_time * 4.0) * 0.12
		
	if _attack_timer <= 0.0:
		_attack_timer = 0.5
		target_obstacle.apply_sawing_damage(18.0)

func _process_fighting(_delta: float) -> void:
	if not is_instance_valid(target_enemy) or target_enemy.current_state == UnitState.DEAD:
		target_enemy = null
		current_state = UnitState.MARCHING
		return
		
	# Attack animation: lunge
	if body_mesh:
		body_mesh.position.z = sin(_walk_anim_time * 5.0) * 0.15
		
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		target_enemy.take_damage(attack_damage)

func _update_position_from_progress() -> void:
	if not path_curve:
		return
	var pos = path_curve.sample_baked(progress_dist)
	global_position = pos
	
	# Compute facing direction
	var look_dist = progress_dist + (march_direction * 0.5)
	if look_dist >= 0.0 and look_dist <= path_total_len:
		var next_pos = path_curve.sample_baked(look_dist)
		var dir = (next_pos - pos).normalized()
		if dir.length_squared() > 0.001:
			var target_yaw = atan2(-dir.x, -dir.z)
			rotation.y = target_yaw

func _apply_procedural_walk() -> void:
	if not body_mesh:
		return
	# Gentle waddling & bobbing walk cycle
	body_mesh.position.y = absf(sin(_walk_anim_time)) * 0.08
	body_mesh.rotation.z = sin(_walk_anim_time) * 0.06

func take_damage(amount: float) -> void:
	if current_state == UnitState.DEAD:
		return
	current_health = maxf(0.0, current_health - amount)
	_update_hp_display()
	if current_health <= 0.0:
		die()

func die() -> void:
	current_state = UnitState.DEAD
	unit_died.emit(self)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK)
	await tween.finished
	queue_free()

func _update_hp_display() -> void:
	if hp_label:
		if carried_nectar > 0:
			hp_label.text = "%s [%d HP]\n🍯 +%d Нектара" % [unit_name, int(current_health), carried_nectar]
			hp_label.modulate = Color(1.0, 0.9, 0.2)
		else:
			hp_label.text = "%s [%d/%d HP]" % [unit_name, int(current_health), int(max_health)]
			hp_label.modulate = Color(1.0, 0.35, 0.3) if is_enemy else Color(0.4, 1.0, 0.5)

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		unit_selected.emit(self)
