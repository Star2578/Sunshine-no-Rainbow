extends Area2D
class_name Player

@export var pool_size: int = 50
var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var bullet_pool: Array = []
var pool_index: int = 0
var auto_fire_timer: float = 0.0

func _ready():
	GameManager.player = self
	
	# Pre-fill the pool
	for i in range(pool_size):
		var b = bullet_scene.instantiate()
		b.hide() # Keep it invisible
		b.process_mode = PROCESS_MODE_DISABLED # Don't let it move/calculate physics
		add_child(b) # Or add to a global "BulletContainer"
		bullet_pool.append(b)

func _input(event: InputEvent):
	if not GameManager.is_start:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			shoot()

func shoot():
	var b = bullet_pool[pool_index]
	
	# If the current bullet is still active, the pool is too small!
	if b.is_active:
		b = bullet_scene.instantiate()
		b.hide()
		b.process_mode = PROCESS_MODE_DISABLED
		add_child(b)
		# Insert it so we don't mess up the sequence
		bullet_pool.insert(pool_index, b)
		print("Bullet pool expanded to: ", bullet_pool.size())

	# Standard activation
	b.global_position = global_position
	b.look_at(get_global_mouse_position())
	b.fire()

	pool_index = (pool_index + 1) % bullet_pool.size()