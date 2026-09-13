class_name Base3Tunnels
extends Node3D

@export var is_enemy: bool = false
@export var base_name: String = "Муравейник"

@onready var tunnel_top_marker: Marker3D = $TunnelTop/MarkerTop
@onready var tunnel_mid_marker: Marker3D = $TunnelMid/MarkerMid
@onready var tunnel_bot_marker: Marker3D = $TunnelBot/MarkerBot

@onready var label_top: Label3D = $TunnelTop/LabelTop
@onready var label_mid: Label3D = $TunnelMid/LabelMid
@onready var label_bot: Label3D = $TunnelBot/LabelBot

func _ready() -> void:
	var prefix = "Враг: Туннель" if is_enemy else "Туннель"
	var col = Color(1.0, 0.35, 0.25) if is_enemy else Color(0.4, 1.0, 0.5)
	
	if label_top:
		label_top.text = "%s 1 (Верх)" % prefix
		label_top.modulate = col
	if label_mid:
		label_mid.text = "%s 2 (Центр)" % prefix
		label_mid.modulate = col
	if label_bot:
		label_bot.text = "%s 3 (Низ)" % prefix
		label_bot.modulate = col

func get_tunnel_spawn_position(lane_idx: int) -> Vector3:
	match lane_idx:
		0:
			return tunnel_top_marker.global_position if tunnel_top_marker else global_position + Vector3(0, 0, -12)
		1:
			return tunnel_mid_marker.global_position if tunnel_mid_marker else global_position
		2:
			return tunnel_bot_marker.global_position if tunnel_bot_marker else global_position + Vector3(0, 0, 12)
	return global_position
