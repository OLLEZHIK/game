class_name FlowerProp
extends Node3D

signal nectar_dropped(drop_pos: Vector3, lane_idx: int)
signal nectar_harvested_by_bee()

@export var can_drop_nectar: bool = true
@export var drop_interval: float = 10.0
@export var reload_time: float = 8.0
@export var associated_lane_index: int = 2
@export var drop_target_z: float = 12.0
@export var stem_height: float = 1.85 ## Height of flower stem/head. Higher stem = larger drop scatter radius!
@export var scatter_radius_factor: float = 2.0 ## Radius multiplier per meter of stem height

var has_nectar: bool = true
var is_reloading: bool = false
var nectar_timer: float = 0.0

# Bee single-reservation system: only 1 bee can target this flower!
var is_reserved_by_bee: bool = false
var reserving_bee: Node = null

const NECTAR_MAT = preload("res://assets/materials/mat_nectar.tres")

@onready var droplet_mesh: MeshInstance3D = $NectarDroplet if has_node("NectarDroplet") else null
@onready var nectar_light: OmniLight3D = $NectarLight if has_node("NectarLight") else null
@onready var center_dome: MeshInstance3D = $CenterDome if has_node("CenterDome") else null
@onready var petals: Node3D = $Petals if has_node("Petals") else null

var _initial_droplet_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	if droplet_mesh:
		_initial_droplet_scale = droplet_mesh.scale
	# Read balance settings if available
	drop_interval = GameBalance.FLOWER_DROP_INTERVAL
	reload_time = GameBalance.FLOWER_RELOAD_TIME
	# Stagger initial timers so flowers don't drop at the exact same second
	nectar_timer = randf_range(2.0, 7.0)
	set_stem_height(stem_height)
	_update_visuals()

func get_head_height() -> float:
	if center_dome:
		return center_dome.position.y * scale.y
	elif droplet_mesh:
		return droplet_mesh.position.y * scale.y
	return stem_height * scale.y

## Radius increases proportionally with stem / head height
func get_scatter_radius() -> float:
	var h = get_head_height()
	if h <= 0.1:
		h = stem_height
	return max(1.2, h * scatter_radius_factor)

func set_stem_height(height: float) -> void:
	stem_height = max(0.8, height)
	var ratio = stem_height / 1.85
	if has_node("Stem"):
		var stem = get_node("Stem") as Node3D
		stem.scale.y = ratio
		stem.position.y = 0.7 * ratio
	if has_node("CenterDome"):
		var dome = get_node("CenterDome") as Node3D
		dome.position.y = 1.45 * ratio
	if has_node("Petals"):
		var p = get_node("Petals") as Node3D
		p.position.y = 1.4 * ratio
	if has_node("NectarDroplet"):
		var dr = get_node("NectarDroplet") as Node3D
		dr.position.y = 1.85 * ratio

func can_be_targeted_by_bee() -> bool:
	return has_nectar and not is_reserved_by_bee

func reserve_for_bee(bee: Node) -> bool:
	if not can_be_targeted_by_bee():
		return false
	is_reserved_by_bee = true
	reserving_bee = bee
	return true

func release_bee_reservation(bee: Node = null) -> void:
	if reserving_bee == bee or bee == null:
		is_reserved_by_bee = false
		reserving_bee = null

func _process(delta: float) -> void:
	if not can_drop_nectar:
		return

	# If reserving bee died or became invalid, release reservation
	if is_reserved_by_bee and not is_instance_valid(reserving_bee):
		release_bee_reservation()

	if has_nectar:
		nectar_timer += delta
		
		# Visual growth and glowing pulse as nectar accumulates
		if droplet_mesh:
			var ratio = clampf(nectar_timer / drop_interval, 0.35, 1.0)
			var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.007) * 0.1
			droplet_mesh.scale = _initial_droplet_scale * ratio * pulse

		if nectar_light:
			nectar_light.light_energy = 0.6 + (nectar_timer / drop_interval) * 0.6

		# Once 10 seconds pass without a bee collecting, drop to the lane path!
		if nectar_timer >= drop_interval:
			drop_nectar_onto_path()

func drop_nectar_onto_path() -> void:
	if is_reloading or not has_nectar:
		return
	has_nectar = false
	is_reloading = true
	nectar_timer = 0.0
	release_bee_reservation()

	# 1. Random position along the lane within radius proportional to stem height
	var scatter_rad = get_scatter_radius()
	var rand_x = clampf(global_position.x + randf_range(-scatter_rad, scatter_rad), -4.0, 18.0)
	var rand_z = drop_target_z + randf_range(-0.4, 0.4)
	var raw_drop_pos = Vector3(rand_x, 0.22, rand_z)

	# 2. Anti-stacking: check existing & in-flight drops so it lands adjacent without overlap ("впритык, но рядом")
	var final_drop_pos = raw_drop_pos
	var main_node = get_tree().root.find_child("Main", true, false)
	if main_node and main_node.has_method("reserve_unstacked_drop_position"):
		final_drop_pos = main_node.reserve_unstacked_drop_position(raw_drop_pos, drop_target_z)

	_animate_spit_and_splash(final_drop_pos)

func _animate_spit_and_splash(drop_pos: Vector3) -> void:
	# 1. Daisy flower squash & spring recoil ("выплёвывание")
	var daisy_tw = create_tween()
	
	# Squash down (inhale / coil up)
	if center_dome:
		daisy_tw.parallel().tween_property(center_dome, "scale", Vector3(1.35, 0.55, 1.35), 0.14).set_trans(Tween.TRANS_BACK)
	if petals:
		daisy_tw.parallel().tween_property(petals, "scale", Vector3(1.25, 0.65, 1.25), 0.14).set_trans(Tween.TRANS_BACK)

	# POP! Spring up and fling the droplet out
	daisy_tw.chain().tween_callback(func():
		_update_visuals()
		_launch_spit_blob(drop_pos)
	)
	
	# Elastic recoil bounce
	if center_dome:
		daisy_tw.parallel().tween_property(center_dome, "scale", Vector3(0.85, 1.45, 0.85), 0.12).set_trans(Tween.TRANS_ELASTIC)
		daisy_tw.parallel().tween_property(center_dome, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC)
	if petals:
		daisy_tw.parallel().tween_property(petals, "scale", Vector3(0.85, 1.35, 0.85), 0.12).set_trans(Tween.TRANS_ELASTIC)
		daisy_tw.parallel().tween_property(petals, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC)

func _launch_spit_blob(target_pos: Vector3) -> void:
	var tree = get_tree()
	if not tree:
		return

	var main_node = tree.root.find_child("Main", true, false)
	var spawn_parent = main_node if main_node else get_parent()

	# Flying nectar blob (bright honey droplet)
	var blob = MeshInstance3D.new()
	var s_mesh = SphereMesh.new()
	s_mesh.radius = 0.38
	s_mesh.height = 0.58
	s_mesh.material = NECTAR_MAT
	blob.mesh = s_mesh

	var bl_light = OmniLight3D.new()
	bl_light.light_color = Color(1.0, 0.85, 0.25)
	bl_light.light_energy = 2.0
	bl_light.omni_range = 3.0
	blob.add_child(bl_light)

	spawn_parent.add_child(blob)
	var start_pos = global_position + Vector3(0, stem_height, 0)
	blob.global_position = start_pos

	var flight_tw = create_tween()
	var flight_duration = 0.55
	var arc_peak = max(2.5, stem_height * 1.6)
	flight_tw.tween_method(func(t: float):
		if is_instance_valid(blob):
			var cur = start_pos.lerp(target_pos, t)
			cur.y += sin(t * PI) * arc_peak # High ballistic ejection arc scaling with stem height!
			blob.global_position = cur
			if t < 0.5:
				blob.scale = Vector3(0.8, 1.4, 0.8) # Stretched along flight path
			else:
				blob.scale = Vector3(1.3, 0.75, 1.3) # Squashing down before impact
	, 0.0, 1.0, flight_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	flight_tw.tween_callback(func():
		if is_instance_valid(blob):
			blob.queue_free()

		# Ground impact splash ("всплеск")!
		_trigger_nectar_splash(target_pos, spawn_parent)

		# Spawn collectible drop on lane
		if main_node and main_node.has_method("spawn_fallen_nectar_drop"):
			main_node.spawn_fallen_nectar_drop(target_pos, associated_lane_index)

		nectar_dropped.emit(target_pos, associated_lane_index)

		# Start reload cooldown
		_start_reload_cooldown()
	)

func _trigger_nectar_splash(pos: Vector3, parent_node: Node) -> void:
	if not parent_node:
		return

	# 1. Golden shockwave splash ring on the soil
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.5
	torus.material = NECTAR_MAT
	ring.mesh = torus
	parent_node.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.05, 0)
	ring.scale = Vector3(0.3, 0.3, 0.3)

	var r_tw = ring.create_tween()
	r_tw.set_parallel(true)
	r_tw.tween_property(ring, "scale", Vector3(4.2, 0.3, 4.2), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	r_tw.chain().tween_callback(ring.queue_free)

	# 2. Droplet splatter particles (8 honey drops bursting outward radially)
	for i in range(8):
		var sp = MeshInstance3D.new()
		var sp_mesh = SphereMesh.new()
		sp_mesh.radius = 0.12
		sp_mesh.height = 0.2
		sp_mesh.material = NECTAR_MAT
		sp.mesh = sp_mesh
		parent_node.add_child(sp)
		sp.global_position = pos + Vector3(0, 0.15, 0)

		var angle = (float(i) / 8.0) * TAU + randf_range(-0.2, 0.2)
		var dist = randf_range(1.0, 2.0)
		var end_pos = pos + Vector3(cos(angle) * dist, 0.04, sin(angle) * dist)

		var sp_tw = sp.create_tween()
		var dur = 0.35 + randf_range(0.0, 0.1)
		sp_tw.tween_method(func(t: float):
			if is_instance_valid(sp):
				var cur = (pos + Vector3(0, 0.15, 0)).lerp(end_pos, t)
				cur.y += sin(t * PI) * 1.1 # little hop arc
				sp.global_position = cur
				sp.scale = Vector3.ONE * (1.0 - t * 0.8)
		, 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD)
		sp_tw.tween_callback(sp.queue_free)

	# 3. Floating 3D splash text "🍯 ВСПЛЕСК!"
	var splash_lbl = Label3D.new()
	splash_lbl.text = "🍯 ВСПЛЕСК!"
	splash_lbl.font_size = 28
	splash_lbl.outline_size = 5
	splash_lbl.outline_modulate = Color(0, 0, 0, 0.9)
	splash_lbl.modulate = Color(1.0, 0.9, 0.2)
	splash_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	splash_lbl.pixel_size = 0.007
	parent_node.add_child(splash_lbl)
	splash_lbl.global_position = pos + Vector3(0, 0.8, 0)

	var lbl_tw = splash_lbl.create_tween()
	lbl_tw.parallel().tween_property(splash_lbl, "position:y", pos.y + 1.8, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lbl_tw.parallel().tween_property(splash_lbl, "modulate:a", 0.0, 0.6).set_delay(0.2)
	lbl_tw.chain().tween_callback(splash_lbl.queue_free)

	# 4. Bright golden splash flash
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.95, 0.4)
	flash.light_energy = 4.0
	flash.omni_range = 4.0
	parent_node.add_child(flash)
	flash.global_position = pos + Vector3(0, 0.4, 0)

	var f_tw = flash.create_tween()
	f_tw.tween_property(flash, "light_energy", 0.0, 0.35)
	f_tw.tween_callback(flash.queue_free)

func _start_reload_cooldown() -> void:
	var tween = create_tween()
	tween.tween_interval(reload_time)
	tween.tween_callback(func():
		has_nectar = true
		is_reloading = false
		nectar_timer = 0.0
		_update_visuals()
		if droplet_mesh:
			droplet_mesh.scale = Vector3.ZERO
			var grow_tw = create_tween()
			grow_tw.tween_property(droplet_mesh, "scale", _initial_droplet_scale * 0.4, 0.5).set_trans(Tween.TRANS_BACK)
	)

func harvest_by_bee() -> bool:
	if not has_nectar:
		return false

	has_nectar = false
	is_reloading = true
	nectar_timer = 0.0
	release_bee_reservation()
	_update_visuals()
	nectar_harvested_by_bee.emit()

	_start_reload_cooldown()
	return true

func _update_visuals() -> void:
	if droplet_mesh:
		droplet_mesh.visible = has_nectar
	if nectar_light:
		nectar_light.light_energy = 0.9 if has_nectar else 0.15
