extends Node

var is_start: bool = false
var is_day: bool = true

# Time variables
var current_time: float = 6.0 # Start at 6:00 AM
var time_speed: float = 0.05   # How many "in-game hours" pass per real second
var cycle_count: int = 1

var player: Player = null
var money: int = 0
var base_enemy_hp: float = 10.0

func _process(delta: float):
	if not is_start: return
	
	# Progress time
	current_time += delta * time_speed
	
	# Handle Day/Night switch
	# 6:00 to 18:00 (6AM - 6PM) is Day
	if current_time >= 6.0 and current_time < 18.0:
		is_day = true
	else:
		is_day = false

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


func get_current_enemy_hp():
	return base_enemy_hp * pow(1.15, cycle_count)

func get_current_enemy_speed():
	var modifier = 1.2 if is_day else 0.8
	return 200.0 * modifier * (1.05 ** cycle_count)