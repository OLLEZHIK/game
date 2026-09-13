class_name FallenNectarDrop
extends Area3D

signal collected(by_who: Node)

@export var nectar_value: int = 30
@export var lane_index: int = 0

var is_collected: bool = false
var _bob_timer: float = 0.0
var _base_y: float = 0.22

@onready var visual: Node3D = $Visual
@onready var light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null

func _ready() -> void:
	_base_y = position.y
	input_ray_pickable = true
	input_event.connect(_on_input_event)
	
	# Spawn drop animation (fall and bounce)
	position.y = 1.6
	var tween = create_tween()
	tween.tween_property(self, "position:y", _base_y, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if is_collected:
		return
	_bob_timer += delta
	# Gentle floating bob and slight spin
	if visual:
		visual.position.y = sin(_bob_timer * 4.0) * 0.06
		visual.rotation.y += delta * 1.5

func collect(collector: Node = null) -> int:
	if is_collected:
		return 0
	is_collected = true
	collected.emit(collector)

	# Sound/Visual pop tween on visual child
	if visual:
		var tween = create_tween()
		tween.tween_property(visual, "scale", Vector3(1.35, 1.35, 1.35), 0.1)
		tween.parallel().tween_property(visual, "position:y", visual.position.y + 0.5, 0.2)
		tween.tween_property(visual, "scale", Vector3(0.05, 0.05, 0.05), 0.12)
		tween.tween_callback(queue_free)
	else:
		queue_free()
	return nectar_value

func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Direct player click collection!
		var main_node = get_tree().root.find_child("Main", true, false)
		if main_node and "nectar" in main_node:
			main_node.nectar += collect(main_node)
			main_node._update_hud()
			if main_node.has_method("show_notice"):
				main_node.show_notice("🍯 Собрана капля нектара (+30🍯)!", Color(1.0, 0.9, 0.2))
