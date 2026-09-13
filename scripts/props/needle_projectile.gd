class_name NeedleProjectile
extends Node3D

@export var speed: float = 24.0
@export var damage: float = 14.0

var target_node: Node3D = null
var target_pos: Vector3 = Vector3.ZERO
var _is_flying: bool = true
var is_flying: bool:
	get: return _is_flying

@onready var mesh: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null

func launch(from_pos: Vector3, target: Node3D, dmg: float) -> void:
	if is_inside_tree():
		global_position = from_pos
	else:
		position = from_pos
	target_node = target
	damage = dmg
	if is_instance_valid(target_node):
		var offset = Vector3(0, 0.4, 0)
		target_pos = (target_node.global_position if target_node.is_inside_tree() else target_node.position) + offset
	_is_flying = true

func _process(delta: float) -> void:
	if not _is_flying:
		return

	if is_instance_valid(target_node):
		var offset = Vector3(0, 0.4, 0)
		target_pos = (target_node.global_position if target_node.is_inside_tree() else target_node.position) + offset

	var dir = target_pos - global_position
	var dist = dir.length()

	# Rotate needle along flight velocity
	if dir.length_squared() > 0.001:
		var target_yaw = atan2(-dir.x, -dir.z)
		rotation.y = target_yaw
		rotation.x = atan2(dir.y, sqrt(dir.x * dir.x + dir.z * dir.z))

	if dist <= speed * delta or dist < 0.4:
		_impact()
	else:
		global_position += dir.normalized() * speed * delta

func _impact() -> void:
	_is_flying = false
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(damage)

	# Puncture impact flash
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.8, 0.2, 1.8), 0.06)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.08)
	tween.tween_callback(queue_free)
