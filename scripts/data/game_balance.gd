class_name GameBalance
extends RefCounted

## Centralized game configuration and balance parameters
## Easy to edit and tune in one place!

# Economy & Nectar
const INITIAL_NECTAR: int = 200
const INITIAL_POLLEN: int = 40
const FALLEN_NECTAR_VALUE: int = 30
const BEE_HARVEST_VALUE: int = 30

# Flower settings
const FLOWER_DROP_INTERVAL: float = 10.0    # Time before unharvested nectar drops to lane
const FLOWER_RELOAD_TIME: float = 8.0       # Cooldown after harvest/drop before new nectar appears

# Lane & Spacing settings
const UNIT_BODY_SPACING: float = 1.6        # Minimum distance kept between friendly units (anti-stacking)
const MELEE_ATTACK_RANGE: float = 2.2       # Melee engagement range
const RANGED_ATTACK_RANGE: float = 5.2      # Ranged attack range (spits over 1 friendly bug!)

# Enemy Wave settings
const ENEMY_FIRST_WAVE_TIME: float = 8.0
const ENEMY_WAVE_INTERVAL: float = 16.0

# Unit Statistics Dictionary
const UNITS = {
	"WORKER_ANT": {
		"title": "Муравей-Сборщик",
		"cost": 40,
		"max_health": 40.0,
		"move_speed": 4.6,
		"attack_damage": 5.0,
		"attack_cooldown": 0.8,
		"attack_range": 2.2,
		"is_ranged": false,
		"desc": "Быстрый сборщик: собирает упавший нектар с тропинок и носит в улей."
	},
	"FLYING_BEE": {
		"title": "Летающая Пчелка",
		"cost": 50,
		"max_health": 45.0,
		"move_speed": 5.5,
		"flight_height": 2.4,
		"attack_damage": 0.0,
		"attack_cooldown": 0.0,
		"attack_range": 0.0,
		"is_ranged": false,
		"desc": "Воздушный сборщик: забирает нектар прямо с цветков за 10с до их падения (+30🍯)."
	},
	"WOODCUTTER": {
		"title": "Жук-Лесоруб",
		"cost": 60,
		"max_health": 100.0,
		"move_speed": 3.0,
		"attack_damage": 16.0,
		"attack_cooldown": 1.0,
		"attack_range": 2.2,
		"is_ranged": false,
		"desc": "Лесоруб: средняя броня и урон, распиливает поваленные бревна."
	},
	"WOODCUTTER_BEETLE": {
		"title": "Жук-Лесоруб",
		"cost": 60,
		"max_health": 100.0,
		"move_speed": 3.0,
		"attack_damage": 16.0,
		"attack_cooldown": 1.0,
		"attack_range": 2.2,
		"is_ranged": false,
		"desc": "Лесоруб: средняя броня и урон, распиливает поваленные бревна."
	},
	"RHINO_TANK": {
		"title": "Танк-Носорог",
		"cost": 85,
		"max_health": 260.0,
		"move_speed": 1.8,
		"attack_damage": 30.0,
		"attack_cooldown": 1.6,
		"attack_range": 2.2,
		"is_ranged": false,
		"desc": "Танк: медленный, медленно бьет, но имеет колоссальное HP и мощный таран."
	},
	"RHINO_BEETLE": {
		"title": "Танк-Носорог",
		"cost": 85,
		"max_health": 260.0,
		"move_speed": 1.8,
		"attack_damage": 30.0,
		"attack_cooldown": 1.6,
		"attack_range": 2.2,
		"is_ranged": false,
		"desc": "Танк: медленный, медленно бьет, но имеет колоссальное HP и мощный таран."
	},
	"STINK_BUG": {
		"title": "Клоп (Стрелок)",
		"cost": 75,
		"max_health": 70.0,
		"move_speed": 2.8,
		"attack_damage": 22.0,
		"attack_cooldown": 1.4,
		"attack_range": 5.2,
		"is_ranged": true,
		"desc": "Дальнобойный клоп: плюется ядовитым кислотным залпом через союзника впереди!"
	},
	"TERMITE_SOLDIER": {
		"title": "Термит-Воин",
		"cost": 0,
		"max_health": 85.0,
		"move_speed": 2.6,
		"attack_damage": 16.0,
		"attack_cooldown": 1.1,
		"attack_range": 2.2,
		"is_ranged": false,
		"desc": "Вражеский солдат: нападает волнами на нашу колонию."
	}
}

static func get_unit(key: String) -> Dictionary:
	if UNITS.has(key):
		return UNITS[key]
	return {}
