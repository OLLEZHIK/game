class_name CaterpillarUnit
extends BugUnit

const NEEDLE_PROJECTILE_SCENE = preload("res://scenes/props/needle_projectile.tscn")

@onready var dorsal_spine: Node3D = $Visuals/BodyMesh/DorsalSpine if has_node("Visuals/BodyMesh/DorsalSpine") else null

func _ready() -> void:
	unit_name = "Гусеница-ПВО"
	role = UnitRole.RANGED
	is_ranged = true
	max_health = 120.0
	current_health = max_health
	move_speed = 2.2
	attack_damage = 12.0
	attack_cooldown = 0.5 # 0.5s rapid fire!
	attack_range = 22.0   # ~Half the map!

	super._ready()

func _process(delta: float) -> void:
	super._process(delta)

## Prioritize air targets (Enemy Bees) anywhere within 22m range, then ground enemies
func _find_nearest_enemy_on_lane() -> CharacterBody3D:
	var tree = get_tree()
	if not tree:
		return null
	var main_node = tree.root.find_child("Main", true, false)
	if not main_node or not ("active_units" in main_node):
		return null

	# 1. First priority: Air targets (Enemy Flying Bees) within 22m
	var nearest_air_target: CharacterBody3D = null
	var min_air_dist: float = attack_range

	for other in main_node.active_units:
		if is_instance_valid(other) and other != self:
			if ("is_enemy" in other) and (other.is_enemy != is_enemy):
				if ("current_state" in other) and other.current_state != UnitState.DEAD:
					if other is FlyingBee:
						var d = global_position.distance_to(other.global_position)
						if d <= min_air_dist:
							min_air_dist = d
							nearest_air_target = other

	if nearest_air_target:
		return nearest_air_target

	# 2. Second priority: Ground enemies on the same lane within range
	var nearest_ground_target: CharacterBody3D = null
	var min_ground_dist: float = attack_range

	for other in main_node.active_units:
		if is_instance_valid(other) and other != self:
			if ("is_enemy" in other) and (other.is_enemy != is_enemy):
				if ("current_state" in other) and other.current_state != UnitState.DEAD:
					if ("lane_index" in other) and other.lane_index == lane_index:
						var d = global_position.distance_to(other.global_position)
						if d <= min_ground_dist:
							min_ground_dist = d
							nearest_ground_target = other

	return nearest_ground_target

## Rapid needle spine launch
func _perform_ranged_attack() -> void:
	# Spine recoil animation
	if dorsal_spine:
		var orig_y = dorsal_spine.scale.y
		var tw = create_tween()
		tw.tween_property(dorsal_spine, "scale:y", orig_y * 0.4, 0.04)
		tw.tween_property(dorsal_spine, "scale:y", orig_y, 0.12)

	if is_instance_valid(target_enemy) and NEEDLE_PROJECTILE_SCENE:
		var needle = NEEDLE_PROJECTILE_SCENE.instantiate()
		get_parent().add_child(needle)
		var spawn_pos = global_position + Vector3(0, 0.85, 0)
		needle.launch(spawn_pos, target_enemy, attack_damage)
