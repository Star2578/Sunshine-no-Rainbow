extends Node2D

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var pool_size: int = 20
@export var spawn_interval: float = 2.0

var target_pool: Array = []
var pool_index: int = 0
var timer: float = 0.0

func _ready():
	# Pre-instantiate the targets
	for i in range(pool_size):
		var t = enemy_scene.instantiate()
		t.hide()
		t.process_mode = PROCESS_MODE_DISABLED
		add_child(t)
		target_pool.append(t)

func _process(delta: float):
	if not GameManager.is_start:
		return
	
	timer += delta
	if timer >= spawn_interval:
		spawn_from_pool()
		timer = 0.0

func spawn_from_pool():
	var t = target_pool[pool_index]
	
	if not t.is_active:
		var view_size = get_viewport_rect().size
		# Calculate a radius that is safely outside the screen corners
		# (Diagonal of the screen / 2 + some padding)
		var spawn_radius = view_size.length() / 1.5 
		
		# Pick a random angle in radians (0 to 360 degrees)
		var random_angle = randf() * TAU # TAU is 2 * PI
		
		# Convert polar coordinates (angle/radius) to Cartesian (x/y)
		var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * spawn_radius
		
		# Spawn relative to the center of the screen
		var center = view_size / 2
		t.spawn(center + spawn_offset)
	
	pool_index = (pool_index + 1) % pool_size