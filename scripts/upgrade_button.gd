extends ColorRect
class_name UpgradeItem

signal purchased(upgrade_name)

@onready var name_label = %NameLabel
@onready var buy_button = %BuyButton
@onready var level_label = %LevelLabel

var upgrade_id: String = ""
var current_cost: int = 10

func _process(_delta):
	# If we can't afford it, make the button look disabled
	if GameManager.money < current_cost:
		buy_button.disabled = true
		buy_button.modulate = Color(0.5, 0.5, 0.5) # Dim it
	else:
		buy_button.disabled = false
		buy_button.modulate = Color.WHITE # "Refresh" it to bright color

func setup(id: String, display_name: String, cost: int):
	upgrade_id = id
	name_label.text = display_name
	current_cost = cost
	buy_button.text = "$" + str(cost)

func _on_buy_button_pressed():
	# Emit the signal so the HUD knows which upgrade was clicked
	purchased.emit(upgrade_id)

func update_ui(new_level: int, new_cost: int):
	level_label.text = "Lv." + str(new_level)
	current_cost = new_cost
	buy_button.text = "$" + str(new_cost)
