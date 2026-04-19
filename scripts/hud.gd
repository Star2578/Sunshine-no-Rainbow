extends CanvasLayer

@onready var main_menu: CanvasLayer = %MainMenu
@onready var settings: CanvasLayer = %Settings

@onready var bgm_bus_idx = AudioServer.get_bus_index("BGM")
@onready var sfx_bus_idx = AudioServer.get_bus_index("SFX")

func _on_start_pressed():
	main_menu.hide()
	settings.hide()
	GameManager.is_start = true

func _on_bgm_slider_value_changed(value: float):
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(bgm_bus_idx, db_value)
	
	AudioServer.set_bus_mute(bgm_bus_idx, value < 0.01)

func _on_sfx_slider_value_changed(value: float):
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(sfx_bus_idx, db_value)
	
	AudioServer.set_bus_mute(sfx_bus_idx, value < 0.01)