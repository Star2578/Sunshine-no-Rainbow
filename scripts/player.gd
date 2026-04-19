extends Area2D
class_name Player

@export var pool_size: int = 50
var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var bullet_pool: Array = []
var pool_index: int = 0

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
	# Grab the next bullet in the array
	var b = bullet_pool[pool_index]
	
	# Reset and activate it
	b.global_position = global_position
	b.look_at(get_global_mouse_position())
	b.show()
	b.process_mode = PROCESS_MODE_INHERIT
	
	# If your bullet has a specific 'reset' function, call it here
	if b.has_method("fire"):
		b.fire()

	# Cycle the index (wraps around back to 0)
	pool_index = (pool_index + 1) % pool_size