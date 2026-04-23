extends Node

var is_start: bool = false
var is_day: bool = true
var is_pause: bool = false
var is_over: bool = false

# Time variables
var current_time: float = 6.0 # Start at 6:00 AM
var time_speed: float = 0.1   # How many "in-game hours" pass per real second
var cycle_count: int = 0

var spawner: Spawner
var hud: HUD

# Player variables
var player: Player = null
var max_health: float = 25.0
var health: float = 25.0
var regen: float = 1
var click_dmg = 10.0
var click_fire_rate = 0.35
var bullet_speed = 600.0
var auto_turret_enabled: bool = false
var auto_dmg: float = 7.0
var auto_fire_rate: float = 1.5   # seconds between shots
var auto_bullet_speed: float = 500.0
var auto_targets: int = 1
var money_per_kill: int = 15
var money: int = 0

# Enemy variables
var base_enemy_hp: float = 10.0
var base_enemy_dmg: float = 5.0
var base_enemy_speed: float = 220.0
var base_spawn_rate: float = 1.8
var mutation_rate: float = 0.25  # tune this: 0.1 = slow creep, 0.5 = fast madness

# Dictionary to hold the state of every upgrade
# Key: ID, Value: {level, base_cost, cost_multiplier}
var upgrades: Dictionary = {
	"money": {
		"title": "Money Per Kill",
		"level": 0, 
		"cost": 20, 
		"mult": 1.5
	},
	"max_hp": {
		"title": "Max HP",
		"level": 0, 
		"cost": 25, 
		"mult": 1.5
	},
	"hp_regen": {
		"title": "HP Regen",
		"level": 0, 
		"cost": 30, 
		"mult": 1.6
	},
	"bullet_dmg": {
		"title": "Bullet Damage",
		"level": 0, 
		"cost": 30, 
		"mult": 1.6
	},
	"bullet_speed": {
		"title": "Bullet Speed",
		"level": 0, 
		"cost": 25, 
		"mult": 1.6
	},
	"auto_turret": {
		"title": "Auto Turret",
		"level": 0, 
		"cost": 200, 
		"mult": 2.0,
		"one_time": true
	},
	"auto_turret_dmg": {
		"title": "Turret Damage",
		"level": 0, "cost": 50, "mult": 1.5,
		"requires": "auto_turret"
	},
	"auto_turret_fire_rate": {
		"title": "Turret Fire Rate",
		"level": 0, "cost": 75, "mult": 1.5,
		"requires": "auto_turret"
	},
	"auto_turret_bullet_speed": {
		"title": "Turret Bullet Speed",
		"level": 0, "cost": 50, "mult": 1.5,
		"requires": "auto_turret"
	},
	"auto_turret_targets": {
		"title": "Turret Targets",
		"level": 0, "cost": 1000, "mult": 2,
		"requires": "auto_turret"
	}
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float):
	if not is_start: return

	if Input.is_action_just_pressed("esc"):
		pause()
	
	if Input.is_action_just_pressed("cheat_money"):
		GameManager.money += 1000

	hp_regen(delta)
	clock(delta)

func hp_regen(delta: float):
	health = min(max_health, health + regen * delta)

func clock(delta: float):
	# Progress time
	current_time += delta * time_speed
	
	# Handle Day/Night switch
	# 6:00 to 18:00 (6AM - 6PM) is Day
	if current_time >= 6.0 and current_time < 18.0:
		is_day = true
	else:
		is_day = false

	var bg = get_tree().get_first_node_in_group("background")
	if bg:
		bg.material.set_shader_parameter("time_of_day", current_time)

	var int_hour = int(current_time)
	if (int_hour == 12 or int_hour == 0):
		trigger_special_event()
	
	# Reset cycle and increment difficulty at midnight
	if current_time >= 24.0:
		current_time = 0.0
		cycle_count += 1

func trigger_special_event():
	if is_day:
		print("HIGH NOON: Boss Spawns!")
	else:
		print("MIDNIGHT: Resource Rush Starts!")

func get_clock_string():
	var hours = int(current_time)
	var minutes = int((current_time - hours) * 60)
	var am_pm = "AM" if hours < 12 else "PM"
	
	# Convert 24h to 12h format
	var display_hours = hours % 12
	if display_hours == 0: display_hours = 12
	
	# Format string to look like "12:05 PM"
	return "%02d:%02d %s" % [display_hours, minutes, am_pm]

func attempt_purchase(id: String) -> bool:
	if not upgrades.has(id): return false
	
	var data = upgrades[id]
	var current_cost = data["cost"]
	
	if money >= current_cost:
		# 1. Pay the price
		money -= current_cost
		
		# 2. Level up
		data["level"] += 1
		
		# 3. Increase cost for next time (The "Inflation")
		data["cost"] = int(current_cost * data["mult"])
		
		print("Bought ", id, ". New Level: ", data["level"])
		return true
	return false

func get_spawn_interval():
	var min_interval = 0.2  # The absolute fastest the game can go
	
	# 1. Global Scaling: Always decreasing
	# Using cycle_count + (current_total_time / day_length) 
	# ensures it gets harder even DURING the day, not just when the day ends.
	var total_progression = cycle_count + (current_time / 24.0)
	var current_floor = base_spawn_rate * pow(0.92, total_progression)

	# 2. Time of Day "Pulse":
	# Instead of remapping to a high number (1.2), 
	# remap to a percentage of the CURRENT floor.
	var pulse_mod = 1.0
	if is_day:
		# Noon makes it 30% faster than the current floor
		var dist_from_noon = abs(current_time - 12.0)
		pulse_mod = remap(dist_from_noon, 0.0, 6.0, 0.7, 1.0)
	else:
		# Midnight makes it 70% faster than the current floor
		var dist_from_midnight = min(current_time, abs(24.0 - current_time))
		pulse_mod = remap(dist_from_midnight, 0.0, 6.0, 0.3, 1.0)
		
	var final_interval = current_floor * pulse_mod
	
	return max(final_interval, min_interval)

func get_current_enemy_dmg():
	var modifier = 1.2 if is_day else 0.88
	return base_enemy_dmg * modifier * pow(1.2, cycle_count)

func get_current_enemy_hp():
	var cycle_growth = pow(1.15, cycle_count)
	

	var noon_factor = 0.0
	if is_day:
		var day_progress = (current_time - 6.0) / 12.0
		noon_factor = 1.5 - abs(day_progress - 0.5) * 2.0
	
	var time_surge = 1.0 + (noon_factor * 0.5)
	
	var night_surge = 0.7 if not is_day else 1.0

	return base_enemy_hp * cycle_growth * night_surge * time_surge

func get_current_enemy_speed():
	var modifier = 1.1 if is_day else 0.9
	return base_enemy_speed * modifier * pow(1.1, cycle_count)

func get_money_for_kill():
	var cycle_bonus = 1.0 + (cycle_count * 0.15)
	var modifier = 1.0 if is_day else 2.5
	return int(money_per_kill * modifier * cycle_bonus)

func get_enemy_hue_seed():
	return cycle_count * 0.618033988  # unbounded golden ratio drift

func get_enemy_mutation():
	# clamped at 1.0 so shader params stay predictable
	var cycle_contribution = (cycle_count - 1) * mutation_rate
	return clamp(cycle_contribution, 0.0, 1.0)

func stats():
	var stats_string = """		[color=gray]HP[/color]          			%.1f/%.1f
		[color=gray]Regen[/color]       			%.2f/s
		[color=gray]Money[/color]       			+$%d/kill
		[color=gray]Click dmg[/color]   			%.1f
		[color=gray]Bullet speed[/color]   			%.1f px/s
	""" % [
		health, max_health,
		regen,
		get_money_for_kill(),
		click_dmg,
		bullet_speed,
	]

	if auto_turret_enabled:
		stats_string = stats_string + """	[color=RED]Auto dmg[/color]    			%.1f
		[color=RED]Auto fire rate[/color]    		%.1f s/shot
		[color=RED]Auto bullet speed[/color]    	%.1f px/s
		[color=RED]Auto targets[/color]    		%.1f
		""" % [
			auto_dmg,
			auto_fire_rate,
			auto_bullet_speed,
			auto_targets,
		]

	return stats_string

func debug_stats():
	var m = get_enemy_mutation()
	var h = get_enemy_hue_seed()
	var phase = "[color=yellow]DAY[/color]" if is_day else "[color=cyan]NIGHT[/color]"

	var debug_string = """[b]── WORLD ──[/b]
[color=gray]Clock[/color]       %s  %s
[color=gray]Cycle[/color]       %d
[color=gray]Spawn rate[/color]  %.2fs

[b]── ENEMY ──[/b]
[color=gray]HP[/color]          %.1f
[color=gray]Dmg[/color]         %.1f
[color=gray]Speed[/color]       %.1f
[color=gray]Mutation[/color]    %.2f  [color=green]%s[/color]
[color=gray]Hue seed[/color]    %.3f

[b]── UPGRADES ──[/b]
%s""" % [
			get_clock_string(), phase,
			cycle_count,
			get_spawn_interval(),
			get_current_enemy_hp(),
			get_current_enemy_dmg(),
			get_current_enemy_speed(),
			m, _mutation_bar(m),
			h,
			_upgrade_lines()
		]

	return debug_string

func _mutation_bar(m: float):
	var filled = int(m * 10)
	return "[" + "█".repeat(filled) + "░".repeat(10 - filled) + "]"

func format_cost(n: int):
	if n >= 1_000_000_000:
		return "$%.1fB" % (n / 1_000_000_000.0)
	elif n >= 1_000_000:
		return "$%.1fM" % (n / 1_000_000.0)
	elif n >= 1_000:
		return "$%.1fK" % (n / 1_000.0)
	return "$%d" % n

func _upgrade_lines():
	var lines = ""
	for id in upgrades:
		var d = upgrades[id]
		var cost_str = "$%d" % d["cost"]
		var locked = " [color=gray](locked)[/color]" if d.get("requires", "") != "" and upgrades[d.get("requires", "")]["level"] == 0 else ""
		lines += "[color=gray]%-24s[/color] Lv.%d  %s%s\n" % [d["title"], d["level"], cost_str, locked]
	return lines

func pause():
	is_pause = !is_pause
	get_tree().paused = !get_tree().paused
	print("is_pause ", is_pause)

func start():
	# Reset game state
	health = max_health
	is_day = true
	is_pause = false
	is_over = false
	current_time = 6.0
	cycle_count = 0
	money = 0
	
	# Reset player stats to defaults
	max_health = 25.0
	regen = 1.0
	click_fire_rate = 0.5
	click_dmg = 10
	bullet_speed = 600.0
	auto_turret_enabled = false
	auto_dmg = 7.0
	auto_fire_rate = 1.5
	auto_bullet_speed = 500.0
	auto_targets = 1
	money_per_kill = 10

	base_enemy_hp = 10.0
	base_enemy_dmg = 5.0
	base_enemy_speed = 220
	base_spawn_rate = 1.8
	
	# Reset all upgrade levels and costs
	upgrades["money"]["level"] = 0
	upgrades["money"]["cost"] = 20
	upgrades["max_hp"]["level"] = 0
	upgrades["max_hp"]["cost"] = 25
	upgrades["hp_regen"]["level"] = 0
	upgrades["hp_regen"]["cost"] = 30
	upgrades["bullet_dmg"]["level"] = 0
	upgrades["bullet_dmg"]["cost"] = 30
	upgrades["bullet_speed"]["level"] = 0
	upgrades["bullet_speed"]["cost"] = 25
	upgrades["auto_turret"]["level"] = 0
	upgrades["auto_turret"]["cost"] = 200
	upgrades["auto_turret_dmg"]["level"] = 0
	upgrades["auto_turret_dmg"]["cost"] = 50
	upgrades["auto_turret_fire_rate"]["level"] = 0
	upgrades["auto_turret_fire_rate"]["cost"] = 75
	upgrades["auto_turret_bullet_speed"]["level"] = 0
	upgrades["auto_turret_bullet_speed"]["cost"] = 50
	upgrades["auto_turret_targets"]["level"] = 0
	upgrades["auto_turret_targets"]["cost"] = 1000
	
	GameManager.player.reset_bullet_speed()

	# Reset entities
	spawner.despawn()
	player.despawn()

func game_over():
	is_start = false
	is_over = true
	get_tree().paused = true
