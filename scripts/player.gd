extends Area2D
class_name Player


var pool_size: int = 50
var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var bullet_pool: Array = []
var pool_index: int = 0
var click_timer: float = 0.0
var can_shoot: bool = true
var is_mouse_held: bool = false

# --- Auto turret ---
var auto_bullet_pool: Array = []
var auto_pool_index: int = 0
var _auto_timer: float = 0.0

func _ready():
	GameManager.player = self
	# Pre-fill the pool
	for i in range(pool_size):
		var b: Bullet = bullet_scene.instantiate()
		b.hide() # Keep it invisible
		b.dmg = GameManager.click_dmg
		b.process_mode = PROCESS_MODE_DISABLED # Don't let it move/calculate physics
		%BulletContainer.add_child(b)
		bullet_pool.append(b)

func _input(event: InputEvent):
	if not GameManager.is_start:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_mouse_held = true
		else:
			is_mouse_held = false

func shoot():
	var b = bullet_pool[pool_index]
	
	# If the current bullet is still active, the pool is too small!
	if b.is_active:
		b = bullet_scene.instantiate()
		b.hide()
		b.dmg = GameManager.click_dmg
		b.process_mode = PROCESS_MODE_DISABLED
		%BulletContainer.add_child(b)
		# Insert it so we don't mess up the sequence
		bullet_pool.insert(pool_index, b)
		print("Bullet pool expanded to: ", bullet_pool.size())

	# Standard activation
	b.global_position = global_position
	b.look_at(get_global_mouse_position())

	# Set pressure from damage upgrade level
	var dmg_level = GameManager.upgrades["bullet_dmg"]["level"]
	var mat = b.get_node("Sprite2D").material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("time_offset", randf() * 100.0)
		mat.set_shader_parameter("pressure", clamp(dmg_level / 3.0, 0.0, 1.0))

	b.fire()
	pool_index = (pool_index + 1) % bullet_pool.size()

func enable_auto_turret():
	# Build the pool on first enable (lazy init)
	if auto_bullet_pool.is_empty():
		for i in range(20):
			var b: Bullet = bullet_scene.instantiate()
			b.hide()
			b.dmg = GameManager.auto_dmg
			b.speed = GameManager.auto_bullet_speed
			b.process_mode = PROCESS_MODE_DISABLED
			%BulletContainer.add_child(b)
			auto_bullet_pool.append(b)

func _process(delta: float):
	if not GameManager.is_start:
		return
	
	if not can_shoot:
		click_timer += delta
		if click_timer >= GameManager.click_fire_rate:
			click_timer = 0.0
			can_shoot = true
	
	# Fire if mouse is held and we can shoot
	if is_mouse_held and can_shoot:
		can_shoot = false
		shoot()

	if GameManager.auto_turret_enabled:
		_auto_timer += delta
		if _auto_timer >= GameManager.auto_fire_rate:
			_auto_timer = 0.0
			auto_shoot()

func auto_shoot():
	var targets = _find_nearest_enemies(GameManager.auto_targets)
	if targets.is_empty():
		return

	for i in range(targets.size()):
		_fire_auto_bullet_at(targets[i], i * 0.05)  # small stagger delay

func _find_nearest_enemies(count: int) -> Array:
	# Gather all active enemies with their distances
	var candidates = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and node.is_active:
			candidates.append({
				"enemy": node,
				"dist": global_position.distance_to(node.global_position)
			})
	
	# Sort by distance, nearest first
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	
	# Return up to `count` enemies (if fewer exist, return all)
	var result = []
	for i in range(min(count, candidates.size())):
		result.append(candidates[i]["enemy"])
	return result

func _fire_auto_bullet_at(target: Enemy, delay: float = 0.0):
	var b = auto_bullet_pool[auto_pool_index]
	auto_pool_index = (auto_pool_index + 1) % auto_bullet_pool.size()  # advance BEFORE insert check

	if b.is_active:
		b = bullet_scene.instantiate()
		b.hide()
		b.process_mode = PROCESS_MODE_DISABLED
		var sprite = b.get_node("Sprite2D")
		sprite.material = sprite.material.duplicate()
		%BulletContainer.add_child(b)
		auto_bullet_pool.append(b)  # append instead of insert, keeps indices stable

	b.dmg = GameManager.auto_dmg
	b.speed = GameManager.auto_bullet_speed
	b.global_position = global_position
	b.look_at(target.global_position)

	var mat = b.get_node("Sprite2D").material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("time_offset", randf() * 100.0)
		mat.set_shader_parameter("pressure", clamp(
			GameManager.upgrades["bullet_dmg"]["level"] / 3.0, 0.0, 1.0
		))

	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(b.fire)
	else:
		b.fire()

func set_bullet_speed(bonus: float):
	for b in bullet_pool:
		b.speed += bonus

func reset_bullet_speed():
	for b in bullet_pool:
		b.speed = GameManager.bullet_speed
	for b in auto_bullet_pool:
		b.speed = GameManager.auto_bullet_speed

func despawn():
	for bullet in bullet_pool:
		bullet.deactivate()