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

@onready var text_popup: PackedScene = preload("res://scenes/ui/popup_text.tscn")
@onready var text_container: Control = %TextPoolContainer
var text_pool: Array = []
var pool_index: int = 0
var pool_size: int = 30

@onready var bgm_bus_idx = AudioServer.get_bus_index("BGM")
@onready var sfx_bus_idx = AudioServer.get_bus_index("SFX")

func _ready():
	GameManager.hud = self
	for i in range(1, 10):
		var action_name = "upgrade_%d" % i
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var ev = InputEventKey.new()
			ev.keycode = KEY_1 + (i - 1)
			InputMap.action_add_event(action_name, ev)
	# Start by showing Main Menu
	open_menu(main_menu)
	for i in range(pool_size):
		var t: RichTextLabel = text_popup.instantiate()
		t.hide()
		t.process_mode = PROCESS_MODE_DISABLED
		text_container.add_child(t)
		text_pool.append(t)

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
		money_label.text = GameManager.format_cost(GameManager.money)

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

func _input(event: InputEvent):
	if not GameManager.is_start or GameManager.is_pause or GameManager.is_over:
		return
	for i in range(1, 10):
		if Input.is_action_just_pressed("upgrade_%d" % i):
			var children = upgrade_list.get_children()
			var idx = i - 1
			if idx < children.size() and children[idx] is UpgradeItem:
				children[idx].trigger_purchase()

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

func spawn_text_popup(text: String, world_pos: Vector2):
	var t: RichTextLabel = text_pool[pool_index]

	if t.has_meta("tween"):
		var old_tween = t.get_meta("tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()

	var screen_pos = get_viewport().get_canvas_transform() * world_pos

	# Reset node state before reuse
	t.modulate.a = 1.0
	t.global_position = screen_pos
	t.global_position.x -= 150
	t.text = "[center]" + text + "[/center]"
	t.show()
	t.process_mode = PROCESS_MODE_INHERIT

	var tween = t.create_tween()
	t.set_meta("tween", tween)  # Store reference so we can kill it on reuse

	tween.set_parallel(true)
	tween.tween_property(t, "global_position:y", world_pos.y - 40.0, 0.8)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(t, "modulate:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# When done, return node to pool instead of freeing it
	tween.tween_callback(_return_to_pool.bind(t)).set_delay(0.8)

	pool_index = (pool_index + 1) % text_pool.size()

func _return_to_pool(t: RichTextLabel):
	t.hide()
	t.process_mode = PROCESS_MODE_DISABLED
	t.modulate.a = 1.0  # Reset alpha so it's clean for next use

func create_upgrade_ui(id: String, title: String, cost: int):
	var item: UpgradeItem = upgrade_item_scene.instantiate()
	upgrade_list.add_child(item)
	
	item.setup(id, title, cost)
	
	item.purchased.connect(_on_upgrade_bought)

	_reassign_hotkeys()

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
		_reassign_hotkeys()

func _reveal_locked_upgrades(parent_id: String):
	for id in GameManager.upgrades:
		var data = GameManager.upgrades[id]
		if data.get("requires", "") == parent_id:
			create_upgrade_ui(id, data["title"], data["cost"])

func apply_upgrade_effect(id: String):
	match id:
		"money":
			var level = GameManager.upgrades["money"]["level"]
			GameManager.money_per_kill += 5 * level
			GameManager.base_enemy_hp += 0.25
		"max_hp":
			var new_hp = GameManager.health / GameManager.max_health
			GameManager.max_health += 5
			GameManager.health = new_hp * GameManager.max_health
			GameManager.base_enemy_dmg += 1.0
			GameManager.base_enemy_hp += 1
		"hp_regen":
			GameManager.regen += 0.5
			GameManager.base_enemy_dmg += 0.1
			GameManager.base_enemy_hp += 0.1
		"bullet_dmg":
			GameManager.click_dmg += 2.5
			GameManager.auto_dmg += 1.5
			GameManager.base_enemy_hp += 1
			GameManager.base_spawn_rate -= 0.01
		"bullet_speed":
			# Update bullet speed via player reference
			GameManager.player.set_bullet_speed(50.0)
			GameManager.base_enemy_hp += 0.1
			GameManager.base_enemy_speed += 0.5
		"auto_turret":
			GameManager.auto_turret_enabled = true
			GameManager.player.enable_auto_turret()
			GameManager.base_spawn_rate -= 0.05
			GameManager.base_enemy_hp += 2
			_reveal_locked_upgrades("auto_turret")
		"auto_turret_dmg":
			GameManager.auto_dmg += 2.5
			GameManager.base_enemy_hp += 1.5
		"auto_turret_fire_rate":
			GameManager.auto_fire_rate = max(0.2, GameManager.auto_fire_rate - GameManager.auto_fire_rate * 0.15)
			GameManager.base_enemy_hp += 4.0
			GameManager.base_spawn_rate -= 0.01
		"auto_turret_bullet_speed":
			GameManager.auto_bullet_speed += 50.0
			GameManager.base_enemy_speed += 0.5
			GameManager.base_enemy_hp += 0.1
		"auto_turret_targets":
			GameManager.auto_targets += 1
			GameManager.base_spawn_rate -= 0.3
			GameManager.base_enemy_hp += 5.0

func _reassign_hotkeys():
	var children = upgrade_list.get_children()
	for i in range(children.size()):
		var child = children[i]
		if child is UpgradeItem:
			var hotkey = i + 1  # 1-indexed
			if hotkey <= 9:
				child.set_hotkey(hotkey)
			else:
				child.set_hotkey(0)
