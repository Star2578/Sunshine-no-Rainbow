extends Area2D
class_name Enemy

var is_active: bool = false

var speed: float
var hp: float

func _ready():
	add_to_group("enemies")
	speed = GameManager.get_current_enemy_speed()
	hp = GameManager.get_current_enemy_hp()

func _physics_process(delta: float):
	if not is_active: return
	
	if GameManager.player:
		look_at(GameManager.player.global_position)
	
	position += transform.x * speed * delta

func spawn(start_pos: Vector2):
	global_position = start_pos
	is_active = true
	show()
	# Re-enable everything
	process_mode = PROCESS_MODE_INHERIT
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", false)
	
	if GameManager.player:
		look_at(GameManager.player.global_position)

func deactivate():
	is_active = false
	hide()
	set_deferred("process_mode", PROCESS_MODE_DISABLED)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", true)

func receive_dmg(dmg: float):
	hp -= dmg
	if hp <= 0:
		GameManager.money += GameManager.get_money_for_kill()
		deactivate()

func _on_area_entered(area: Area2D):
	if area == GameManager.player:
		GameManager.health -= GameManager.get_current_enemy_dmg()
		deactivate()

		if GameManager.health <= 0:
			GameManager.health = 0
			
			print("Game Over")
			get_tree().paused = true
