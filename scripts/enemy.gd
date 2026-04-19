extends Area2D
class_name Enemy

@export var speed: float = 150.0
var is_active: bool = false

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


func _on_area_entered(area: Area2D):
	if area == GameManager.player:
		# TODO : Deal damage or trigger game over
		deactivate()
