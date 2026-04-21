extends Area2D
class_name Enemy

var is_active: bool = false
var speed: float
var hp: float

@onready var sparks: GPUParticles2D = $SparksParticles
@onready var glitter: GPUParticles2D = $GlitterParticles
@onready var orbit: GPUParticles2D = $OrbitParticles

func _ready():
	speed = GameManager.get_current_enemy_speed()
	hp = GameManager.get_current_enemy_hp()
	add_to_group("enemies")
	_setup_particles()

func _physics_process(delta: float):
	if not is_active: return
	if GameManager.player:
		look_at(GameManager.player.global_position)
	position += transform.x * speed * delta

func spawn(start_pos: Vector2):
	global_position = start_pos
	is_active = true
	show()
	process_mode = PROCESS_MODE_INHERIT
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", false)
	if GameManager.player:
		look_at(GameManager.player.global_position)

	hp = GameManager.get_current_enemy_hp()
	speed = GameManager.get_current_enemy_speed()
	var mat = $Sprite2D.material as ShaderMaterial
	mat.set_shader_parameter("time_offset", randf() * 100.0)  # large range so they're well spread
	_apply_shader_params()

func deactivate():
	is_active = false
	hide()
	set_deferred("process_mode", PROCESS_MODE_DISABLED)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", true)
	# Stop particles but don't kill existing ones mid-air
	sparks.emitting = false
	glitter.emitting = false
	orbit.emitting = false

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
			GameManager.game_over()

# ----------------------------------------------------------
# SHADER
# ----------------------------------------------------------
func _apply_shader_params():
	var mat = $Sprite2D.material as ShaderMaterial
	if not mat: return
	var m = GameManager.get_enemy_mutation()
	var h = GameManager.get_enemy_hue_seed()
	mat.set_shader_parameter("mutation", m)
	mat.set_shader_parameter("hue_seed", h)
	_apply_particle_state(m, h)

func _apply_particle_state(m: float, h: float):
	# Sparks: kick in early
	sparks.emitting = m >= 0.2
	sparks.amount = int(remap(m, 1, 5, 10, 20))

	# Glitter: mid mutation
	glitter.emitting = m >= 0.5
	glitter.amount = int(remap(m, 1, 5, 10, 24))

	# Orbit: high mutation only
	orbit.emitting = m >= 0.8
	orbit.amount = int(remap(m, 1, 5, 10, 20))

	# Tint particles to match hue territory so they don't fight the shader
	# hue_seed drives the color: we approximate it in a simple gradient
	# low hue = warm, mid = cool, high = pale/void
	var hue_frac = fposmod(h, 1.0)
	var particle_color = Color.from_hsv(hue_frac, 0.8, 1.0)
	_tint_particle(orbit, particle_color)

# ----------------------------------------------------------
# PARTICLE SETUP — runs once in _ready, sets all materials
# ----------------------------------------------------------
func _setup_particles():
	_setup_sparks()
	_setup_glitter()
	_setup_orbit()

func _setup_sparks():
	var mat = ParticleProcessMaterial.new()

	# Spawn in a ring around the sun edge
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 24.0
	mat.emission_ring_inner_radius = 20.0
	mat.emission_ring_axis = Vector3(0, 0, 1)

	# Shoot outward
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0           # full sphere from ring = radial outward
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 160.0

	# Gravity: none — space sun
	mat.gravity = Vector3.ZERO

	# Shrink and fade as they travel
	mat.scale_min = 0.8
	mat.scale_max = 1.8
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	mat.scale_curve = scale_curve

	mat.color = Color(1.0, 0.7, 0.2, 1.0)   # warm orange base
	var color_ramp = Gradient.new()
	color_ramp.add_point(0.0, Color(1.0, 0.9, 0.3, 1.0))  # bright yellow born
	color_ramp.add_point(0.6, Color(1.0, 0.4, 0.1, 0.8))  # orange mid
	color_ramp.add_point(1.0, Color(0.8, 0.1, 0.0, 0.0))  # red fade out
	mat.color_ramp = color_ramp

	mat.damping_min = 40.0
	mat.damping_max = 80.0       # slows down as it travels (solar drag feel)

	sparks.process_material = mat
	sparks.lifetime = 0.8
	sparks.explosiveness = 0.0   # continuous stream
	sparks.randomness = 0.4
	sparks.emitting = false
	sparks.amount = 8

func _setup_glitter():
	var mat = ParticleProcessMaterial.new()

	# Scatter from inside the body
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 20.0

	# Slow drift in all directions
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3.ZERO

	# Tiny, stay tiny
	mat.scale_min = 0.3
	mat.scale_max = 0.9

	# Flicker alpha — the key glitter feel
	var color_ramp = Gradient.new()
	color_ramp.add_point(0.0,  Color(1.0, 1.0, 1.0, 0.0))   # born invisible
	color_ramp.add_point(0.2,  Color(1.0, 1.0, 1.0, 1.0))   # flash on
	color_ramp.add_point(0.5,  Color(1.0, 1.0, 1.0, 0.3))   # dim
	color_ramp.add_point(0.7,  Color(1.0, 1.0, 1.0, 0.9))   # flash again
	color_ramp.add_point(1.0,  Color(1.0, 1.0, 1.0, 0.0))   # gone
	mat.color_ramp = color_ramp

	# No damping — drift forever until lifetime ends
	mat.damping_min = 0.0
	mat.damping_max = 5.0

	glitter.process_material = mat
	glitter.lifetime = 1.4
	glitter.explosiveness = 0.0
	glitter.randomness = 0.8      # very random timing = sparkle feel
	glitter.emitting = false
	glitter.amount = 12
	# Additive blend so glitter genuinely glows — set this in editor on the node:
	# CanvasItem > Material > new CanvasItemMaterial > Blend Mode = Add
	# (can't set CanvasItemMaterial in code as easily, do it once in editor)

func _setup_orbit():
	var mat = ParticleProcessMaterial.new()

	# Spawn exactly on the sun's edge
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 28.0
	mat.emission_ring_inner_radius = 26.0
	mat.emission_ring_axis = Vector3(0, 0, 1)

	# Key trick: tangential velocity makes them arc sideways not outward
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 0.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 90.0

	# Orbit feel: angular velocity spins the velocity vector
	mat.angular_velocity_min = 180.0
	mat.angular_velocity_max = 360.0

	mat.gravity = Vector3.ZERO
	mat.damping_min = 10.0
	mat.damping_max = 20.0

	mat.scale_min = 0.5
	mat.scale_max = 1.2
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.0))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	mat.scale_curve = scale_curve

	# Color is overridden per-spawn by _tint_particle to match hue territory
	mat.color = Color(0.5, 1.0, 0.8, 1.0)
	var color_ramp = Gradient.new()
	color_ramp.add_point(0.0, Color(1.0, 1.0, 1.0, 0.9))
	color_ramp.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	mat.color_ramp = color_ramp

	orbit.process_material = mat
	orbit.lifetime = 1.0
	orbit.explosiveness = 0.1
	orbit.randomness = 0.5
	orbit.emitting = false
	orbit.amount = 6

func _tint_particle(particles: GPUParticles2D, tint: Color):
	var mat = particles.process_material as ParticleProcessMaterial
	if mat:
		mat.color = tint
