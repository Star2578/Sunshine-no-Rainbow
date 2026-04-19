extends CanvasLayer
class_name HUD

@onready var main_menu: Control = %MainMenu
@onready var settings: Control = %Settings

var ui_stack: Array[Control] = []

@onready var clock: Label = %Clock

@onready var bgm_bus_idx = AudioServer.get_bus_index("BGM")
@onready var sfx_bus_idx = AudioServer.get_bus_index("SFX")

func _ready():
	# Start by showing Main Menu
	open_menu(main_menu)

func open_menu(menu: Control):
	# Hide the current menu if there is one
	if ui_stack.size() > 0:
		ui_stack.back().hide()
	
	# Add new menu to stack and show it
	ui_stack.append(menu)
	menu.show()

func go_back():
	if ui_stack.size() > 1:
		var current_menu = ui_stack.pop_back()
		current_menu.hide()
		
		# Show the previous menu
		ui_stack.back().show()
	else:
		# If only 1 menu is left (like Main Menu), 
		# maybe hitting back does nothing or closes everything
		pass

func _process(_delta: float):
	if GameManager.is_start:
		clock.text = GameManager.get_clock_string()

func _on_start_pressed():
	# Close all menus and start game
	for menu in ui_stack:
		menu.hide()
	ui_stack.clear()
	GameManager.is_start = true

func _on_settings_pressed():
	open_menu(settings)

func _on_quit_pressed():
	get_tree().quit()

func _on_back_pressed():
	go_back()

func _on_bgm_slider_value_changed(value: float):
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(bgm_bus_idx, db_value)
	
	AudioServer.set_bus_mute(bgm_bus_idx, value < 0.01)

func _on_sfx_slider_value_changed(value: float):
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(sfx_bus_idx, db_value)
	
	AudioServer.set_bus_mute(sfx_bus_idx, value < 0.01)