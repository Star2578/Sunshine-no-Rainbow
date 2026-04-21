extends Area2D
class_name Bullet

@onready var shoot_sfx: AudioStreamPlayer2D = %ShootBulletSFX

var is_active: bool = false

var speed: float
var dmg: float

func _ready():
	speed = GameManager.bullet_speed

func _physics_process(delta: float):
	if not is_active:
		return
	
	position += transform.x * speed * delta

func fire():
	is_active = true
	shoot_sfx.play()
	show()
	process_mode = PROCESS_MODE_INHERIT
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", false)

func deactivate():
	is_active = false
	hide()
	set_deferred("process_mode", PROCESS_MODE_DISABLED)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", true)

func _on_bullet_hit(area: Area2D):
	if area is Enemy:
		area.receive_dmg(dmg)
		deactivate()

func _on_screen_exit():
	if is_active:
		deactivate()
