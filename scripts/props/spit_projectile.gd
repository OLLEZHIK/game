class_name SpitProjectile
extends Node3D

@export var speed: float = 14.0
@export var damage: float = 22.0

var target_node: Node3D = null
var target_pos: Vector3 = Vector3.ZERO
var _is_flying: bool = true
var is_flying: bool:
	get: return _is_flying

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null

func launch(from_pos: Vector3, target: Node3D, dmg: float) -> void:
	if is_inside_tree():
		global_position = from_pos
	else:
		position = from_pos
	target_node = target
	damage = dmg
	if is_instance_valid(target_node):
		if target_node.is_inside_tree():
			target_pos = target_node.global_position + Vector3(0, 0.4, 0)
		else:
			target_pos = target_node.position + Vector3(0, 0.4, 0)
	_is_flying = true

func _process(delta: float) -> void:
	if not _is_flying:
		return

	if is_instance_valid(target_node):
		target_pos = target_node.global_position + Vector3(0, 0.4, 0)

	var dir = target_pos - global_position
	var dist = dir.length()
	
	if dist <= speed * delta or dist < 0.35:
		_impact()
	else:
		global_position += dir.normalized() * speed * delta

func _impact() -> void:
	_is_flying = false
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(damage)
		
	# Splash tween
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.6, 1.6, 1.6), 0.08)
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.1)
	tween.tween_callback(queue_free)
