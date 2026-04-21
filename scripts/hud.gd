extends CanvasLayer
class_name HUD

@onready var main_menu: Control = %MainMenu
@onready var settings: Control = %Settings
@onready var retry: Control = %Retry
@onready var upgrade_list: BoxContainer = %UpgradeList
@onready var money_label: Label = %MoneyLabel
@onready var stats_text: RichTextLabel = %Stats
@onready var debug_text: RichTextLabel = %DebugText
@onready var gameover_text: RichTextLabel = %GameOver_Stats

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
		var phase = "DAY" if GameManager.is_day else "NIGHT"
		clock.text = phase + " " + str(GameManager.cycle_count) + " " + GameManager.get_clock_string()
		money_label.text = "$" + str(GameManager.money)

		stats_text.text = GameManager.stats()
		debug_text.text = GameManager.debug_stats()

		%GameBackground.material.set_shader_parameter("health", GameManager.health / GameManager.max_health)

		if GameManager.is_pause:
			%Pause.show()
			settings.show()
			upgrade_list.hide()
		else:
			%Pause.hide()
			settings.hide()
			upgrade_list.show()

	if ui_stack.size() > 1:
		%BackButton.show()
	else:
		%BackButton.hide()


	if GameManager.is_over:
		upgrade_list.hide()
		%GameOver.show()
		%Retry.show()
	


func _on_start_pressed():
	GameManager.start()
	# Close all menus and start game
	for menu in ui_stack:
		menu.hide()

	for id in GameManager.upgrades:
		var data = GameManager.upgrades[id]
		# Skip locked child upgrades at start
		if data.has("requires"):
			continue
		create_upgrade_ui(id, data["title"], data["cost"])

	ui_stack.clear()
	GameManager.is_start = true

func _on_settings_pressed():
	open_menu(settings)

func _on_quit_pressed():
	get_tree().quit()

func _on_back_pressed():
	go_back()

func _on_retry_pressed():
	GameManager.is_start = true
	GameManager.is_over = false
	get_tree().paused = false
	%GameOver.hide()
	%Retry.hide()
	upgrade_list.show()
	for child in upgrade_list.get_children():
		child.queue_free()
	_on_start_pressed()

func _on_bgm_slider_value_changed(value: float):
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(bgm_bus_idx, db_value)
	
	AudioServer.set_bus_mute(bgm_bus_idx, value < 0.01)

func _on_sfx_slider_value_changed(value: float):
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(sfx_bus_idx, db_value)
	
	AudioServer.set_bus_mute(sfx_bus_idx, value < 0.01)

func create_upgrade_ui(id: String, title: String, cost: int):
	var item: UpgradeItem = upgrade_item_scene.instantiate()
	upgrade_list.add_child(item)
	
	item.setup(id, title, cost)
	
	item.purchased.connect(_on_upgrade_bought)

func _on_upgrade_bought(id: String):
	if GameManager.attempt_purchase(id):
		apply_upgrade_effect(id)
		var new_data = GameManager.upgrades[id]
		for child in upgrade_list.get_children():
			if child is UpgradeItem and child.upgrade_id == id:
				# One-time upgrade: destroy the button after buying
				if new_data.get("one_time", false):
					child.queue_free()
				else:
					child.update_ui(new_data["level"], new_data["cost"])
				break

func _reveal_locked_upgrades(parent_id: String):
	for id in GameManager.upgrades:
		var data = GameManager.upgrades[id]
		if data.get("requires", "") == parent_id:
			create_upgrade_ui(id, data["title"], data["cost"])

func apply_upgrade_effect(id: String):
	match id:
		"money":
			GameManager.money_per_kill += 5
		"max_hp":
			var new_hp = GameManager.health / GameManager.max_health
			GameManager.max_health += 5
			GameManager.health = new_hp * GameManager.max_health
		"hp_regen":
			GameManager.regen += 0.3
		"bullet_dmg":
			GameManager.click_dmg += 2.0
			GameManager.auto_dmg += 1.0
		"bullet_speed":
			# Update bullet speed via player reference
			GameManager.player.set_bullet_speed(50.0)
		"auto_turret":
			GameManager.auto_turret_enabled = true
			GameManager.player.enable_auto_turret()
			_reveal_locked_upgrades("auto_turret")
		"auto_turret_dmg":
			GameManager.auto_dmg += 2.0
		"auto_turret_fire_rate":
			GameManager.auto_fire_rate = max(0.2, GameManager.auto_fire_rate - 0.15)
		"auto_turret_bullet_speed":
			GameManager.auto_bullet_speed += 50.0
		"auto_turret_targets":
			GameManager.auto_targets += 1
