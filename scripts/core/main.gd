class_name MainGame
extends Node3D

const BugUnitScript = preload("res://scripts/units/bug_unit.gd")
const WORKER_ANT_SCENE = preload("res://scenes/units/worker_ant.tscn")
const RHINO_BEETLE_SCENE = preload("res://scenes/units/rhino_beetle.tscn")
const WOODCUTTER_BEETLE_SCENE = preload("res://scenes/units/woodcutter_beetle.tscn")
const FLYING_BEE_SCENE = preload("res://scenes/units/flying_bee.tscn")
const TERMITE_SOLDIER_SCENE = preload("res://scenes/units/termite_soldier.tscn")
const STINK_BUG_SCENE = preload("res://scenes/units/stink_bug.tscn")
const CATERPILLAR_SCENE = preload("res://scenes/units/caterpillar.tscn")
const ENEMY_BEE_SCENE = preload("res://scenes/units/enemy_bee.tscn")
const FALLEN_NECTAR_DROP_SCENE = preload("res://scenes/props/fallen_nectar_drop.tscn")

@onready var forest_map: ForestMap = $ForestMap
@onready var rts_camera: RTSCamera = $RTSCamera

# HUD elements
@onready var label_mid_status: Label = %LabelMidStatus
@onready var label_log_hp: Label = %LabelLogHp
@onready var btn_saw_log: Button = %BtnSawLog
@onready var btn_select_lane1: Button = %BtnSelectLane1
@onready var btn_select_lane2: Button = %BtnSelectLane2
@onready var btn_select_lane3: Button = %BtnSelectLane3

# Spawn buttons
@onready var btn_spawn_worker: Button = %BtnSpawnWorker
@onready var btn_spawn_bee: Button = %BtnSpawnBee if has_node("%BtnSpawnBee") else null
@onready var btn_spawn_woodcutter: Button = %BtnSpawnWoodcutter
@onready var btn_spawn_rhino: Button = %BtnSpawnRhino
@onready var btn_spawn_stink_bug: Button = %BtnSpawnStinkBug if has_node("%BtnSpawnStinkBug") else null
@onready var btn_spawn_caterpillar: Button = %BtnSpawnCaterpillar if has_node("%BtnSpawnCaterpillar") else null
@onready var btn_spawn_enemy: Button = %BtnSpawnEnemy if has_node("%BtnSpawnEnemy") else null
@onready var btn_spawn_enemy_bee: Button = %BtnSpawnEnemyBee if has_node("%BtnSpawnEnemyBee") else null
@onready var label_wave_status: Label = %LabelWaveStatus if has_node("%LabelWaveStatus") else null

# Stats panel elements
@onready var label_stat_title: Label = %LabelStatTitle if has_node("%LabelStatTitle") else null
@onready var label_stat_hp: Label = %LabelStatHp if has_node("%LabelStatHp") else null
@onready var label_stat_speed: Label = %LabelStatSpeed if has_node("%LabelStatSpeed") else null
@onready var label_stat_damage: Label = %LabelStatDamage if has_node("%LabelStatDamage") else null
@onready var label_stat_cadence: Label = %LabelStatCadence if has_node("%LabelStatCadence") else null
@onready var label_stat_desc: Label = %LabelStatDesc if has_node("%LabelStatDesc") else null

@onready var bug_cam_banner: PanelContainer = %BugCamBanner
@onready var label_notification: Label = %LabelNotification if has_node("%LabelNotification") else null
@onready var label_active_lane: Label = %LabelActiveLane if has_node("%LabelActiveLane") else null

var fallen_nectar_drops: Array = []
var in_flight_drop_targets: Array = []

# Economy resources (from docs/03_economy_and_resources.md)
var nectar: int = 200
var pollen: int = 40

# Enemy waves
var enemy_wave_timer: float = 8.0
var enemy_wave_interval: float = 15.0

@onready var label_nectar: Label = %LabelNectar
@onready var label_pollen: Label = %LabelPollen

var active_units: Array = []
var selected_unit: Node3D = null

# BugBits Deploy Mode: Select Bug -> Click Tunnel or Lane
var deploy_bug_scene: PackedScene = null
var deploy_bug_cost: int = 0
var deploy_bug_name: String = ""

func _ready() -> void:
	_update_hud()
	if bug_cam_banner:
		bug_cam_banner.visible = false
	
	# Prevent buttons from stealing keyboard focus
	var all_btns = [btn_saw_log, btn_select_lane1, btn_select_lane2, btn_select_lane3, 
		btn_spawn_worker, btn_spawn_bee, btn_spawn_woodcutter, btn_spawn_rhino, btn_spawn_stink_bug, btn_spawn_enemy]
	for btn in all_btns:
		if btn:
			btn.focus_mode = Control.FOCUS_NONE

	if btn_saw_log:
		btn_saw_log.pressed.connect(_on_btn_saw_log_pressed)
		
	# Direct tunnel buttons on UI
	if btn_select_lane1:
		btn_select_lane1.pressed.connect(func(): on_tunnel_selected(0))
	if btn_select_lane2:
		btn_select_lane2.pressed.connect(func(): on_tunnel_selected(1))
	if btn_select_lane3:
		btn_select_lane3.pressed.connect(func(): on_tunnel_selected(2))

	# Bug selection buttons
	if btn_spawn_worker:
		btn_spawn_worker.pressed.connect(func(): select_bug_for_deployment(WORKER_ANT_SCENE, GameBalance.UNITS["WORKER_ANT"].cost, "Муравей-Сборщик"))
		btn_spawn_worker.mouse_entered.connect(func(): display_stats_for_bug_name("Муравей-Сборщик"))
	if btn_spawn_bee:
		btn_spawn_bee.pressed.connect(func(): select_bug_for_deployment(FLYING_BEE_SCENE, GameBalance.UNITS["FLYING_BEE"].cost, "Летающая Пчелка"))
		btn_spawn_bee.mouse_entered.connect(func(): display_stats_for_bug_name("Летающая Пчелка"))
	if btn_spawn_woodcutter:
		btn_spawn_woodcutter.pressed.connect(func(): select_bug_for_deployment(WOODCUTTER_BEETLE_SCENE, GameBalance.UNITS["WOODCUTTER_BEETLE"].cost, "Жук-Лесоруб"))
		btn_spawn_woodcutter.mouse_entered.connect(func(): display_stats_for_bug_name("Жук-Лесоруб"))
	if btn_spawn_rhino:
		btn_spawn_rhino.pressed.connect(func(): select_bug_for_deployment(RHINO_BEETLE_SCENE, GameBalance.UNITS["RHINO_BEETLE"].cost, "Танк-Носорог"))
		btn_spawn_rhino.mouse_entered.connect(func(): display_stats_for_bug_name("Танк-Носорог"))
	if btn_spawn_stink_bug:
		btn_spawn_stink_bug.pressed.connect(func(): select_bug_for_deployment(STINK_BUG_SCENE, GameBalance.UNITS["STINK_BUG"].cost, "Клоп-Стрелок"))
		btn_spawn_stink_bug.mouse_entered.connect(func(): display_stats_for_bug_name("Клоп-Стрелок"))
	if btn_spawn_caterpillar:
		btn_spawn_caterpillar.pressed.connect(func(): select_bug_for_deployment(CATERPILLAR_SCENE, GameBalance.UNITS["CATERPILLAR"].cost, "Гусеница-ПВО"))
		btn_spawn_caterpillar.mouse_entered.connect(func(): display_stats_for_bug_name("Гусеница-ПВО"))

	# Enemy manual trigger buttons
	if btn_spawn_enemy:
		btn_spawn_enemy.pressed.connect(func(): spawn_enemy_wave(randi() % 3))
		btn_spawn_enemy.mouse_entered.connect(func(): display_stats_for_bug_name("Термит-Воин"))
	if btn_spawn_enemy_bee:
		btn_spawn_enemy_bee.pressed.connect(func(): spawn_enemy_bee())
		btn_spawn_enemy_bee.mouse_entered.connect(func(): display_stats_for_bug_name("Вражеская Оса-Пчела"))

	# Connect 3D world tunnel and lane clicking
	if forest_map:
		if forest_map.allied_base:
			forest_map.allied_base.tunnel_clicked.connect(on_tunnel_selected)
		if forest_map.has_signal("lane_clicked"):
			forest_map.lane_clicked.connect(on_tunnel_selected)

	if forest_map and forest_map.mid_obstacle:
		forest_map.mid_obstacle.obstacle_damaged.connect(_on_obstacle_damaged)
		forest_map.mid_obstacle.obstacle_cleared.connect(_on_obstacle_cleared)

func _process(delta: float) -> void:
	if rts_camera and bug_cam_banner:
		bug_cam_banner.visible = rts_camera.is_bug_cam

	# Enemy wave timer
	enemy_wave_timer -= delta
	if label_wave_status:
		label_wave_status.text = "Волна термитов: %d с" % max(0, int(ceil(enemy_wave_timer)))
	if enemy_wave_timer <= 0.0:
		enemy_wave_timer = enemy_wave_interval
		var random_lane = randi() % 3
		spawn_enemy_wave(random_lane)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if deploy_bug_scene != null:
				cancel_deployment()
				return
			elif is_instance_valid(selected_unit):
				_handle_right_click_order(event.position)
				return

	if not (event is InputEventKey and event.is_pressed()):
		return
		
	var pkey = event.physical_keycode
	var key = event.keycode

	# Check both physical and logical keycodes for layout independence
	if pkey == KEY_SPACE or key == KEY_SPACE:
		saw_mid_log()
	elif pkey == KEY_1 or key == KEY_1 or pkey == KEY_KP_1:
		on_tunnel_selected(0)
	elif pkey == KEY_2 or key == KEY_2 or pkey == KEY_KP_2:
		on_tunnel_selected(1)
	elif pkey == KEY_3 or key == KEY_3 or pkey == KEY_KP_3:
		on_tunnel_selected(2)
	elif pkey == KEY_F or key == KEY_F:
		toggle_bug_cam_on_selected()
	elif pkey == KEY_ESCAPE or key == KEY_ESCAPE:
		if deploy_bug_scene != null:
			cancel_deployment()
		elif rts_camera and rts_camera.is_bug_cam:
			rts_camera.reset_to_overview()

## 1. Step 1: Player clicks on bug icon to deploy
func select_bug_for_deployment(scene: PackedScene, cost: int, title: String) -> void:
	display_stats_for_bug_name(title)
	if nectar < cost:
		show_notice("❌ Недостаточно нектара! Нужно: %d🍯 (у вас: %d🍯)" % [cost, nectar], Color(1, 0.35, 0.3))
		return
		
	deploy_bug_scene = scene
	deploy_bug_cost = cost
	deploy_bug_name = title
	
	if forest_map and forest_map.allied_base:
		forest_map.allied_base.set_highlight_for_deployment(true)
		
	_update_bug_button_styles()
	show_notice("👉 Выбран: %s! Кликните на ЛИНИЮ или туннель" % title, Color(1.0, 0.9, 0.2))

## 2. Step 2: Player clicks on tunnel in 3D world, lane strip, or UI
func on_tunnel_selected(lane_idx: int) -> void:
	var lane_names = ["Верхний (1)", "Средний (2)", "Нижний (3)"]
	
	if deploy_bug_scene != null:
		# Deploy the primed bug into this tunnel/lane!
		var spawned = spawn_unit_into_tunnel(deploy_bug_scene, lane_idx, deploy_bug_cost, deploy_bug_name)
		if spawned:
			if nectar < deploy_bug_cost:
				cancel_deployment()
			else:
				show_notice("✅ %s отправлен на ветку %s!" % [deploy_bug_name, lane_names[lane_idx]], Color(0.4, 1.0, 0.5))
	else:
		show_notice("Выбрана ветка: %s! Нажмите на жука слева для отправки." % lane_names[lane_idx], Color(0.5, 0.85, 1.0))

func cancel_deployment() -> void:
	deploy_bug_scene = null
	deploy_bug_cost = 0
	deploy_bug_name = ""
	if forest_map and forest_map.allied_base:
		forest_map.allied_base.set_highlight_for_deployment(false)
	_update_bug_button_styles()
	clear_bug_stats()
	show_notice("Выбор отменен.", Color(0.8, 0.8, 0.8))

func _update_bug_button_styles() -> void:
	if btn_spawn_worker:
		btn_spawn_worker.text = ("▶ Муравей (40🍯) [ВЫБРАН]" if deploy_bug_name == "Муравей-Сборщик" else " Муравей-Сборщик (40🍯)")
	if btn_spawn_bee:
		btn_spawn_bee.text = ("▶ Пчелка (50🍯) [ВЫБРАНА]" if deploy_bug_name == "Летающая Пчелка" else " Летающая Пчелка (50🍯)")
	if btn_spawn_woodcutter:
		btn_spawn_woodcutter.text = ("▶ Лесоруб (60🍯) [ВЫБРАН]" if deploy_bug_name == "Жук-Лесоруб" else " Жук-Лесоруб (60🍯)")
	if btn_spawn_rhino:
		btn_spawn_rhino.text = ("▶ Носорог (85🍯) [ВЫБРАН]" if deploy_bug_name == "Танк-Носорог" else " Танк-Носорог (85🍯)")
	if btn_spawn_stink_bug:
		btn_spawn_stink_bug.text = ("▶ Клоп (75🍯) [ВЫБРАН]" if deploy_bug_name == "Клоп-Стрелок" else " Клоп-Стрелок (75🍯)")
	if btn_spawn_caterpillar:
		btn_spawn_caterpillar.text = ("▶ Гусеница (90🍯) [ВЫБРАНА]" if deploy_bug_name == "Гусеница-ПВО" else " Гусеница-ПВО (90🍯)")
	
	if label_active_lane:
		if deploy_bug_name != "":
			label_active_lane.text = "🎯 Кликните на ЛИНИЮ или туннель!"
			label_active_lane.modulate = Color(1.0, 0.9, 0.2)
		else:
			label_active_lane.text = "Кликните по жуку, затем по линии"
			label_active_lane.modulate = Color(0.7, 0.7, 0.7)

func spawn_unit_into_tunnel(scene: PackedScene, lane_idx: int, cost: int, unit_title: String) -> Node3D:
	if nectar < cost:
		show_notice("❌ Недостаточно нектара! Нужно: %d🍯 (у вас: %d🍯)" % [cost, nectar], Color(1, 0.35, 0.3))
		return null

	nectar -= cost
	_update_hud()

	var unit = scene.instantiate()
	add_child(unit)
	active_units.append(unit)

	# Special handling for Air class (Flying Bee)
	if scene == FLYING_BEE_SCENE or unit.has_method("initialize_bee"):
		var spawn_pos = Vector3(-7.5, 2.4, (lane_idx - 1) * 6.0)
		unit.initialize_bee(spawn_pos, Vector3(-7.5, 0.0, 0.0))
		unit.unit_selected.connect(_on_unit_selected)
		unit.unit_died.connect(_on_unit_died)
		select_unit(unit)
		show_notice("🐝 Пчелка взлетела! Летает по всей арене и собирает мед.", Color(1.0, 0.9, 0.2))
		return unit

	# Land units follow the lane curve
	if forest_map and forest_map.lane_manager:
		var path = forest_map.lane_manager.get_lane_path(lane_idx)
		if path and path.curve:
			unit.initialize_on_lane(path.curve, lane_idx, false)
	
	if lane_idx == 1 and forest_map and forest_map.mid_obstacle:
		unit.target_obstacle = forest_map.mid_obstacle

	unit.unit_selected.connect(_on_unit_selected)
	unit.unit_died.connect(_on_unit_died)
	
	select_unit(unit)
	return unit

## Spawns an opposing enemy termite wave
func spawn_enemy_wave(lane_idx: int) -> void:
	if not forest_map or not forest_map.lane_manager:
		return
	var enemy = TERMITE_SOLDIER_SCENE.instantiate()
	add_child(enemy)
	active_units.append(enemy)

	var path = forest_map.lane_manager.get_lane_path(lane_idx)
	if path and path.curve:
		enemy.initialize_on_lane(path.curve, lane_idx, true)

	enemy.unit_selected.connect(_on_unit_selected)
	enemy.unit_died.connect(_on_unit_died)

	var lane_names = ["Верхней (1)", "Средней (2)", "Нижней (3)"]
	show_notice("⚠️ Термит-Воин вышел на %s линии!" % lane_names[lane_idx], Color(1.0, 0.4, 0.3))

	# 40% chance to spawn an enemy bee for air harassment
	if randf() < 0.4:
		spawn_enemy_bee()

func show_notice(text: String, color: Color = Color.WHITE) -> void:
	if label_notification:
		label_notification.text = text
		label_notification.modulate = color
		label_notification.visible = true
		var tween = create_tween()
		tween.tween_interval(3.5)
		tween.tween_property(label_notification, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): label_notification.visible = false; label_notification.modulate.a = 1.0)

func select_unit(unit: Node3D) -> void:
	selected_unit = unit
	display_stats_from_unit(unit)

func toggle_bug_cam_on_selected() -> void:
	if not selected_unit:
		if active_units.size() > 0:
			selected_unit = active_units[0]
	if selected_unit and rts_camera:
		rts_camera.toggle_bug_cam(selected_unit)

func _on_unit_selected(unit: Node3D) -> void:
	select_unit(unit)

func _on_unit_died(unit: Node3D) -> void:
	active_units.erase(unit)
	if selected_unit == unit:
		selected_unit = null
		clear_bug_stats()
		if rts_camera and rts_camera.is_bug_cam:
			rts_camera.reset_to_overview()

## Anti-stacking drop placement: finds adjacent non-overlapping coordinate along lane ("впритык, но рядом")
func calculate_unstacked_drop_position(desired_pos: Vector3, lane_z: float) -> Vector3:
	const MIN_DISTANCE: float = 0.85
	const MIN_DIST_SQ: float = MIN_DISTANCE * MIN_DISTANCE

	var occupied_points: Array[Vector2] = []
	for drop in fallen_nectar_drops:
		if is_instance_valid(drop) and not drop.is_collected:
			var d_pos = drop.global_position if drop.is_inside_tree() else drop.position
			occupied_points.append(Vector2(d_pos.x, d_pos.z))
	for pt in in_flight_drop_targets:
		if pt is Vector2:
			occupied_points.append(pt)

	var target_p2 = Vector2(desired_pos.x, desired_pos.z)
	var is_spot_free = true
	for op in occupied_points:
		if target_p2.distance_squared_to(op) < MIN_DIST_SQ:
			is_spot_free = false
			break

	if is_spot_free:
		return desired_pos

	# If occupied, find adjacent clearance spot ("впритык, но рядом")
	var best_p2: Vector2 = target_p2
	var found = false

	# Test expanding rings around desired_pos
	for ring in range(1, 14):
		var radius = ring * MIN_DISTANCE
		var steps = 8 * ring
		for step in range(steps):
			var angle = (float(step) / float(steps)) * TAU
			var cand_x = desired_pos.x + cos(angle) * radius
			var cand_z = desired_pos.z + sin(angle) * radius

			# Keep strictly on dirt lane width & playable bounds
			if absf(cand_z - lane_z) > 0.8:
				continue
			if cand_x < -4.0 or cand_x > 18.0:
				continue

			var cand_p2 = Vector2(cand_x, cand_z)
			var valid = true
			for op in occupied_points:
				if cand_p2.distance_squared_to(op) < MIN_DIST_SQ:
					valid = false
					break
			if valid:
				best_p2 = cand_p2
				found = true
				break
		if found:
			break

	# Fallback: slide linearly along X axis on the lane
	if not found:
		for step in range(1, 25):
			for sgn in [1.0, -1.0]:
				var cand_x = clampf(desired_pos.x + sgn * step * MIN_DISTANCE, -4.0, 18.0)
				var cand_p2 = Vector2(cand_x, lane_z)
				var valid = true
				for op in occupied_points:
					if cand_p2.distance_squared_to(op) < MIN_DIST_SQ:
						valid = false
						break
				if valid:
					best_p2 = cand_p2
					found = true
					break
			if found:
				break

	return Vector3(best_p2.x, desired_pos.y, best_p2.y)

func reserve_unstacked_drop_position(desired_pos: Vector3, lane_z: float) -> Vector3:
	var final_pos = calculate_unstacked_drop_position(desired_pos, lane_z)
	in_flight_drop_targets.append(Vector2(final_pos.x, final_pos.z))
	return final_pos

func spawn_fallen_nectar_drop(pos: Vector3, lane_idx: int) -> Node3D:
	# Release reservation from in_flight_drop_targets
	var p2 = Vector2(pos.x, pos.z)
	for i in range(in_flight_drop_targets.size() - 1, -1, -1):
		if (in_flight_drop_targets[i] as Vector2).distance_squared_to(p2) < 0.25:
			in_flight_drop_targets.remove_at(i)
			break

	var final_pos = calculate_unstacked_drop_position(pos, pos.z)
	var drop = FALLEN_NECTAR_DROP_SCENE.instantiate()
	drop.position = final_pos
	drop.lane_index = lane_idx
	add_child(drop)
	fallen_nectar_drops.append(drop)
	drop.tree_exited.connect(func(): fallen_nectar_drops.erase(drop))
	var lane_names = ["Верхнюю (1)", "Среднюю (2)", "Нижнюю (3)"]
	show_notice("🍯 Цветок сбросил нектар на %s дорожку! Муравей может забрать его." % lane_names[lane_idx], Color(1.0, 0.85, 0.2))
	return drop

func display_bug_stats(title_str: String, hp_str: String, speed_str: String, dmg_str: String, cadence_str: String, desc_str: String) -> void:
	if label_stat_title:
		label_stat_title.text = "📊 %s" % title_str
	if label_stat_hp:
		label_stat_hp.text = "❤️ Здоровье: %s" % hp_str
	if label_stat_speed:
		label_stat_speed.text = "🏃 Скорость бега: %s" % speed_str
	if label_stat_damage:
		label_stat_damage.text = "⚔️ Сила атаки: %s" % dmg_str
	if label_stat_cadence:
		label_stat_cadence.text = "⏱️ Скорость атаки: %s" % cadence_str
	if label_stat_desc:
		label_stat_desc.text = desc_str

func display_stats_for_bug_name(bname: String) -> void:
	var key = ""
	match bname:
		"Муравей-Сборщик": key = "WORKER_ANT"
		"Летающая Пчелка": key = "FLYING_BEE"
		"Жук-Лесоруб": key = "WOODCUTTER_BEETLE"
		"Танк-Носорог": key = "RHINO_BEETLE"
		"Клоп-Стрелок", "Клоп (Стрелок)": key = "STINK_BUG"
		"Гусеница-ПВО", "Гусеница": key = "CATERPILLAR"
		"Термит-Воин": key = "TERMITE_SOLDIER"
		"Вражеская Оса-Пчела", "Вражеская Пчела": key = "ENEMY_BEE"

	if key != "" and GameBalance.UNITS.has(key):
		var s = GameBalance.UNITS[key]
		var title = "%s (%d🍯)" % [s.title, s.cost] if s.cost > 0 else s.title
		var hp_str = "%d HP" % int(s.max_health)
		var spd_str = "%.1f м/с" % s.move_speed
		var dmg_str = "%.0f урона" % s.attack_damage if s.attack_damage > 0 else "—"
		var cad_str = "%.1f с" % s.attack_cooldown if s.attack_cooldown > 0 else "—"
		display_bug_stats(title, hp_str, spd_str, dmg_str, cad_str, s.desc)

func display_stats_from_unit(unit: Node3D) -> void:
	if not is_instance_valid(unit):
		return
	var uname = unit.get("unit_name") if "unit_name" in unit else "Юнит"
	var chp = int(unit.get("current_health")) if "current_health" in unit else 0
	var mhp = int(unit.get("max_health")) if "max_health" in unit else 0
	var spd = unit.get("move_speed") if "move_speed" in unit else 0.0
	var dmg = unit.get("attack_damage") if "attack_damage" in unit else 0.0
	var cad = unit.get("attack_cooldown") if "attack_cooldown" in unit else 0.0
	
	display_bug_stats(uname, "%d / %d HP" % [chp, mhp], "%.1f м/с" % spd, "%.0f урона" % dmg if dmg > 0 else "—", "%.1f с" % cad if cad > 0 else "—", "Нажмите F для вида от лица (Bug-Cam)")

func clear_bug_stats() -> void:
	display_bug_stats("ХАРАКТЕРИСТИКИ:", "—", "—", "—", "—", "Кликните по жуку для деталей (F — вид от лица)")

func saw_mid_log() -> void:
	if forest_map:
		forest_map.damage_obstacle(35.0)
		show_notice("🪓 Нанесен урон бревну! (-35 HP)", Color(1.0, 0.85, 0.2))

func _on_obstacle_damaged(curr_hp: float, max_hp: float) -> void:
	if label_log_hp:
		label_log_hp.text = "Сук на центре: %d/%d HP" % [int(curr_hp), int(max_hp)]

func _on_obstacle_cleared(_obs: LaneObstacle) -> void:
	pollen += 35
	_update_hud()
	if label_mid_status:
		label_mid_status.text = "СВОБОДНА (Бревно распилено! +35 пыльцы)"
		label_mid_status.modulate = Color(0.3, 1.0, 0.4)
	if label_log_hp:
		label_log_hp.text = "Препятствие расчищено!"
	if btn_saw_log:
		btn_saw_log.disabled = true
		btn_saw_log.text = "Бревно распилено!"
	show_notice("🎉 Центральное бревно распилено! Линия свободна (+35 пыльцы)", Color(1, 0.9, 0.2))

func _on_btn_saw_log_pressed() -> void:
	saw_mid_log()

func _update_hud() -> void:
	if label_nectar:
		label_nectar.text = "🍯 Нектар: %d" % nectar
	if label_pollen:
		label_pollen.text = "✨ Пыльца: %d" % pollen

func spawn_enemy_bee() -> Node3D:
	var bee = ENEMY_BEE_SCENE.instantiate()
	add_child(bee)
	active_units.append(bee)
	var spawn_pos = Vector3(21.5, 2.4, (randf() - 0.5) * 6.0)
	bee.initialize_bee(spawn_pos, Vector3(21.5, 0.0, 0.0))
	bee.unit_selected.connect(_on_unit_selected)
	bee.unit_died.connect(_on_unit_died)
	show_notice("⚠️ Вражеская Оса-Пчела вылетела из улья противника!", Color(1.0, 0.35, 0.35))
	return bee

## Micro-control: Right-click gives direct orders with a 5-second command window
func _handle_right_click_order(screen_pos: Vector2) -> void:
	if not is_instance_valid(selected_unit):
		return
	if not rts_camera or not rts_camera.camera_3d:
		return

	var cam = rts_camera.camera_3d
	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_normal = cam.project_ray_normal(screen_pos)
	var ray_length = 300.0
	var ray_end = ray_origin + ray_normal * ray_length

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)

	var hit_flower: Node3D = null
	var hit_enemy: Node3D = null
	var target_pos: Vector3 = Vector3.ZERO
	var has_target_pos: bool = false

	if not result.is_empty():
		var cur = result.collider
		while cur != null and cur != self and cur != get_tree().root:
			if cur is FlowerProp:
				hit_flower = cur
				break
			if "is_enemy" in cur:
				var selected_is_enemy = selected_unit.get("is_enemy") if "is_enemy" in selected_unit else false
				if cur.is_enemy != selected_is_enemy:
					hit_enemy = cur
					break
			cur = cur.get_parent()
		target_pos = result.position
		has_target_pos = true
	else:
		var target_y = selected_unit.global_position.y if selected_unit.is_inside_tree() else 0.0
		var plane = Plane(Vector3.UP, target_y)
		var intersect = plane.intersects_ray(ray_origin, ray_normal)
		if intersect != null:
			target_pos = intersect
			has_target_pos = true

	if hit_enemy != null:
		if selected_unit.has_method("order_attack_target"):
			selected_unit.order_attack_target(hit_enemy)
			var hpos = hit_enemy.global_position if hit_enemy.is_inside_tree() else hit_enemy.position
			_spawn_order_ring(hpos, Color(1.0, 0.25, 0.25))
			show_notice("🎯 Приказ: атаковать врага на 5с!", Color(1.0, 0.4, 0.4))
			return
	elif hit_flower != null and selected_unit.has_method("order_target_flower"):
		selected_unit.order_target_flower(hit_flower)
		var fpos = hit_flower.global_position if hit_flower.is_inside_tree() else hit_flower.position
		_spawn_order_ring(fpos, Color(1.0, 0.9, 0.2))
		show_notice("🌸 Приказ: лететь к цветку на 5с!", Color(1.0, 0.9, 0.3))
		return
	elif has_target_pos:
		if selected_unit.has_method("order_move_to_position"):
			selected_unit.order_move_to_position(target_pos)
			_spawn_order_ring(target_pos, Color(0.3, 0.9, 1.0))
			show_notice("📍 Приказ: движение в точку на 5с!", Color(0.4, 0.8, 1.0))
			return

func _spawn_order_ring(pos: Vector3, color: Color) -> void:
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.75
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.mesh = torus
	ring.material_override = mat
	add_child(ring)
	ring.global_position = pos + Vector3(0, 0.15, 0)

	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector3(1.4, 1.4, 1.4), 0.45)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.tween_callback(func(): ring.queue_free())
