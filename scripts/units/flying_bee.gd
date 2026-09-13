class_name FlyingBee
extends CharacterBody3D

signal unit_selected(unit: FlyingBee)
signal unit_died(unit: FlyingBee)

enum BeeState {
	FLYING_TO_FLOWER,
	GATHERING,
	RETURNING_HOME,
	MANUAL_MOVE,
	MANUAL_ATTACK,
	DEAD
}

@export var unit_name: String = "Медоносная Пчелка"
@export var is_enemy: bool = false
@export var move_speed: float = 5.5
@export var flight_height: float = 2.4
@export var max_health: float = 50.0
@export var attack_damage: float = 12.0
@export var attack_cooldown: float = 0.8

var current_health: float = 50.0
var current_state: BeeState = BeeState.FLYING_TO_FLOWER

var carried_nectar: int = 0
var target_flower_pos: Vector3 = Vector3.ZERO
var home_hive_pos: Vector3 = Vector3(-7.5, 0.0, 0.0)
var gather_timer: float = 0.0
var target_flower_node: Node = null

# Micro-control system (5-second manual command window)
var is_under_manual_control: bool = false
var manual_control_timer: float = 0.0
var manual_target_pos: Vector3 = Vector3.ZERO
var manual_target_node: Node3D = null

var _attack_timer: float = 0.0
var _flower_check_timer: float = 0.0
var _anim_time: float = 0.0

@onready var visuals: Node3D = $Visuals if has_node("Visuals") else null
@onready var wing_left: Node3D = $Visuals/WingLeft if has_node("Visuals/WingLeft") else null
@onready var wing_right: Node3D = $Visuals/WingRight if has_node("Visuals/WingRight") else null
@onready var hp_label: Label3D = $HpLabel if has_node("HpLabel") else null

func _ready() -> void:
	current_health = max_health
	input_ray_pickable = true
	input_event.connect(_on_input_event)
	if is_enemy:
		home_hive_pos = Vector3(21.5, 0.0, 0.0)
		unit_name = "Вражеская Пчелка"
		_apply_enemy_visuals()
	_update_hp_display()
	pick_next_flower()

func initialize_bee(spawn_pos: Vector3, hive_pos: Vector3) -> void:
	home_hive_pos = hive_pos
	global_position = spawn_pos + Vector3(0, flight_height, 0)
	pick_next_flower()

func _apply_enemy_visuals() -> void:
	if has_node("Visuals/Body"):
		var b = get_node("Visuals/Body") as MeshInstance3D
		if b and b.material_override:
			var mat = b.material_override.duplicate() as StandardMaterial3D
			if mat:
				mat.albedo_color = Color(0.85, 0.2, 0.15)
				b.material_override = mat

func _process(delta: float) -> void:
	if current_state == BeeState.DEAD:
		return

	_anim_time += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)

	# Wing flap animation
	if wing_left and wing_right:
		var flap = sin(_anim_time * 50.0) * 0.45
		wing_left.rotation.z = flap
		wing_right.rotation.z = -flap

	# Gentle hovering bob
	if visuals:
		visuals.position.y = sin(_anim_time * 6.0) * 0.12

	# Manual control timer countdown: auto-reverts to autonomous AI after 5s of inactivity
	if is_under_manual_control:
		manual_control_timer -= delta
		if manual_control_timer <= 0.0:
			is_under_manual_control = false
			if current_state == BeeState.MANUAL_MOVE or current_state == BeeState.MANUAL_ATTACK:
				if carried_nectar > 0:
					current_state = BeeState.RETURNING_HOME
				else:
					pick_next_flower()

	# Dynamic mid-flight reroute: if flower lost its nectar while bee was flying, immediately retarget nearest!
	if current_state == BeeState.FLYING_TO_FLOWER and not is_under_manual_control:
		_flower_check_timer += delta
		if _flower_check_timer >= 0.2:
			_flower_check_timer = 0.0
			if target_flower_node and is_instance_valid(target_flower_node):
				if not target_flower_node.has_nectar:
					target_flower_node.release_bee_reservation(self)
					pick_next_flower()

	match current_state:
		BeeState.FLYING_TO_FLOWER:
			_process_flying_to_target(target_flower_pos, delta)
		BeeState.GATHERING:
			_process_gathering(delta)
		BeeState.RETURNING_HOME:
			_process_flying_to_target(home_hive_pos + Vector3(0, flight_height, 0), delta)
		BeeState.MANUAL_MOVE:
			_process_flying_to_target(manual_target_pos, delta)
		BeeState.MANUAL_ATTACK:
			_process_manual_attack(delta)

func _process_flying_to_target(target: Vector3, delta: float) -> void:
	var target_air_pos = Vector3(target.x, flight_height, target.z)
	var dir = target_air_pos - global_position
	var dist = dir.length()

	if dist > 0.4:
		dir = dir.normalized()
		global_position += dir * move_speed * delta
		var target_yaw = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)
	else:
		# Reached target
		if current_state == BeeState.FLYING_TO_FLOWER:
			current_state = BeeState.GATHERING
			gather_timer = 2.0
		elif current_state == BeeState.RETURNING_HOME:
			_deliver_nectar_to_hive()
		elif current_state == BeeState.MANUAL_MOVE:
			# Arrived at manual point: hover until 5s expires or new order given
			pass

func _process_manual_attack(delta: float) -> void:
	if not is_instance_valid(manual_target_node) or ("current_health" in manual_target_node and manual_target_node.current_health <= 0.0):
		manual_target_node = null
		current_state = BeeState.RETURNING_HOME if carried_nectar > 0 else BeeState.FLYING_TO_FLOWER
		pick_next_flower()
		return

	var enemy_pos = manual_target_node.global_position
	var target_pos = Vector3(enemy_pos.x, flight_height, enemy_pos.z)
	var dir = target_pos - global_position
	var dist = dir.length()

	if dist > 1.8:
		dir = dir.normalized()
		global_position += dir * move_speed * delta
		var target_yaw = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)
	else:
		# Attack with sting!
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_perform_sting_attack(manual_target_node)

func _perform_sting_attack(target: Node) -> void:
	if visuals:
		var tw = create_tween()
		tw.tween_property(visuals, "position:z", visuals.position.z - 0.4, 0.08)
		tw.tween_property(visuals, "position:z", 0.0, 0.12)
	if target and target.has_method("take_damage"):
		target.take_damage(attack_damage)

func _process_gathering(delta: float) -> void:
	gather_timer -= delta
	if gather_timer <= 0.0:
		carried_nectar = 30
		if target_flower_node and is_instance_valid(target_flower_node) and target_flower_node.has_method("harvest_by_bee"):
			target_flower_node.harvest_by_bee()
		current_state = BeeState.RETURNING_HOME
		_update_hp_display()

func _deliver_nectar_to_hive() -> void:
	if is_enemy:
		carried_nectar = 0
		_update_hp_display()
		pick_next_flower()
	else:
		var main_game = get_tree().root.find_child("Main", true, false)
		if main_game and "nectar" in main_game:
			main_game.nectar += carried_nectar
			main_game._update_hud()
			if main_game.has_method("show_notice"):
				main_game.show_notice("🐝 Пчелка доставила +%d🍯 нектара в улей!" % carried_nectar, Color(1, 0.9, 0.2))
		carried_nectar = 0
		_update_hp_display()
		pick_next_flower()

## Pick nearest flower with nectar (Action towards nearest object)
func pick_next_flower() -> void:
	current_state = BeeState.FLYING_TO_FLOWER
	target_flower_node = _find_flower_with_nectar()
	if target_flower_node:
		target_flower_pos = target_flower_node.global_position
	else:
		# No nectar right now, hover near center/hive
		target_flower_pos = home_hive_pos + Vector3(6.0 if not is_enemy else -6.0, 0, 0)

func _find_flower_with_nectar() -> Node:
	var tree = get_tree()
	if not tree:
		return null
	var daisies_node = tree.root.find_child("Daisies", true, false)
	if not daisies_node:
		return null
	var ready_flowers: Array[Node] = []
	for child in daisies_node.get_children():
		if child.has_method("can_be_targeted_by_bee") and child.can_be_targeted_by_bee():
			ready_flowers.append(child)
		elif ("has_nectar" in child) and child.has_nectar and not ("is_reserved_by_bee" in child and child.is_reserved_by_bee):
			ready_flowers.append(child)

	if ready_flowers.size() > 0:
		# SORT BY DISTANCE TO THIS BEE: ACTION TO NEAREST OBJECT!
		ready_flowers.sort_custom(func(a: Node, b: Node):
			return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
		)
		var chosen = ready_flowers[0]
		if chosen.has_method("reserve_for_bee"):
			chosen.reserve_for_bee(self)
		return chosen
	return null

# Micro-control orders
func order_move_to_position(target: Vector3) -> void:
	is_under_manual_control = true
	manual_control_timer = 5.0
	manual_target_pos = target
	manual_target_node = null
	current_state = BeeState.MANUAL_MOVE
	if target_flower_node and is_instance_valid(target_flower_node) and target_flower_node.has_method("release_bee_reservation"):
		target_flower_node.release_bee_reservation(self)
		target_flower_node = null

func order_target_flower(flower: Node3D) -> void:
	if not is_instance_valid(flower):
		return
	is_under_manual_control = true
	manual_control_timer = 5.0
	manual_target_node = flower
	target_flower_node = flower
	target_flower_pos = flower.global_position
	if flower.has_method("reserve_for_bee"):
		flower.reserve_for_bee(self)
	current_state = BeeState.FLYING_TO_FLOWER

func order_attack_target(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	is_under_manual_control = true
	manual_control_timer = 5.0
	manual_target_node = enemy
	current_state = BeeState.MANUAL_ATTACK
	if target_flower_node and is_instance_valid(target_flower_node) and target_flower_node.has_method("release_bee_reservation"):
		target_flower_node.release_bee_reservation(self)
		target_flower_node = null

func set_manual_control(duration: float = 5.0) -> void:
	is_under_manual_control = true
	manual_control_timer = duration

func take_damage(amount: float) -> void:
	if current_state == BeeState.DEAD:
		return
	current_health = maxf(0.0, current_health - amount)
	_update_hp_display()
	if current_health <= 0.0:
		die()

func die() -> void:
	current_state = BeeState.DEAD
	if target_flower_node and is_instance_valid(target_flower_node) and target_flower_node.has_method("release_bee_reservation"):
		target_flower_node.release_bee_reservation(self)
	unit_died.emit(self)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.35)
	await tween.finished
	queue_free()

func _update_hp_display() -> void:
	if hp_label:
		var prefix = "🐝 Враг Пчела" if is_enemy else "🐝 Пчелка"
		if is_under_manual_control:
			prefix = "🎯 " + prefix
		if carried_nectar > 0:
			hp_label.text = "%s [%d HP]\n🍯 +%d Нектара" % [prefix, int(current_health), carried_nectar]
			hp_label.modulate = Color(1.0, 0.9, 0.2)
		else:
			hp_label.text = "%s [%d/%d]" % [prefix, int(current_health), int(max_health)]
			hp_label.modulate = Color(1.0, 0.4, 0.3) if is_enemy else Color(0.4, 1.0, 0.5)

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		unit_selected.emit(self)
