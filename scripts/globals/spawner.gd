extends Node2D

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var pool_size: int = 20

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
	
	# Get the dynamic rate from GameManager
	var current_rate = GameManager.get_spawn_interval()
	
	if timer >= current_rate:
		spawn_from_pool()
		timer = 0.0

func spawn_from_pool():
	var t = target_pool[pool_index]
	
	# If the current index is active, the pool is "too small" for this spawn rate
	if t.is_active:
		# Expand the pool by 1 on the fly
		t = enemy_scene.instantiate()
		t.hide()
		t.process_mode = PROCESS_MODE_DISABLED
		add_child(t)
		target_pool.insert(pool_index, t) # Insert so we don't skip the index
		print("Pool expanded to: ", target_pool.size())

	var view_size = get_viewport_rect().size
	var spawn_radius = view_size.length() / 1.5 
	var random_angle = randf() * TAU
	var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * spawn_radius
	t.spawn((view_size / 2) + spawn_offset)
	
	pool_index = (pool_index + 1) % target_pool.size()
