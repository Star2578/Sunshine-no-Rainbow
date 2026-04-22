extends TextureRect


# Called when the node enters the scene tree for the first time.
func _ready():
	var mat = material as ShaderMaterial
	mat.set_shader_parameter("time_offset", randf() * 100.0)  # large range so they're well spread

func _process(_delta):
	_apply_shader_params()

	if not GameManager.is_day:
		modulate = Color.DARK_BLUE
	else:
		modulate = Color.WHITE

func _apply_shader_params():
	var mat = material as ShaderMaterial
	if not mat: return
	var m = GameManager.get_enemy_mutation()
	var h = GameManager.get_enemy_hue_seed()
	mat.set_shader_parameter("mutation", m)
	mat.set_shader_parameter("hue_seed", h)