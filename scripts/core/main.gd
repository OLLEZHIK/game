class_name MainGame
extends Node3D

const BugUnitScript = preload("res://scripts/units/bug_unit.gd")
const WORKER_ANT_SCENE = preload("res://scenes/units/worker_ant.tscn")
const RHINO_BEETLE_SCENE = preload("res://scenes/units/rhino_beetle.tscn")
const WOODCUTTER_BEETLE_SCENE = preload("res://scenes/units/woodcutter_beetle.tscn")

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
@onready var btn_spawn_woodcutter: Button = %BtnSpawnWoodcutter
@onready var btn_spawn_rhino: Button = %BtnSpawnRhino
@onready var label_selected_bug: Label = %LabelSelectedBug
@onready var bug_cam_banner: PanelContainer = %BugCamBanner
@onready var label_notification: Label = %LabelNotification if has_node("%LabelNotification") else null
@onready var label_active_lane: Label = %LabelActiveLane if has_node("%LabelActiveLane") else null

# Economy resources (from docs/03_economy_and_resources.md)
var nectar: int = 200
var pollen: int = 40

@onready var label_nectar: Label = %LabelNectar
@onready var label_pollen: Label = %LabelPollen

var active_units: Array = []
var selected_unit: Node3D = null

# BugBits Deploy Mode: Select Bug -> Click Tunnel
var deploy_bug_scene: PackedScene = null
var deploy_bug_cost: int = 0
var deploy_bug_name: String = ""

func _ready() -> void:
	_update_hud()
	if bug_cam_banner:
		bug_cam_banner.visible = false
	
	# Prevent buttons from stealing keyboard focus
	for btn in [btn_saw_log, btn_select_lane1, btn_select_lane2, btn_select_lane3, btn_spawn_worker, btn_spawn_woodcutter, btn_spawn_rhino]:
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
		btn_spawn_worker.pressed.connect(func(): select_bug_for_deployment(WORKER_ANT_SCENE, 40, "Муравей-Сборщик"))
	if btn_spawn_woodcutter:
		btn_spawn_woodcutter.pressed.connect(func(): select_bug_for_deployment(WOODCUTTER_BEETLE_SCENE, 60, "Жук-Лесоруб"))
	if btn_spawn_rhino:
		btn_spawn_rhino.pressed.connect(func(): select_bug_for_deployment(RHINO_BEETLE_SCENE, 85, "Танк-Носорог"))

	# Connect 3D world tunnel clicking
	if forest_map and forest_map.allied_base:
		forest_map.allied_base.tunnel_clicked.connect(on_tunnel_selected)

	if forest_map and forest_map.mid_obstacle:
		forest_map.mid_obstacle.obstacle_damaged.connect(_on_obstacle_damaged)
		forest_map.mid_obstacle.obstacle_cleared.connect(_on_obstacle_cleared)

func _process(_delta: float) -> void:
	if rts_camera and bug_cam_banner:
		bug_cam_banner.visible = rts_camera.is_bug_cam

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_RIGHT and deploy_bug_scene != null:
			cancel_deployment()
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
	if nectar < cost:
		show_notice("❌ Недостаточно нектара! Нужно: %d🍯 (у вас: %d🍯)" % [cost, nectar], Color(1, 0.35, 0.3))
		return
		
	deploy_bug_scene = scene
	deploy_bug_cost = cost
	deploy_bug_name = title
	
	if forest_map and forest_map.allied_base:
		forest_map.allied_base.set_highlight_for_deployment(true)
		
	_update_bug_button_styles()
	show_notice("👉 Выбран %s! Теперь НАЖМИТЕ НА ТУННЕЛЬ (Верхний, Средний или Нижний)" % title, Color(1.0, 0.9, 0.2))

## 2. Step 2: Player clicks on tunnel in 3D world or UI or presses 1, 2, 3
func on_tunnel_selected(lane_idx: int) -> void:
	var lane_names = ["Верхний (1)", "Средний (2)", "Нижний (3)"]
	
	if deploy_bug_scene != null:
		# Deploy the primed bug into this tunnel!
		var spawned = spawn_unit_into_tunnel(deploy_bug_scene, lane_idx, deploy_bug_cost, deploy_bug_name)
		if spawned:
			# Keep primed or reset if can't afford more
			if nectar < deploy_bug_cost:
				cancel_deployment()
			else:
				show_notice("✅ %s вышел в %s туннель! (Кликните еще раз для повторной отправки)" % [deploy_bug_name, lane_names[lane_idx]], Color(0.4, 1.0, 0.5))
	else:
		# No bug was selected yet: inform user to pick a bug first
		show_notice("Туннель: %s! Нажмите на иконку Муравья, Лесоруба или Танка для отправки." % lane_names[lane_idx], Color(0.5, 0.85, 1.0))

func cancel_deployment() -> void:
	deploy_bug_scene = null
	deploy_bug_cost = 0
	deploy_bug_name = ""
	if forest_map and forest_map.allied_base:
		forest_map.allied_base.set_highlight_for_deployment(false)
	_update_bug_button_styles()
	show_notice("Выбор отменен.", Color(0.8, 0.8, 0.8))

func _update_bug_button_styles() -> void:
	if btn_spawn_worker:
		btn_spawn_worker.text = ("▶ 🐜 Муравей (40🍯) [ВЫБРАН]" if deploy_bug_name == "Муравей-Сборщик" else "🐜 Муравей-Сборщик (40🍯)")
	if btn_spawn_woodcutter:
		btn_spawn_woodcutter.text = ("▶ 🪓 Лесоруб (60🍯) [ВЫБРАН]" if deploy_bug_name == "Жук-Лесоруб" else "🪓 Жук-Лесоруб (60🍯)")
	if btn_spawn_rhino:
		btn_spawn_rhino.text = ("▶ 🦏 Носорог (85🍯) [ВЫБРАН]" if deploy_bug_name == "Танк-Носорог" else "🦏 Танк-Носорог (85🍯)")
	
	if label_active_lane:
		if deploy_bug_name != "":
			label_active_lane.text = "🎯 Нажмите на Туннель в мире или [1, 2, 3]!"
			label_active_lane.modulate = Color(1.0, 0.9, 0.2)
		else:
			label_active_lane.text = "Кликните по жуку, затем по туннелю"
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

	var path = forest_map.lane_manager.get_lane_path(lane_idx)
	if path and path.curve:
		unit.initialize_on_lane(path.curve, lane_idx, false)
	
	if lane_idx == 1 and forest_map.mid_obstacle:
		unit.target_obstacle = forest_map.mid_obstacle

	unit.unit_selected.connect(_on_unit_selected)
	unit.unit_died.connect(_on_unit_died)
	
	select_unit(unit)
	return unit

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
	if label_selected_bug and "unit_name" in unit:
		label_selected_bug.text = "Выбран: %s\n(Нажмите F для Bug-Cam)" % unit.unit_name

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
		if rts_camera and rts_camera.is_bug_cam:
			rts_camera.reset_to_overview()
		if label_selected_bug:
			label_selected_bug.text = "Жук погиб!"

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
