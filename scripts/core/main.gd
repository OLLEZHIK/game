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
var active_lane_index: int = 1 # 0: Top, 1: Mid, 2: Bot

@onready var label_nectar: Label = %LabelNectar
@onready var label_pollen: Label = %LabelPollen

var active_units: Array = []
var selected_unit: Node3D = null

func _ready() -> void:
	_update_hud()
	_update_lane_selection_ui()
	if bug_cam_banner:
		bug_cam_banner.visible = false
	
	# Prevent buttons from stealing keyboard focus
	for btn in [btn_saw_log, btn_select_lane1, btn_select_lane2, btn_select_lane3, btn_spawn_worker, btn_spawn_woodcutter, btn_spawn_rhino]:
		if btn:
			btn.focus_mode = Control.FOCUS_NONE

	if btn_saw_log:
		btn_saw_log.pressed.connect(_on_btn_saw_log_pressed)
	if btn_select_lane1:
		btn_select_lane1.pressed.connect(func(): set_active_lane(0))
	if btn_select_lane2:
		btn_select_lane2.pressed.connect(func(): set_active_lane(1))
	if btn_select_lane3:
		btn_select_lane3.pressed.connect(func(): set_active_lane(2))

	# Spawning into currently selected tunnel
	if btn_spawn_worker:
		btn_spawn_worker.pressed.connect(func(): spawn_player_unit(WORKER_ANT_SCENE, active_lane_index, 40, "Муравей-Сборщик"))
	if btn_spawn_woodcutter:
		btn_spawn_woodcutter.pressed.connect(func(): spawn_player_unit(WOODCUTTER_BEETLE_SCENE, active_lane_index, 60, "Жук-Лесоруб"))
	if btn_spawn_rhino:
		btn_spawn_rhino.pressed.connect(func(): spawn_player_unit(RHINO_BEETLE_SCENE, active_lane_index, 85, "Танк-Носорог"))

	if forest_map and forest_map.mid_obstacle:
		forest_map.mid_obstacle.obstacle_damaged.connect(_on_obstacle_damaged)
		forest_map.mid_obstacle.obstacle_cleared.connect(_on_obstacle_cleared)

func _process(_delta: float) -> void:
	if rts_camera and bug_cam_banner:
		bug_cam_banner.visible = rts_camera.is_bug_cam

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed()):
		return
		
	var pkey = event.physical_keycode
	var key = event.keycode

	# Check both physical and logical keycodes for layout independence
	if pkey == KEY_SPACE or key == KEY_SPACE:
		saw_mid_log()
	elif pkey == KEY_1 or key == KEY_1 or pkey == KEY_KP_1:
		set_active_lane(0)
	elif pkey == KEY_2 or key == KEY_2 or pkey == KEY_KP_2:
		set_active_lane(1)
	elif pkey == KEY_3 or key == KEY_3 or pkey == KEY_KP_3:
		set_active_lane(2)
	elif pkey == KEY_F or key == KEY_F:
		toggle_bug_cam_on_selected()
	elif pkey == KEY_ESCAPE or key == KEY_ESCAPE:
		if rts_camera and rts_camera.is_bug_cam:
			rts_camera.reset_to_overview()

func set_active_lane(idx: int) -> void:
	active_lane_index = idx
	_update_lane_selection_ui()
	var names = ["Туннель 1 (Северная ветка)", "Туннель 2 (Центральная ветка)", "Туннель 3 (Южная ветка)"]
	show_notice("Выбран для отправки: %s" % names[idx], Color(0.4, 0.9, 1.0))

func _update_lane_selection_ui() -> void:
	var names = ["Ветка 1 (Север)", "Ветка 2 (Центр)", "Ветка 3 (Юг)"]
	if label_active_lane:
		label_active_lane.text = "🎯 Выход: %s" % names[active_lane_index]
	
	if btn_select_lane1:
		btn_select_lane1.text = ("▶ [ 1 ] Туннель 1 (Верх)" if active_lane_index == 0 else "[ 1 ] Туннель 1 (Верх)")
	if btn_select_lane2:
		btn_select_lane2.text = ("▶ [ 2 ] Туннель 2 (Центр)" if active_lane_index == 1 else "[ 2 ] Туннель 2 (Центр)")
	if btn_select_lane3:
		btn_select_lane3.text = ("▶ [ 3 ] Туннель 3 (Низ)" if active_lane_index == 2 else "[ 3 ] Туннель 3 (Низ)")

func spawn_player_unit(scene: PackedScene, lane_idx: int, cost: int, unit_title: String) -> Node3D:
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
	show_notice("✅ %s вышел из Туннеля %d!" % [unit_title, lane_idx + 1], Color(0.4, 1.0, 0.5))
	return unit

func show_notice(text: String, color: Color = Color.WHITE) -> void:
	if label_notification:
		label_notification.text = text
		label_notification.modulate = color
		label_notification.visible = true
		var tween = create_tween()
		tween.tween_interval(3.0)
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
		label_pollen.text = "✨ Пыльца / Биомасса: %d" % pollen
