extends CanvasLayer
class_name HUD

@onready var main_menu: Control = %MainMenu
@onready var settings: Control = %Settings
@onready var upgrade_list = %UpgradeList
@onready var money_label = %MoneyLabel

var ui_stack: Array[Control] = []

@onready var upgrade_item_scene: PackedScene = preload("res://scenes/ui/upgrade_button.tscn")

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
		money_label = "$" + str(GameManager.money)

func _on_start_pressed():
	# Close all menus and start game
	for menu in ui_stack:
		menu.hide()

	for id in GameManager.upgrades:
		var data = GameManager.upgrades[id]
		create_upgrade_ui(id, data["title"], data["cost"])

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

func create_upgrade_ui(id: String, title: String, cost: int):
	var item = upgrade_item_scene.instantiate()
	upgrade_list.add_child(item)
	
	item.setup(id, title, cost)
	
	item.purchased.connect(_on_upgrade_bought)

func _on_upgrade_bought(id: String):
	print("Player wants to buy: ", id)
	# Ask GameManager if we have enough money
	if GameManager.attempt_purchase(id):
		# Update the UI after a successful buy
		var new_data = GameManager.upgrades[id]
		
		for child in upgrade_list.get_children():
			if child is UpgradeItem and child.upgrade_id == id:
				child.update_ui(new_data["level"], new_data["cost"])
				break
