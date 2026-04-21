extends Node

var is_start: bool = false
var is_day: bool = true

# Time variables
var current_time: float = 6.0 # Start at 6:00 AM
var time_speed: float = 0.05   # How many "in-game hours" pass per real second
var cycle_count: int = 0

# Player variables
var player: Player = null
var max_health: float = 10.0
var health: float = 10.0
var regen: float = 1.0
var bullet_click_dmg: float = 5.0
var bullet_auto_dmg: float = 2.0
var money_per_kill: int = 10
var money: int = 0

# Enemy variables
var base_enemy_hp: float = 10.0
var base_enemy_dmg: float = 2.0
var base_enemy_speed: float = 200.0
var mutation_rate: float = 0.25  # tune this: 0.1 = slow creep, 0.5 = fast madness

# Dictionary to hold the state of every upgrade
# Key: ID, Value: {level, base_cost, cost_multiplier}
var upgrades: Dictionary = {
	"money": {
		"title": "Money Per Kill",
		"level": 0, 
		"cost": 10, 
		"mult": 1.5
	},
	"max_hp": {
		"title": "Max HP",
		"level": 0, 
		"cost": 10, 
		"mult": 1.5
	},
	"hp_regen": {
		"title": "HP Regen",
		"level": 0, 
		"cost": 10, 
		"mult": 1.5
	},
	"bullet_dmg": {
		"title": "Bullet Damage",
		"level": 0, 
		"cost": 25, 
		"mult": 1.8
	},
	"bullet_speed": {
		"title": "Bullet Speed",
		"level": 0, 
		"cost": 25, 
		"mult": 1.8
	},
	"auto_turret": {
		"title": "Auto Turret",
		"level": 0, 
		"cost": 100, 
		"mult": 2.0,
		"one_time": true
	},
	"auto_turret_dmg": {
		"title": "Turret Damage",
		"level": 0, "cost": 50, "mult": 1.8,
		"requires": "auto_turret"
	},
	"auto_turret_fire_rate": {
		"title": "Turret Fire Rate",
		"level": 0, "cost": 50, "mult": 1.8,
		"requires": "auto_turret"
	},
	"auto_turret_bullet_speed": {
		"title": "Turret Bullet Speed",
		"level": 0, "cost": 40, "mult": 1.6,
		"requires": "auto_turret"
	},
	"auto_turret_targets": {
		"title": "Turret Targets",
		"level": 0, "cost": 1000, "mult": 2,
		"requires": "auto_turret"
	}
}

func _process(delta: float):
	if not is_start: return

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
	var base_rate = 1.0
	
	# 1. Scaling: Make it faster every cycle (e.g., 5% faster per cycle)
	var scaled_rate = base_rate * pow(0.95, cycle_count - 1)
	
	# 2. Time of Day Modifier:
	# Let's make Noon (12.0) and Midnight (0.0) the fastest points.
	# We use a sin wave or absolute distance from "peak" times.
	var time_factor = 1.0
	
	if is_day:
		# Day: Enemies spawn faster as it gets closer to 12:00 PM
		# abs(current_time - 12) gives distance from noon. 
		# We normalize it so 12:00 = 0.5 multiplier (twice as fast)
		time_factor = remap(abs(current_time - 12.0), 0.0, 6.0, 0.5, 1.0)
	else:
		# Night: Maybe a steadier, slower pace for farming resources?
		# Or faster at Midnight (0.0/24.0)
		var dist_from_midnight = min(current_time, abs(24.0 - current_time))
		time_factor = remap(dist_from_midnight, 0.0, 6.0, 0.7, 1.2)
		
	# Final clamping to prevent it from going to 0 (which would crash the game)
	return max(scaled_rate * time_factor, 0.1)

func get_current_enemy_dmg():
	var modifier = 1.2 if is_day else 0.7
	return base_enemy_dmg * modifier * pow(1.1, cycle_count - 1)

func get_current_enemy_hp():
	var modifier = 1.0 if is_day else 0.6   # night = less HP
	return base_enemy_hp * modifier * pow(1.15, cycle_count)

func get_current_enemy_speed():
	var modifier = 1.1 if is_day else 0.9
	return base_enemy_speed * modifier * pow(1.1, cycle_count)

func get_money_for_kill():
	var modifier = 1 if is_day else 2        # night = double money
	return int(money_per_kill * modifier)

func get_enemy_hue_seed():
	return cycle_count * 0.618033988  # unbounded golden ratio drift

func get_enemy_mutation():
	# clamped at 1.0 so shader params stay predictable
	var cycle_contribution = (cycle_count - 1) * mutation_rate
	return clamp(cycle_contribution, 0.0, 1.0)

func debug_stats():
	var m = get_enemy_mutation()
	var h = get_enemy_hue_seed()
	var phase = "[color=yellow]DAY[/color]" if is_day else "[color=cyan]NIGHT[/color]"

	var debug_string = """[b]── WORLD ──[/b]
	[color=gray]Clock[/color]       %s  %s
	[color=gray]Cycle[/color]       %d
	[color=gray]Spawn rate[/color]  %.2fs
	
	[b]── PLAYER ──[/b]
	[color=gray]HP[/color]          %.1f / %.1f
	[color=gray]Regen[/color]       %.2f/s
	[color=gray]Money[/color]       $%d  (+$%d/kill)
	[color=gray]Click dmg[/color]   %.1f
	[color=gray]Auto dmg[/color]    %.1f
	
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
			health, max_health,
			regen,
			money, get_money_for_kill(),
			bullet_click_dmg,
			bullet_auto_dmg,
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

func _upgrade_lines():
	var lines = ""
	for id in upgrades:
		var d = upgrades[id]
		var cost_str = "$%d" % d["cost"]
		var locked = " [color=gray](locked)[/color]" if d.get("requires", "") != "" and upgrades[d.get("requires", "")]["level"] == 0 else ""
		lines += "[color=gray]%-24s[/color] Lv.%d  %s%s\n" % [d["title"], d["level"], cost_str, locked]
	return lines