extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var car: CharacterBody3D
var _capsule_mesh: MeshInstance3D
var _huncho_npc: CharacterBody3D
var in_vehicle := false

const ENTER_DISTANCE := 4.0

# Day/night cycle
var _time_hours   := 8.0    # parte alle 8:00
const TIME_SPEED  := 0.04   # ore per secondo → ciclo completo ~10 min reali
var _sun: DirectionalLight3D
var _sky_mat: ProceduralSkyMaterial
var _environment: Environment
var _lamp_lights: Array = []
var _label_time: Label

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_map()
	_setup_streetlamps()
	_setup_player()
	_setup_npcs()
	_setup_car()
	_setup_camera()
	_setup_ui()
	camera.call("set_target", player)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("=== MRG City Phase 2 ===")
	print("Player at: ", player.global_position)

# ─── helpers ───────────────────────────────────────────────────────────────

func _make_mat(color: Color, emission: Color = Color.BLACK, emit_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emit_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emit_energy
	return mat

func _make_box(size: Vector3, pos: Vector3, color: Color, name_str: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	if name_str: body.name = name_str
	body.position = pos
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.material_override = _make_mat(color)
	mi.mesh = mesh
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body

func _make_visual(mesh: Mesh, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi

# ─── environment ────────────────────────────────────────────────────────────

func _setup_environment() -> void:
	var env_node := WorldEnvironment.new()
	_environment = Environment.new()
	_sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_energy = 0.6
	env_node.environment = _environment
	add_child(env_node)

func _setup_lighting() -> void:
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	add_child(_sun)

func _process(delta: float) -> void:
	_time_hours = fmod(_time_hours + delta * TIME_SPEED, 24.0)
	_update_daynight()

func _update_daynight() -> void:
	var t := _time_hours / 24.0
	# Elevazione sole: -1 a mezzanotte, +1 a mezzogiorno
	var elev_rad := sin(t * TAU - PI * 0.5)
	var sun_deg  := elev_rad * 82.0

	# Fattori
	var day_f: float    = clamp((sun_deg + 8.0) / 22.0, 0.0, 1.0)
	var golden_f: float = clamp(1.0 - abs(sun_deg) / 22.0, 0.0, 1.0) * clamp(sun_deg + 18.0, 0.0, 1.0)
	golden_f = clamp(golden_f, 0.0, 1.0)

	# Sole: rotazione
	if _sun:
		_sun.rotation_degrees.x = -sun_deg
		_sun.rotation_degrees.y = 35.0
		# Colore
		var night_col  := Color(0.50, 0.55, 0.88)
		var golden_col := Color(1.00, 0.50, 0.10)
		var day_col    := Color(1.00, 0.95, 0.82)
		var c := night_col.lerp(golden_col, golden_f)
		c = c.lerp(day_col, day_f * (1.0 - golden_f * 0.5))
		_sun.light_color  = c
		_sun.light_energy = lerpf(0.25, 1.5, day_f) * (1.0 + golden_f * 0.2)

	# Cielo
	if _sky_mat:
		var nt := Color(0.02, 0.02, 0.08)
		var dt := Color(0.08, 0.22, 0.60)
		var gt := Color(0.18, 0.10, 0.04)
		_sky_mat.sky_top_color = nt.lerp(dt, day_f).lerp(gt, golden_f * 0.5)

		var nh := Color(0.05, 0.03, 0.02)
		var dh := Color(0.52, 0.70, 0.90)
		var gh := Color(0.98, 0.40, 0.06)
		var hor := nh.lerp(dh, day_f).lerp(gh, golden_f * 0.85)
		_sky_mat.sky_horizon_color    = hor
		_sky_mat.ground_horizon_color = hor * 0.35
		_sky_mat.ground_bottom_color  = Color(0.01, 0.01, 0.01)

	# Ambient
	if _environment:
		_environment.ambient_light_energy = lerpf(0.25, 0.75, day_f)

	# Lampioni: accesi di notte/crepuscolo
	var lamps_on := sun_deg < 14.0
	for light in _lamp_lights:
		if is_instance_valid(light):
			light.light_energy = 2.2 if lamps_on else 0.0

	# Orario HUD
	if _label_time:
		var h := int(_time_hours)
		var m := int(fmod(_time_hours * 60.0, 60.0))
		_label_time.text = "%02d:%02d" % [h, m]

# ─── map ────────────────────────────────────────────────────────────────────

func _setup_map() -> void:
	var map := Node3D.new()
	map.name = "Map"
	add_child(map)

	# Ground — unico piano con collisione
	map.add_child(_make_box(Vector3(400, 0.4, 200), Vector3(0, -0.2, 26), Color(0.18, 0.24, 0.12), "Ground"))

	# Viale Pavia — visivo
	map.add_child(_make_visual(_box_mesh(Vector3(200, 0.02, 9)), Vector3(0, 0.01, 0), _make_mat(Color(0.12, 0.12, 0.12))))
	# Linea di mezzeria tratteggiata
	for xi in range(-19, 20):
		map.add_child(_make_visual(_box_mesh(Vector3(3.5, 0.01, 0.14)), Vector3(xi * 5.0, 0.025, 0), _make_mat(Color(0.85, 0.75, 0.10))))

	# Marciapiedi — visivi
	map.add_child(_make_visual(_box_mesh(Vector3(200, 0.018, 3.8)), Vector3(0, 0.009, -5.9), _make_mat(Color(0.55, 0.55, 0.55))))
	map.add_child(_make_visual(_box_mesh(Vector3(200, 0.018, 3.8)), Vector3(0, 0.009,  5.9), _make_mat(Color(0.55, 0.55, 0.55))))
	# Bordo marciapiede
	map.add_child(_make_visual(_box_mesh(Vector3(200, 0.022, 0.12)), Vector3(0, 0.011, -4.58), _make_mat(Color(0.28, 0.28, 0.28))))
	map.add_child(_make_visual(_box_mesh(Vector3(200, 0.022, 0.12)), Vector3(0, 0.011,  4.58), _make_mat(Color(0.28, 0.28, 0.28))))

	# Strisce pedonali
	for xi in range(-3, 4):
		var stripe := _make_visual(BoxMesh.new(), Vector3(xi * 2.0, 0.025, 0), _make_mat(Color(0.88, 0.88, 0.88)))
		(stripe.mesh as BoxMesh).size = Vector3(0.5, 0.01, 4.2)
		map.add_child(stripe)

	# Via Colombo nord-sud — visivo
	map.add_child(_make_visual(_box_mesh(Vector3(8, 0.02, 120)), Vector3(0, 0.01, 30), _make_mat(Color(0.12, 0.12, 0.12))))

	# ── La Muraglia ──
	_add_muraglia_block(map, Vector3(-52, 7.5, -14), 100, Color(0.76, 0.70, 0.60), "MuragliaLeft")
	_add_muraglia_block(map, Vector3(58, 7.5, -14),   88, Color(0.72, 0.66, 0.56), "MuragliaRight")

	# ── Alberi lungo viale Pavia ──
	for ti in range(-9, 10):
		_add_tree(map, Vector3(ti * 10.0, 0, -7.8))
		_add_tree(map, Vector3(ti * 10.0 + 5.0, 0, 7.8))

	# ── Edifici ──
	_add_caffe_molinari(map)
	_add_casa_quartiere(map)
	_add_sottoponte(map)

	# Garage
	map.add_child(_make_box(Vector3(18, 5, 14), Vector3(62, 2.5, 56), Color(0.25, 0.25, 0.27), "Garage"))
	map.add_child(_make_visual(_box_mesh(Vector3(5.2, 3.2, 0.15)), Vector3(62, 1.6, 49.05), _make_mat(Color(0.30, 0.30, 0.35))))
	for pi in range(5):
		map.add_child(_make_visual(_box_mesh(Vector3(5.0, 0.05, 0.1)), Vector3(62, 0.35 + pi * 0.62, 49.0), _make_mat(Color(0.20, 0.20, 0.24))))

	# ── Panchine lungo il marciapiede ──
	for bx in [-70.0, -50.0, -30.0, -10.0, 10.0, 30.0, 50.0, 70.0]:
		_add_bench(map, Vector3(bx, 0, -7.4))

	# ── Auto parcheggiate (visive, no collisione) ──
	_add_parked_car_visual(map, Vector3(-82, 0, -6.2), 0.0)
	_add_parked_car_visual(map, Vector3(-67, 0, -6.2), 0.0)
	_add_parked_car_visual(map, Vector3( 45, 0,  6.2), PI)
	_add_parked_car_visual(map, Vector3( 62, 0,  6.2), PI)
	_add_parked_car_visual(map, Vector3(-92, 0,  6.2), PI)

func _add_muraglia_block(map: Node3D, center: Vector3, length: float, color: Color, name_str: String) -> void:
	var depth   := 12.0
	var height  := 15.0
	var bottom  := center.y - height * 0.5
	var south_z := center.z + depth * 0.5

	# Corpo principale (collisione)
	map.add_child(_make_box(Vector3(length, height, depth), center, color, name_str))

	# Fascia bassa / graffiti
	map.add_child(_make_visual(
		_box_mesh(Vector3(length + 0.02, 1.9, depth + 0.02)),
		Vector3(center.x, bottom + 0.95, center.z),
		_make_mat(Color(color.r * 0.62, color.g * 0.60, color.b * 0.58))))

	# Linee di piano
	var fl_mat := _make_mat(Color(color.r * 0.70, color.g * 0.70, color.b * 0.70))
	for fi in range(1, 5):
		map.add_child(_make_visual(
			_box_mesh(Vector3(length + 0.06, 0.22, depth + 0.06)),
			Vector3(center.x, bottom + fi * 3.0, center.z), fl_mat))

	# Parapetto tetto
	map.add_child(_make_visual(
		_box_mesh(Vector3(length + 0.12, 0.55, 0.45)),
		Vector3(center.x, bottom + height + 0.27, south_z - 0.22), fl_mat))

	# Finestre + balconi (facciata sud)
	var win_mat  := _make_mat(Color(0.06, 0.07, 0.14))
	var bal_mat  := _make_mat(Color(color.r * 0.90, color.g * 0.90, color.b * 0.90))
	var rail_mat := _make_mat(Color(0.48, 0.48, 0.52))
	var cols     := int(length / 5.0)

	for ci in range(cols):
		var wx := center.x - length * 0.5 + 2.5 + ci * 5.0
		for fi in range(5):
			var wy := bottom + 1.6 + fi * 3.0
			# Finestra
			map.add_child(_make_visual(
				_box_mesh(Vector3(2.0, 1.4, 0.14)),
				Vector3(wx, wy, south_z + 0.07), win_mat))
			# Soletta balcone
			map.add_child(_make_visual(
				_box_mesh(Vector3(2.5, 0.10, 0.90)),
				Vector3(wx, bottom + fi * 3.0 + 0.05, south_z + 0.45), bal_mat))
			# Ringhiera
			map.add_child(_make_visual(
				_box_mesh(Vector3(2.5, 0.62, 0.06)),
				Vector3(wx, bottom + fi * 3.0 + 0.41, south_z + 0.87), rail_mat))

	# Portoni d'ingresso ogni ~20 m
	var door_mat  := _make_mat(Color(0.13, 0.09, 0.07))
	var n_doors: int  = max(1, int(length / 20))
	var door_step: float = length / float(n_doors)
	for di in range(n_doors):
		var dx := center.x - length * 0.5 + door_step * (di + 0.5)
		map.add_child(_make_visual(
			_box_mesh(Vector3(1.7, 2.7, 0.16)),
			Vector3(dx, bottom + 1.35, south_z + 0.08), door_mat))

func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

# ─── street furniture ───────────────────────────────────────────────────────

func _add_tree(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14; trunk.bottom_radius = 0.22; trunk.height = 3.8
	root.add_child(_make_visual(trunk, Vector3(0, 1.9, 0), _make_mat(Color(0.30, 0.19, 0.09))))
	var foliage := SphereMesh.new()
	foliage.radius = 1.5; foliage.height = 3.0
	root.add_child(_make_visual(foliage, Vector3(0, 5.0, 0), _make_mat(Color(0.13, 0.34, 0.11))))

func _add_bench(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var wood  := _make_mat(Color(0.44, 0.29, 0.14))
	var metal := _make_mat(Color(0.28, 0.28, 0.28))
	root.add_child(_make_visual(_box_mesh(Vector3(1.6, 0.06, 0.44)), Vector3(0, 0.46, 0),    wood))
	root.add_child(_make_visual(_box_mesh(Vector3(1.6, 0.42, 0.06)), Vector3(0, 0.73, -0.21), wood))
	for lx in [-0.64, 0.64]:
		root.add_child(_make_visual(_box_mesh(Vector3(0.06, 0.46, 0.38)), Vector3(lx, 0.23, 0), metal))

func _add_parked_car_visual(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos; root.rotation.y = rot_y
	parent.add_child(root)
	var palette := [Color(0.28,0.28,0.65), Color(0.60,0.10,0.10), Color(0.14,0.14,0.14),
					Color(0.70,0.70,0.70), Color(0.18,0.38,0.18), Color(0.55,0.40,0.10)]
	var c: Color = palette[randi() % palette.size()]
	var dark := _make_mat(Color(0.05, 0.05, 0.08))
	root.add_child(_make_visual(_box_mesh(Vector3(1.85, 0.62, 4.1)),  Vector3(0, 0.44, 0),    _make_mat(c)))
	root.add_child(_make_visual(_box_mesh(Vector3(1.60, 0.48, 1.95)), Vector3(0, 0.99, 0.08), _make_mat(c)))
	root.add_child(_make_visual(_box_mesh(Vector3(1.55, 0.38, 0.06)), Vector3(0, 0.97, -1.04), dark))
	root.add_child(_make_visual(_box_mesh(Vector3(1.55, 0.34, 0.06)), Vector3(0, 0.99,  1.08), dark))
	var rubber := _make_mat(Color(0.10, 0.10, 0.10))
	for wx: float in [-0.95, 0.95]:
		for wz: float in [-1.28, 1.28]:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.29; cyl.bottom_radius = 0.29; cyl.height = 0.19
			var mi := _make_visual(cyl, Vector3(wx, 0.30, wz), rubber)
			mi.rotation_degrees.z = 90
			root.add_child(mi)

func _add_caffe_molinari(map: Node3D) -> void:
	map.add_child(_make_box(Vector3(14, 6, 10), Vector3(-100, 3, 5), Color(0.40, 0.25, 0.13), "Caffemolinari"))
	# Insegna luminosa
	map.add_child(_make_visual(_box_mesh(Vector3(8, 0.6, 0.12)), Vector3(-100, 6.4, -0.06),
		_make_mat(Color(0.9, 0.7, 0.1), Color(1.0, 0.8, 0.0), 1.5)))
	# Tenda/awning
	map.add_child(_make_visual(_box_mesh(Vector3(11, 0.10, 2.0)), Vector3(-100, 3.7, -1.0),
		_make_mat(Color(0.14, 0.32, 0.14))))
	for si in range(6):
		map.add_child(_make_visual(_box_mesh(Vector3(0.28, 0.12, 2.05)),
			Vector3(-102.5 + si * 1.0, 3.69, -1.0), _make_mat(Color(0.90, 0.90, 0.90))))
	# Porta
	map.add_child(_make_visual(_box_mesh(Vector3(1.4, 2.4, 0.12)), Vector3(-100, 1.2, -0.06),
		_make_mat(Color(0.28, 0.16, 0.07))))
	# Vetrine
	var glass := _make_mat(Color(0.15, 0.22, 0.30))
	map.add_child(_make_visual(_box_mesh(Vector3(3.5, 1.8, 0.08)), Vector3(-96.5, 2.5, -0.04), glass))
	map.add_child(_make_visual(_box_mesh(Vector3(3.5, 1.8, 0.08)), Vector3(-103.5, 2.5, -0.04), glass))
	# Gradino
	map.add_child(_make_visual(_box_mesh(Vector3(3.0, 0.14, 0.55)), Vector3(-100, 0.07, -0.27),
		_make_mat(Color(0.45, 0.42, 0.40))))

func _add_casa_quartiere(map: Node3D) -> void:
	map.add_child(_make_box(Vector3(16, 8, 12), Vector3(96, 4, 5), Color(0.30, 0.38, 0.22), "CasaDelQuartiere"))
	# Fascia murale
	map.add_child(_make_visual(_box_mesh(Vector3(16.02, 2.5, 0.12)), Vector3(96, 1.25, -1.06),
		_make_mat(Color(0.55, 0.32, 0.18))))
	# Insegna
	map.add_child(_make_visual(_box_mesh(Vector3(9, 0.5, 0.1)), Vector3(96, 8.2, -1.05),
		_make_mat(Color(0.9, 0.85, 0.5), Color(1.0, 0.9, 0.3), 1.0)))
	# Porta
	map.add_child(_make_visual(_box_mesh(Vector3(2.0, 2.8, 0.12)), Vector3(96, 1.4, -1.06),
		_make_mat(Color(0.20, 0.28, 0.14))))

func _add_sottoponte(map: Node3D) -> void:
	# Trave ferrovia
	map.add_child(_make_box(Vector3(20, 1.5, 8), Vector3(-52, 5.75, 56), Color(0.36, 0.36, 0.38), "Sottoponte"))
	# Piloni
	for px in [-8.0, 8.0]:
		map.add_child(_make_box(Vector3(2.5, 5.0, 2.5), Vector3(-52.0 + px, 2.5, 56), Color(0.32, 0.32, 0.34)))
	# Pannello graffiti
	map.add_child(_make_visual(_box_mesh(Vector3(13, 3.8, 0.12)), Vector3(-52, 2.9, 52.06),
		_make_mat(Color(0.18, 0.15, 0.22))))

# ─── streetlamps ────────────────────────────────────────────────────────────

func _setup_streetlamps() -> void:
	var xs := [-80.0, -40.0, 0.0, 40.0, 80.0]
	for i in range(xs.size()):
		var side := -1 if i % 2 == 0 else 1   # alterna nord/sud
		_add_streetlamp(Vector3(xs[i], 0, side * 7.2))

func _add_streetlamp(base_pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = base_pos
	add_child(root)

	var metal := _make_mat(Color(0.28, 0.29, 0.30))

	# Palo
	var pole := _make_visual(_box_mesh(Vector3(0.12, 5.0, 0.12)), Vector3(0, 2.5, 0), metal)
	root.add_child(pole)

	# Braccio
	var arm := _make_visual(_box_mesh(Vector3(0.08, 0.08, 1.4)), Vector3(0, 5.0, -0.7), metal)
	root.add_child(arm)

	# Testa lampione
	var lamp_mat := _make_mat(Color(1.0, 0.92, 0.65), Color(1.0, 0.88, 0.5), 3.0)
	var head := _make_visual(_box_mesh(Vector3(0.45, 0.18, 0.65)), Vector3(0, 5.0, -1.35), lamp_mat)
	root.add_child(head)

	# Luce reale
	var light := OmniLight3D.new()
	light.light_energy = 2.2
	light.light_color = Color(1.0, 0.82, 0.48)
	light.omni_range = 22.0
	light.shadow_enabled = false
	light.position = Vector3(0, 4.85, -1.35)
	root.add_child(light)
	_lamp_lights.append(light)

# ─── player ─────────────────────────────────────────────────────────────────

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	player.add_child(col)
	_capsule_mesh = MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.radius = 0.4
	cap_mesh.height = 1.8
	_capsule_mesh.material_override = _make_mat(Color(0.2, 0.5, 0.9))
	_capsule_mesh.mesh = cap_mesh
	_capsule_mesh.position = Vector3(0, 0.9, 0)
	player.add_child(_capsule_mesh)
	player.position = Vector3(-40, 1.0, 0)
	player.set_script(load("res://scripts/player.gd"))
	player.add_to_group("player")
	add_child(player)

func _setup_player_model() -> void:
	var packed = load("res://characters/sugo.glb")
	if not packed:
		print("WARN: sugo.glb non trovato — rimane capsule")
		return
	var model: Node3D = packed.instantiate()
	model.name = "SugoModel"
	player.add_child(model)
	var meshes := _collect_meshes(model)
	if meshes.is_empty():
		model.queue_free(); return
	var combined := AABB()
	var first := true
	for mi: MeshInstance3D in meshes:
		var rel: Transform3D = model.global_transform.affine_inverse() * mi.global_transform
		for corner: Vector3 in _aabb_corners(mi.get_aabb()):
			var p: Vector3 = rel * corner
			if first: combined = AABB(p, Vector3.ZERO); first = false
			else: combined = combined.expand(p)
	var height := combined.size.y
	if height > 0.01:
		var sf := 2.2 / height
		model.scale = Vector3.ONE * sf
		model.position.y = -combined.position.y * sf
		print("Sugo: scale=%.3f" % sf)
	for mi: MeshInstance3D in meshes:
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var mat = mi.mesh.surface_get_material(i)
				if mat is BaseMaterial3D:
					var dup: BaseMaterial3D = mat.duplicate()
					dup.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					mi.mesh.surface_set_material(i, dup)
	_capsule_mesh.visible = false
	print("Sugo caricato OK")

func _collect_meshes(node: Node) -> Array:
	var r := []
	if node is MeshInstance3D: r.append(node)
	for c in node.get_children(): r.append_array(_collect_meshes(c))
	return r

func _aabb_corners(aabb: AABB) -> Array:
	return [aabb.position, aabb.position+Vector3(aabb.size.x,0,0),
		aabb.position+Vector3(0,aabb.size.y,0), aabb.position+Vector3(0,0,aabb.size.z),
		aabb.position+Vector3(aabb.size.x,aabb.size.y,0),
		aabb.position+Vector3(aabb.size.x,0,aabb.size.z),
		aabb.position+Vector3(0,aabb.size.y,aabb.size.z), aabb.end]

# ─── NPCs ───────────────────────────────────────────────────────────────────

func _spawn_npc(pos: Vector3, color: Color, display_name: String) -> CharacterBody3D:
	var npc := CharacterBody3D.new()
	npc.name = display_name
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35; cap.height = 1.7
	col.shape = cap; col.position = Vector3(0, 0.85, 0)
	npc.add_child(col)
	npc.position = pos
	npc.set_script(load("res://scripts/npc.gd"))
	add_child(npc)
	npc.call("init", color, display_name)
	return npc

func _setup_npcs() -> void:
	_huncho_npc = _spawn_npc(Vector3(-50, 1.0,  2.5), Color(0.9, 0.6, 0.1), "Huncho")
	_spawn_npc(Vector3(-45, 1.0, -2.0), Color(0.2, 0.8, 0.3), "Behope")
	_spawn_npc(Vector3(-35, 1.0,  1.5), Color(0.8, 0.2, 0.7), "Chakour")

# ─── car ────────────────────────────────────────────────────────────────────

func _setup_car() -> void:
	car = CharacterBody3D.new()
	car.name = "Car"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.4, 4.5)
	col.shape = box
	col.position = Vector3(0, 0.7, 0)
	car.add_child(col)
	_build_car_visual(car)
	car.position = Vector3(-30, 0.8, 0)
	car.set_script(load("res://scripts/car.gd"))
	add_child(car)

func _build_car_visual(parent: Node3D) -> void:
	var red    := _make_mat(Color(0.82, 0.07, 0.07))
	var dark   := _make_mat(Color(0.05, 0.06, 0.10))
	var rubber := _make_mat(Color(0.10, 0.10, 0.10))
	var chrome := _make_mat(Color(0.65, 0.65, 0.70))
	var light_mat := _make_mat(Color(1.0, 0.95, 0.7), Color(1.0, 0.9, 0.5), 2.0)

	# Body principale
	parent.add_child(_make_visual(_box_mesh(Vector3(2.0, 0.78, 4.5)), Vector3(0, 0.39, 0), red))
	# Cabina
	parent.add_child(_make_visual(_box_mesh(Vector3(1.72, 0.58, 2.3)), Vector3(0, 1.07, 0.08), red))
	# Parabrezza anteriore
	parent.add_child(_make_visual(_box_mesh(Vector3(1.68, 0.52, 0.06)), Vector3(0, 1.05, -1.22), dark))
	# Lunotto posteriore
	parent.add_child(_make_visual(_box_mesh(Vector3(1.68, 0.46, 0.06)), Vector3(0, 1.08, 1.22), dark))
	# Finestrini laterali
	for sx in [-0.87, 0.87]:
		parent.add_child(_make_visual(_box_mesh(Vector3(0.06, 0.44, 1.8)), Vector3(sx, 1.06, 0.1), dark))
	# Fanali anteriori
	for fx in [-0.7, 0.7]:
		parent.add_child(_make_visual(_box_mesh(Vector3(0.5, 0.2, 0.06)), Vector3(fx, 0.52, -2.28), light_mat))
	# Stop posteriori
	var stop_mat := _make_mat(Color(0.9, 0.05, 0.05), Color(1.0, 0.0, 0.0), 1.2)
	for rx in [-0.7, 0.7]:
		parent.add_child(_make_visual(_box_mesh(Vector3(0.45, 0.18, 0.06)), Vector3(rx, 0.52, 2.28), stop_mat))
	# Paraurti
	parent.add_child(_make_visual(_box_mesh(Vector3(1.9, 0.18, 0.1)), Vector3(0, 0.2, -2.3), chrome))
	parent.add_child(_make_visual(_box_mesh(Vector3(1.9, 0.18, 0.1)), Vector3(0, 0.2,  2.3), chrome))

	# Ruote (4) con cerchio
	for wx: float in [-1.02, 1.02]:
		for wz: float in [-1.45, 1.45]:
			var wheel_cyl := CylinderMesh.new()
			wheel_cyl.top_radius = 0.34; wheel_cyl.bottom_radius = 0.34; wheel_cyl.height = 0.24
			var wheel_mi := _make_visual(wheel_cyl, Vector3(wx, 0.34, wz), rubber)
			wheel_mi.rotation_degrees.z = 90
			parent.add_child(wheel_mi)
			var hub_cyl := CylinderMesh.new()
			hub_cyl.top_radius = 0.18; hub_cyl.bottom_radius = 0.18; hub_cyl.height = 0.26
			var hub_mi := _make_visual(hub_cyl, Vector3(wx, 0.34, wz), chrome)
			hub_mi.rotation_degrees.z = 90
			parent.add_child(hub_mi)

# ─── camera ─────────────────────────────────────────────────────────────────

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.set_script(load("res://scripts/chase_camera.gd"))
	add_child(camera)

# ─── UI + missione ───────────────────────────────────────────────────────────

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	# Orologio — angolo top-right
	_label_time = Label.new()
	_label_time.name = "LabelTime"
	_label_time.anchor_left  = 1.0
	_label_time.anchor_right = 1.0
	_label_time.offset_left  = -90.0
	_label_time.offset_top   = 18.0
	_label_time.add_theme_font_size_override("font_size", 22)
	_label_time.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	canvas.add_child(_label_time)

	var label_obj := Label.new()
	label_obj.name = "LabelObjective"
	label_obj.position = Vector2(24, 24)
	label_obj.add_theme_font_size_override("font_size", 20)
	label_obj.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	canvas.add_child(label_obj)

	var label_dlg := Label.new()
	label_dlg.name = "LabelDialogue"
	label_dlg.anchor_left = 0.0; label_dlg.anchor_right  = 1.0
	label_dlg.anchor_top  = 1.0; label_dlg.anchor_bottom = 1.0
	label_dlg.offset_top = -80.0; label_dlg.offset_bottom = -40.0
	label_dlg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_dlg.add_theme_font_size_override("font_size", 22)
	label_dlg.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(label_dlg)

	# Goal marker — disco + colonna
	var mat_goal := _make_mat(Color(1.0, 0.9, 0.0, 0.75), Color(1.0, 0.8, 0.0), 2.0)
	mat_goal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var disc_cyl := CylinderMesh.new()
	disc_cyl.top_radius = 2.2; disc_cyl.bottom_radius = 2.2; disc_cyl.height = 0.08
	disc_cyl.material = mat_goal
	var disc := MeshInstance3D.new()
	disc.mesh = disc_cyl; disc.position = Vector3(-100, 0.05, -2.0)
	add_child(disc)
	var beam_cyl := CylinderMesh.new()
	beam_cyl.top_radius = 0.28; beam_cyl.bottom_radius = 0.28; beam_cyl.height = 8.0
	beam_cyl.material = mat_goal
	var beam := MeshInstance3D.new()
	beam.mesh = beam_cyl; beam.position = Vector3(-100, 4.0, -2.0)
	add_child(beam)

	var mission := Node.new()
	mission.name = "Mission01"
	mission.set_script(load("res://scripts/mission_01.gd"))
	add_child(mission)
	mission.call("setup", player, _huncho_npc, label_obj, label_dlg)

# ─── input / vehicle ────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if event.keycode == KEY_E:
			_toggle_vehicle()
	if InputMap.has_action("enter_exit_vehicle") and event.is_action_pressed("enter_exit_vehicle"):
		_toggle_vehicle()

func _toggle_vehicle() -> void:
	var dist := player.global_position.distance_to(car.global_position)
	if not in_vehicle:
		if dist < ENTER_DISTANCE:
			in_vehicle = true
			player.visible = false
			player.set("in_vehicle", true)
			camera.call("align_to_node", car)
			camera.call("set_target", car)
			print("Entrato in macchina")
		else:
			print("Troppo lontano (%.1fm)" % dist)
	else:
		in_vehicle = false
		player.visible = true
		player.set("in_vehicle", false)
		player.global_position = car.global_position + car.global_transform.basis.x * 2.5 + Vector3(0, 0.5, 0)
		camera.call("set_target", player)
		print("Uscito dall'auto")
