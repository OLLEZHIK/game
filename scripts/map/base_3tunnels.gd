class_name Base3Tunnels
extends Node3D

signal tunnel_clicked(lane_index: int)

@export var is_enemy: bool = false
@export var base_name: String = "Муравейник"

@onready var tunnel_top_marker: Marker3D = $TunnelTop/MarkerTop
@onready var tunnel_mid_marker: Marker3D = $TunnelMid/MarkerMid
@onready var tunnel_bot_marker: Marker3D = $TunnelBot/MarkerBot

@onready var label_top: Label3D = $TunnelTop/LabelTop
@onready var label_mid: Label3D = $TunnelMid/LabelMid
@onready var label_bot: Label3D = $TunnelBot/LabelBot

@onready var light_top: OmniLight3D = $TunnelTop/LightTop
@onready var light_mid: OmniLight3D = $TunnelMid/LightMid
@onready var light_bot: OmniLight3D = $TunnelBot/LightBot

@onready var area_top: Area3D = $TunnelTop/ClickArea
@onready var area_mid: Area3D = $TunnelMid/ClickArea
@onready var area_bot: Area3D = $TunnelBot/ClickArea

var is_highlighted: bool = false

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

	if not is_enemy:
		if area_top:
			area_top.input_event.connect(func(_cam, ev, _p, _n, _s): _handle_input(0, ev))
			area_top.mouse_entered.connect(func(): _on_tunnel_hover(0, true))
			area_top.mouse_exited.connect(func(): _on_tunnel_hover(0, false))
		if area_mid:
			area_mid.input_event.connect(func(_cam, ev, _p, _n, _s): _handle_input(1, ev))
			area_mid.mouse_entered.connect(func(): _on_tunnel_hover(1, true))
			area_mid.mouse_exited.connect(func(): _on_tunnel_hover(1, false))
		if area_bot:
			area_bot.input_event.connect(func(_cam, ev, _p, _n, _s): _handle_input(2, ev))
			area_bot.mouse_entered.connect(func(): _on_tunnel_hover(2, true))
			area_bot.mouse_exited.connect(func(): _on_tunnel_hover(2, false))

func _handle_input(lane_idx: int, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		tunnel_clicked.emit(lane_idx)
		_play_tunnel_click_fx(lane_idx)

func _on_tunnel_hover(lane_idx: int, is_hover: bool) -> void:
	var light = [light_top, light_mid, light_bot][lane_idx]
	if light:
		light.light_energy = 2.5 if is_hover else (1.6 if is_highlighted else 1.1)

func set_highlight_for_deployment(enabled: bool) -> void:
	is_highlighted = enabled
	for light in [light_top, light_mid, light_bot]:
		if light:
			light.light_energy = 1.8 if enabled else 1.1
			light.light_color = Color(1.0, 0.9, 0.2) if enabled else Color(0.4, 1.0, 0.5)
	
	if enabled:
		label_top.text = "▼ ВЕРХ (1) ▼"
		label_mid.text = "▼ ЦЕНТР (2) ▼"
		label_bot.text = "▼ НИЗ (3) ▼"
	else:
		label_top.text = "Туннель 1 (Верх)"
		label_mid.text = "Туннель 2 (Центр)"
		label_bot.text = "Туннель 3 (Низ)"

func _play_tunnel_click_fx(lane_idx: int) -> void:
	var mound_node = [get_node_or_null("TunnelTop/Mound"), get_node_or_null("TunnelMid/Mound"), get_node_or_null("TunnelBot/Mound")][lane_idx]
	if mound_node:
		var tween = create_tween()
		tween.tween_property(mound_node, "scale", Vector3(1.15, 1.15, 1.15), 0.08)
		tween.tween_property(mound_node, "scale", Vector3(1.0, 1.0, 1.0), 0.12)

func get_tunnel_spawn_position(lane_idx: int) -> Vector3:
	match lane_idx:
		0:
			return tunnel_top_marker.global_position if tunnel_top_marker else global_position + Vector3(0, 0, -12)
		1:
			return tunnel_mid_marker.global_position if tunnel_mid_marker else global_position
		2:
			return tunnel_bot_marker.global_position if tunnel_bot_marker else global_position + Vector3(0, 0, 12)
	return global_position
