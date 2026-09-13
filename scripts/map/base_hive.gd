class_name BaseHive
extends Node3D

@export var is_enemy: bool = false
@export var base_name: String = "Улей Муравьев"
@export var max_health: float = 1000.0

var current_health: float = 1000.0

@onready var label: Label3D = $Label3D
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	current_health = max_health
	if is_enemy:
		base_name = "Гнездо Термитов"
		if light:
			light.light_color = Color(1.0, 0.2, 0.1)
		if label:
			label.modulate = Color(1.0, 0.35, 0.3)
	else:
		if light:
			light.light_color = Color(0.2, 1.0, 0.4)
		if label:
			label.modulate = Color(0.4, 1.0, 0.5)
	_update_label()

func _update_label() -> void:
	if label:
		label.text = "%s\n%d / %d HP" % [base_name, int(current_health), int(max_health)]
