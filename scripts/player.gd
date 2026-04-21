extends Area2D
class_name Player

@export var pool_size: int = 50
var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var bullet_pool: Array = []
var pool_index: int = 0

# --- Auto turret ---
var auto_bullet_pool: Array = []
var auto_pool_index: int = 0
var auto_fire_rate: float = 1.0   # seconds between shots
var auto_bullet_speed: float = 500.0
var auto_turret_enabled: bool = false
var _auto_timer: float = 0.0

func _ready():
	GameManager.player = self
	# Pre-fill the pool
	for i in range(pool_size):
		var b: Bullet = bullet_scene.instantiate()
		b.hide() # Keep it invisible
		b.dmg = GameManager.bullet_click_dmg
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
		b.dmg = GameManager.bullet_click_dmg
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

func enable_auto_turret():
	auto_turret_enabled = true
	# Build the pool on first enable (lazy init)
	if auto_bullet_pool.is_empty():
		for i in range(20):
			var b: Bullet = bullet_scene.instantiate()
			b.hide()
			b.dmg = GameManager.bullet_auto_dmg
			b.speed = auto_bullet_speed
			b.process_mode = PROCESS_MODE_DISABLED
			add_child(b)
			auto_bullet_pool.append(b)

func _process(delta: float):
	if not GameManager.is_start or not auto_turret_enabled:
		return
	_auto_timer += delta
	if _auto_timer >= auto_fire_rate:
		_auto_timer = 0.0
		auto_shoot()

func auto_shoot():
	var target = _find_nearest_enemy()
	if not target:
		return
	
	var b = auto_bullet_pool[auto_pool_index]
	if b.is_active:
		b = bullet_scene.instantiate()
		b.hide()
		b.process_mode = PROCESS_MODE_DISABLED
		add_child(b)
		auto_bullet_pool.insert(auto_pool_index, b)
	
	b.dmg = GameManager.bullet_auto_dmg
	b.speed = auto_bullet_speed
	b.global_position = global_position
	b.look_at(target.global_position)
	b.fire()
	auto_pool_index = (auto_pool_index + 1) % auto_bullet_pool.size()

func _find_nearest_enemy() -> Enemy:
	var closest: Enemy = null
	var closest_dist: float = INF
	# Walk the spawner's pool to find active enemies
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and node.is_active:
			var d = global_position.distance_to(node.global_position)
			if d < closest_dist:
				closest_dist = d
				closest = node
	return closest

func set_bullet_speed(bonus: float):
	for b in bullet_pool:
		b.speed += bonus