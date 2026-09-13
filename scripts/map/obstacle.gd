class_name LaneObstacle
extends Node3D

signal obstacle_cleared(obstacle: LaneObstacle)
signal obstacle_damaged(current_hp: float, max_hp: float)

@export var max_health: float = 120.0
@export var obstacle_name: String = "Поваленный сук"
@export var resource_reward: int = 45

var current_health: float = 120.0
var is_cleared: bool = false

@onready var collision_shape: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var mesh_instance: Node3D = $VisualMesh
@onready var hp_label: Label3D = $HpLabel

func _ready() -> void:
	current_health = max_health
	_update_label()

func apply_sawing_damage(amount: float) -> void:
	if is_cleared:
		return
	current_health = maxf(0.0, current_health - amount)
	obstacle_damaged.emit(current_health, max_health)
	_update_label()
	
	# Micro wobble / vibration feedback
	var tween = create_tween()
	tween.tween_property(mesh_instance, "position:y", 0.08, 0.04)
	tween.tween_property(mesh_instance, "position:y", 0.0, 0.04)
	
	if current_health <= 0.0:
		clear_obstacle()

func clear_obstacle() -> void:
	if is_cleared:
		return
	is_cleared = true
	obstacle_cleared.emit(self)
	
	# Play crumbling / splitting tween
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "scale", Vector3(0.01, 0.01, 0.01), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(hp_label, "modulate:a", 0.0, 0.3)
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		
	await tween.finished
	visible = false

func _update_label() -> void:
	if hp_label:
		hp_label.text = "%s: %d/%d HP\n(Нужен Лесоруб)" % [obstacle_name, int(current_health), int(max_health)]
		if is_cleared:
			hp_label.text = "РАСПИЛЕНО!"
