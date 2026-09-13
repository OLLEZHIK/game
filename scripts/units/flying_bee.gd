class_name FlyingBee
extends CharacterBody3D

signal unit_selected(unit: FlyingBee)
signal unit_died(unit: FlyingBee)

enum BeeState {
	FLYING_TO_FLOWER,
	GATHERING,
	RETURNING_HOME,
	DEAD
}

@export var unit_name: String = "Медоносная Пчелка"
@export var move_speed: float = 5.5
@export var flight_height: float = 2.4
@export var max_health: float = 50.0

var current_health: float = 50.0
var current_state: BeeState = BeeState.FLYING_TO_FLOWER

var carried_nectar: int = 0
var target_flower_pos: Vector3 = Vector3.ZERO
var home_hive_pos: Vector3 = Vector3(-7.5, 0.0, 0.0)
var gather_timer: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var wing_left: Node3D = $Visuals/WingLeft
@onready var wing_right: Node3D = $Visuals/WingRight
@onready var hp_label: Label3D = $HpLabel

var _anim_time: float = 0.0

func _ready() -> void:
	current_health = max_health
	input_ray_pickable = true
	input_event.connect(_on_input_event)
	_update_hp_display()
	pick_next_flower()

func initialize_bee(spawn_pos: Vector3, hive_pos: Vector3) -> void:
	home_hive_pos = hive_pos
	global_position = spawn_pos + Vector3(0, flight_height, 0)
	pick_next_flower()

func _process(delta: float) -> void:
	if current_state == BeeState.DEAD:
		return

	_anim_time += delta

	# Fast wing flapping
	if wing_left and wing_right:
		var flap = sin(_anim_time * 50.0) * 0.45
		wing_left.rotation.z = flap
		wing_right.rotation.z = -flap

	# Gentle hovering bobbing
	if visuals:
		visuals.position.y = sin(_anim_time * 6.0) * 0.12

	match current_state:
		BeeState.FLYING_TO_FLOWER:
			_process_flying_to_target(target_flower_pos, delta)
		BeeState.GATHERING:
			_process_gathering(delta)
		BeeState.RETURNING_HOME:
			_process_flying_to_target(home_hive_pos + Vector3(0, flight_height, 0), delta)

func _process_flying_to_target(target: Vector3, delta: float) -> void:
	var target_air_pos = Vector3(target.x, flight_height, target.z)
	var dir = target_air_pos - global_position
	var dist = dir.length()

	if dist > 0.3:
		dir = dir.normalized()
		global_position += dir * move_speed * delta
		
		# Rotate towards flying direction
		var target_yaw = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)
	else:
		# Reached destination
		if current_state == BeeState.FLYING_TO_FLOWER:
			current_state = BeeState.GATHERING
			gather_timer = 2.2
		elif current_state == BeeState.RETURNING_HOME:
			# Deliver nectar to hive
			var main_game = get_tree().root.find_child("Main", true, false)
			if main_game and "nectar" in main_game:
				main_game.nectar += carried_nectar
				main_game._update_hud()
				if main_game.has_method("show_notice"):
					main_game.show_notice("🐝 Пчелка доставила +%d🍯 нектара в улей!" % carried_nectar, Color(1, 0.9, 0.2))
			carried_nectar = 0
			_update_hp_display()
			pick_next_flower()

func _process_gathering(delta: float) -> void:
	gather_timer -= delta
	if gather_timer <= 0.0:
		carried_nectar = 30
		current_state = BeeState.RETURNING_HOME
		_update_hp_display()

func pick_next_flower() -> void:
	current_state = BeeState.FLYING_TO_FLOWER
	# Targets across all 3 lanes (daisies)
	var flower_candidates = [
		Vector3(-6, 0, 10.5),   # Bot lane daisy 1
		Vector3(8, 0, 11.5),    # Bot lane daisy 2
		Vector3(-8, 0, -10.5),  # Top lane daisy 3
		Vector3(6, 0, -11.0),   # Top lane daisy 4
		Vector3(0, 0, 6.0)      # Mid-bot daisy 5
	]
	flower_candidates.shuffle()
	target_flower_pos = flower_candidates[0]

func take_damage(amount: float) -> void:
	if current_state == BeeState.DEAD:
		return
	current_health = maxf(0.0, current_health - amount)
	_update_hp_display()
	if current_health <= 0.0:
		die()

func die() -> void:
	current_state = BeeState.DEAD
	unit_died.emit(self)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.35)
	await tween.finished
	queue_free()

func _update_hp_display() -> void:
	if hp_label:
		if carried_nectar > 0:
			hp_label.text = "🐝 Пчелка [%d HP]\n🍯 +%d Нектара" % [int(current_health), carried_nectar]
			hp_label.modulate = Color(1.0, 0.9, 0.2)
		else:
			hp_label.text = "🐝 Пчелка [%d/%d]" % [int(current_health), int(max_health)]
			hp_label.modulate = Color(0.4, 1.0, 0.5)

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		unit_selected.emit(self)
