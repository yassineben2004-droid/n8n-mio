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
	# Second block — wider, darker brick, 7 floors (~10.5m half-height → center y=10.5)
	_add_muraglia_block(map, Vector3(58, 10.5, -18), 120, Color(0.42, 0.32, 0.24), "MuragliaBrownBlock")

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

	# ── Parco ──
	_add_parco(map)

	# ── Campetto ──
	_add_campetto(map)

	# ── Piazza Omegna ──
	_add_piazza_omegna(map)

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
	# Corner building — ground floor of taller residential block
	# Building above (beige facade with balconies, orange/bronze railings)
	map.add_child(_make_box(Vector3(14, 18, 10), Vector3(-100, 9, 5), Color(0.88, 0.82, 0.72), "CaffeMolinariBuilding"))
	# Ground floor bar volume (slightly darker)
	map.add_child(_make_visual(_box_mesh(Vector3(14.02, 4.0, 10.02)),
		Vector3(-100, 2.0, 5), _make_mat(Color(0.78, 0.74, 0.68))))

	# Balconies + orange/bronze railings on upper floors
	var bal_mat := _make_mat(Color(0.82, 0.78, 0.72))
	var rail_mat := _make_mat(Color(0.72, 0.48, 0.18))
	for fi in range(1, 5):
		var wy: float = 4.0 + fi * 3.2
		map.add_child(_make_visual(_box_mesh(Vector3(12, 0.12, 1.0)),
			Vector3(-100, wy, 0.5), bal_mat))
		map.add_child(_make_visual(_box_mesh(Vector3(12, 0.72, 0.06)),
			Vector3(-100, wy + 0.46, 0.04), rail_mat))

	# Large glass storefront — full width ~12m
	var glass := _make_mat(Color(0.55, 0.68, 0.80))
	map.add_child(_make_visual(_box_mesh(Vector3(5.0, 2.6, 0.10)),
		Vector3(-96.0, 1.8, 0.05), glass))
	map.add_child(_make_visual(_box_mesh(Vector3(5.0, 2.6, 0.10)),
		Vector3(-104.0, 1.8, 0.05), glass))
	# Central glass door
	map.add_child(_make_visual(_box_mesh(Vector3(1.8, 2.8, 0.10)),
		Vector3(-100, 1.5, 0.05), glass))

	# Large white awning spanning full ~12m width
	var awning_white := _make_mat(Color(0.96, 0.96, 0.96))
	map.add_child(_make_visual(_box_mesh(Vector3(12.0, 0.12, 2.8)),
		Vector3(-100, 3.55, -0.6), awning_white))
	# Red stripe on awning front edge
	var awning_red := _make_mat(Color(0.80, 0.12, 0.10))
	map.add_child(_make_visual(_box_mesh(Vector3(12.0, 0.22, 0.12)),
		Vector3(-100, 3.44, -1.96), awning_red))
	# Awning valance (hanging front strip)
	map.add_child(_make_visual(_box_mesh(Vector3(12.0, 0.55, 0.06)),
		Vector3(-100, 3.18, -1.96), awning_red))

	# Tables + chairs outside under awning
	var table_mat := _make_mat(Color(0.88, 0.86, 0.84))
	var chair_mat := _make_mat(Color(0.25, 0.25, 0.28))
	for ti in range(4):
		var tx: float = -106.0 + ti * 4.0
		# Table top
		map.add_child(_make_visual(_box_mesh(Vector3(0.8, 0.06, 0.8)),
			Vector3(tx, 0.76, -1.5), table_mat))
		# Table leg
		map.add_child(_make_visual(_box_mesh(Vector3(0.06, 0.76, 0.06)),
			Vector3(tx, 0.38, -1.5), chair_mat))
		# Two chairs per table
		for cz: float in [-2.1, -0.9]:
			map.add_child(_make_visual(_box_mesh(Vector3(0.42, 0.05, 0.42)),
				Vector3(tx, 0.48, cz), chair_mat))
			map.add_child(_make_visual(_box_mesh(Vector3(0.42, 0.52, 0.05)),
				Vector3(tx, 0.72, cz + (0.22 if cz < -1.5 else -0.22)), chair_mat))

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
	# Il vero sottoponte: tunnel pedonale sotto un sovrappasso
	# Soffitto piatto in cemento
	map.add_child(_make_visual(_box_mesh(Vector3(24, 0.9, 14)),
		Vector3(-52, 4.95, 56), _make_mat(Color(0.30, 0.30, 0.30))))
	# Pareti laterali tunnel
	map.add_child(_make_box(Vector3(0.5, 5.0, 14), Vector3(-64.5, 2.5, 56), Color(0.28, 0.28, 0.28)))
	map.add_child(_make_box(Vector3(0.5, 5.0, 14), Vector3(-39.5, 2.5, 56), Color(0.28, 0.28, 0.28)))
	# Piloni cilindrici rotondi coperti di graffiti colorati
	var graffiti_colors := [Color(0.72, 0.18, 0.12), Color(0.18, 0.45, 0.72),
		Color(0.88, 0.72, 0.10), Color(0.22, 0.60, 0.22), Color(0.65, 0.12, 0.55)]
	var col_idx := 0
	for px in [-8.0, 0.0, 8.0]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.55; cyl.bottom_radius = 0.55; cyl.height = 5.0
		var gc: Color = graffiti_colors[col_idx % graffiti_colors.size()]
		col_idx += 1
		map.add_child(_make_visual(cyl, Vector3(-52.0 + px, 2.5, 56),
			_make_mat(gc.lerp(Color(0.22, 0.22, 0.22), 0.45))))
	# Trave con scritta "MURA" (banda verde sul soffitto/trave frontale)
	map.add_child(_make_visual(_box_mesh(Vector3(20, 0.5, 0.15)),
		Vector3(-52, 4.55, 49.1), _make_mat(Color(0.08, 0.38, 0.10))))
	# Scala di accesso con ringhiera
	for si in range(5):
		map.add_child(_make_visual(_box_mesh(Vector3(4.0, 0.18, 1.1)),
			Vector3(-56, 0.09 + si * 0.32, 49.5 + si * 0.55),
			_make_mat(Color(0.32, 0.32, 0.34))))
	# Ringhiera scala
	map.add_child(_make_visual(_box_mesh(Vector3(0.06, 0.9, 5.0)),
		Vector3(-54.1, 1.1, 51.5), _make_mat(Color(0.55, 0.45, 0.10))))
	# Lampada a gabbia sul soffitto
	var cage_mat := _make_mat(Color(0.55, 0.42, 0.18), Color(1.0, 0.65, 0.20), 1.5)
	map.add_child(_make_visual(_box_mesh(Vector3(0.22, 0.22, 0.22)),
		Vector3(-52, 4.55, 56), cage_mat))
	var tl := OmniLight3D.new()
	tl.light_energy = 1.8
	tl.light_color = Color(1.0, 0.65, 0.25)
	tl.omni_range = 12.0
	tl.position = Vector3(-52, 4.4, 56)
	map.add_child(tl)
	_lamp_lights.append(tl)
	# Pavimento tunnel (cemento scuro)
	map.add_child(_make_visual(_box_mesh(Vector3(24, 0.04, 14)),
		Vector3(-52, 0.02, 56), _make_mat(Color(0.22, 0.20, 0.20))))
	# Grata di scolo
	map.add_child(_make_visual(_box_mesh(Vector3(1.4, 0.04, 1.4)),
		Vector3(-52, 0.03, 57), _make_mat(Color(0.12, 0.12, 0.12))))

func _add_piazza_omegna(map: Node3D) -> void:
	# Grande piazza aperta in asfalto/cemento
	map.add_child(_make_visual(_box_mesh(Vector3(42, 0.04, 32)),
		Vector3(-52, 0.02, 72), _make_mat(Color(0.44, 0.44, 0.46))))
	# Giovani alberi con paletti di supporto (tripode)
	for tx: float in [-62.0, -50.0, -38.0, -26.0]:
		var root := Node3D.new()
		root.position = Vector3(tx, 0, 68)
		map.add_child(root)
		# Paletto tripode di supporto
		for a in [0.0, 2.09, 4.19]:
			root.add_child(_make_visual(_box_mesh(Vector3(0.05, 1.4, 0.05)),
				Vector3(sin(a) * 0.25, 0.7, cos(a) * 0.25),
				_make_mat(Color(0.50, 0.35, 0.12))))
		# Alberello giovane
		var sapling_cyl := CylinderMesh.new()
		sapling_cyl.top_radius = 0.04; sapling_cyl.bottom_radius = 0.06; sapling_cyl.height = 2.5
		root.add_child(_make_visual(sapling_cyl, Vector3(0, 1.25, 0),
			_make_mat(Color(0.28, 0.18, 0.08))))
		var sapling_leaves := SphereMesh.new()
		sapling_leaves.radius = 0.7; sapling_leaves.height = 1.4
		root.add_child(_make_visual(sapling_leaves, Vector3(0, 2.8, 0),
			_make_mat(Color(0.20, 0.40, 0.14))))
	# Edificio marrone lato destro (visivo)
	map.add_child(_make_visual(_box_mesh(Vector3(0.3, 18, 32)),
		Vector3(-31, 9, 72), _make_mat(Color(0.52, 0.36, 0.26))))

func _add_pine(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	# Trunk — thin dark brown cylinder
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12; trunk.bottom_radius = 0.18; trunk.height = 2.2
	root.add_child(_make_visual(trunk, Vector3(0, 1.1, 0), _make_mat(Color(0.28, 0.17, 0.08))))
	# Three stacked cones — dark green, each narrower and higher
	var pine_mat := _make_mat(Color(0.08, 0.22, 0.10))
	for li in range(3):
		var fi: float = float(li)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.8 - fi * 0.4
		cone.height = 2.4
		root.add_child(_make_visual(cone, Vector3(0, 2.8 + fi * 1.6, 0), pine_mat))

func _add_globe_lamp(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var metal := _make_mat(Color(0.30, 0.30, 0.32))
	# Concrete base block
	var base_mat := _make_mat(Color(0.58, 0.56, 0.52))
	root.add_child(_make_visual(_box_mesh(Vector3(0.30, 0.22, 0.30)), Vector3(0, 0.11, 0), base_mat))
	# Thin metal pole
	var pole := CylinderMesh.new()
	pole.top_radius = 0.045; pole.bottom_radius = 0.06; pole.height = 3.8
	root.add_child(_make_visual(pole, Vector3(0, 2.12, 0), metal))
	# Mushroom cap — flat disc on top
	var cap := CylinderMesh.new()
	cap.top_radius = 0.45; cap.bottom_radius = 0.42; cap.height = 0.10
	var cap_mat := _make_mat(Color(0.28, 0.28, 0.30))
	root.add_child(_make_visual(cap, Vector3(0, 4.07, 0), cap_mat))
	# Light diffuser ring under cap
	var ring := CylinderMesh.new()
	ring.top_radius = 0.32; ring.bottom_radius = 0.30; ring.height = 0.12
	var diff_mat := _make_mat(Color(0.98, 0.97, 0.92), Color(1.0, 0.94, 0.78), 2.5)
	root.add_child(_make_visual(ring, Vector3(0, 3.96, 0), diff_mat))
	# Omni light
	var light := OmniLight3D.new()
	light.light_energy = 2.2
	light.light_color = Color(1.0, 0.88, 0.62)
	light.omni_range = 14.0
	light.shadow_enabled = false
	light.position = Vector3(0, 4.0, 0)
	root.add_child(light)
	_lamp_lights.append(light)

func _add_parco(map: Node3D) -> void:
	# Green grass — no perimeter fence
	map.add_child(_make_visual(_box_mesh(Vector3(70, 0.02, 55)),
		Vector3(45, 0.01, 38), _make_mat(Color(0.18, 0.42, 0.12))))

	# Concrete path along left side only
	map.add_child(_make_visual(_box_mesh(Vector3(3.2, 0.03, 55)),
		Vector3(12, 0.02, 38), _make_mat(Color(0.62, 0.60, 0.58))))

	# Large conifer/pine trees dominating center
	var pine_spots: Array[Vector3] = [
		Vector3(42, 0, 35), Vector3(48, 0, 35), Vector3(45, 0, 42),
		Vector3(40, 0, 40), Vector3(50, 0, 40)
	]
	for pp: Vector3 in pine_spots:
		_add_pine(map, pp)

	# Round deciduous trees around edges
	var tree_spots: Array[Vector3] = [
		Vector3(18, 0, 20), Vector3(30, 0, 18), Vector3(60, 0, 20), Vector3(72, 0, 22),
		Vector3(18, 0, 55), Vector3(30, 0, 58), Vector3(60, 0, 58), Vector3(72, 0, 55),
		Vector3(16, 0, 38), Vector3(74, 0, 38)
	]
	for tp: Vector3 in tree_spots:
		_add_tree(map, tp)

	# Globe-style lamp posts
	_add_globe_lamp(map, Vector3(20, 0, 25))
	_add_globe_lamp(map, Vector3(20, 0, 50))
	_add_globe_lamp(map, Vector3(70, 0, 25))
	_add_globe_lamp(map, Vector3(70, 0, 50))

	# Benches scattered
	_add_bench(map, Vector3(25, 0, 38))
	_add_bench(map, Vector3(65, 0, 38))
	_add_bench(map, Vector3(45, 0, 22))
	_add_bench(map, Vector3(45, 0, 54))

	# ── Playground area (east side of park) ──
	var pg_x := 62.0
	var pg_z := 45.0

	# Sandbox — flat pit with sand color
	map.add_child(_make_visual(_box_mesh(Vector3(4.0, 0.12, 3.0)),
		Vector3(pg_x + 4, 0.06, pg_z), _make_mat(Color(0.85, 0.78, 0.52))))
	# Sand border
	map.add_child(_make_visual(_box_mesh(Vector3(4.2, 0.18, 0.18)),
		Vector3(pg_x + 4, 0.09, pg_z - 1.59), _make_mat(Color(0.50, 0.38, 0.22))))
	map.add_child(_make_visual(_box_mesh(Vector3(4.2, 0.18, 0.18)),
		Vector3(pg_x + 4, 0.09, pg_z + 1.59), _make_mat(Color(0.50, 0.38, 0.22))))

	# Swing set — metal A-frame + horizontal bar + two swings
	var metal_sw := _make_mat(Color(0.55, 0.55, 0.58))
	var rope_mat := _make_mat(Color(0.30, 0.25, 0.18))
	var seat_mat := _make_mat(Color(0.18, 0.38, 0.62))
	# A-frame left
	map.add_child(_make_visual(_box_mesh(Vector3(0.08, 2.6, 0.08)),
		Vector3(pg_x - 1.0, 1.3, pg_z - 1.2), metal_sw))
	map.add_child(_make_visual(_box_mesh(Vector3(0.08, 2.6, 0.08)),
		Vector3(pg_x - 1.0, 1.3, pg_z + 1.2), metal_sw))
	# A-frame right
	map.add_child(_make_visual(_box_mesh(Vector3(0.08, 2.6, 0.08)),
		Vector3(pg_x + 1.0, 1.3, pg_z - 1.2), metal_sw))
	map.add_child(_make_visual(_box_mesh(Vector3(0.08, 2.6, 0.08)),
		Vector3(pg_x + 1.0, 1.3, pg_z + 1.2), metal_sw))
	# Horizontal bar
	map.add_child(_make_visual(_box_mesh(Vector3(0.08, 0.08, 2.6)),
		Vector3(pg_x, 2.6, pg_z), metal_sw))
	# Swing seats + ropes
	for sw_x: float in [pg_x - 0.6, pg_x + 0.6]:
		map.add_child(_make_visual(_box_mesh(Vector3(0.04, 1.4, 0.04)),
			Vector3(sw_x, 1.6, pg_z - 0.5), rope_mat))
		map.add_child(_make_visual(_box_mesh(Vector3(0.04, 1.4, 0.04)),
			Vector3(sw_x, 1.6, pg_z + 0.5), rope_mat))
		map.add_child(_make_visual(_box_mesh(Vector3(0.36, 0.06, 0.18)),
			Vector3(sw_x, 0.9, pg_z), seat_mat))

	# Slide — orange ramp on metal frame
	var orange_mat := _make_mat(Color(0.90, 0.42, 0.06))
	var frame_mat := _make_mat(Color(0.60, 0.60, 0.62))
	# Platform
	map.add_child(_make_visual(_box_mesh(Vector3(1.1, 0.10, 1.0)),
		Vector3(pg_x - 4, 1.55, pg_z), orange_mat))
	# Frame legs
	for lx: float in [pg_x - 4.55, pg_x - 3.45]:
		for lz: float in [pg_z - 0.45, pg_z + 0.45]:
			map.add_child(_make_visual(_box_mesh(Vector3(0.07, 1.6, 0.07)),
				Vector3(lx, 0.8, lz), frame_mat))
	# Ramp (rotated box)
	var ramp := _make_visual(_box_mesh(Vector3(1.0, 0.06, 2.2)),
		Vector3(pg_x - 4, 0.88, pg_z + 1.6), orange_mat)
	ramp.rotation_degrees.x = -36.0
	map.add_child(ramp)

	# Climbing frame with yellow accents
	var climb_mat := _make_mat(Color(0.25, 0.25, 0.28))
	var yellow_mat := _make_mat(Color(0.90, 0.78, 0.10))
	for cx: float in [pg_x - 8.5, pg_x - 6.5]:
		for cz: float in [pg_z - 1.0, pg_z + 1.0]:
			map.add_child(_make_visual(_box_mesh(Vector3(0.08, 2.2, 0.08)),
				Vector3(cx, 1.1, cz), climb_mat))
	map.add_child(_make_visual(_box_mesh(Vector3(2.2, 0.08, 0.08)),
		Vector3(pg_x - 7.5, 2.2, pg_z - 1.0), yellow_mat))
	map.add_child(_make_visual(_box_mesh(Vector3(2.2, 0.08, 0.08)),
		Vector3(pg_x - 7.5, 2.2, pg_z + 1.0), yellow_mat))
	map.add_child(_make_visual(_box_mesh(Vector3(0.08, 0.08, 2.1)),
		Vector3(pg_x - 8.5, 2.2, pg_z), yellow_mat))
	map.add_child(_make_visual(_box_mesh(Vector3(0.08, 0.08, 2.1)),
		Vector3(pg_x - 6.5, 2.2, pg_z), yellow_mat))

	# Small soccer goal (background)
	var goal_mat := _make_mat(Color(0.88, 0.88, 0.90))
	map.add_child(_make_visual(_box_mesh(Vector3(3.0, 0.06, 0.06)),
		Vector3(45, 1.55, 16), goal_mat))
	map.add_child(_make_visual(_box_mesh(Vector3(0.06, 1.6, 0.06)),
		Vector3(43.5, 0.8, 16), goal_mat))
	map.add_child(_make_visual(_box_mesh(Vector3(0.06, 1.6, 0.06)),
		Vector3(46.5, 0.8, 16), goal_mat))

	# Fontanella (simple concrete drinking fountain post) near path
	var conc_mat := _make_mat(Color(0.62, 0.60, 0.58))
	var post := CylinderMesh.new()
	post.top_radius = 0.10; post.bottom_radius = 0.12; post.height = 0.95
	map.add_child(_make_visual(post, Vector3(16, 0.475, 32), conc_mat))
	map.add_child(_make_visual(_box_mesh(Vector3(0.25, 0.10, 0.20)),
		Vector3(16, 0.97, 32), conc_mat))

func _add_campetto(map: Node3D) -> void:
	# Sand/dirt surface — tan/beige color, NOT concrete grey
	map.add_child(_make_visual(_box_mesh(Vector3(28, 0.06, 16)),
		Vector3(-38, 0.03, 38), _make_mat(Color(0.72, 0.64, 0.44))))

	# Grey chain-link fence enclosure (~1.5m high, matches reference photo)
	var fence_mat := _make_mat(Color(0.60, 0.60, 0.62))
	# Long sides (north + south)
	for xi in range(7):
		var fx: float = -52.0 + xi * 4.8
		map.add_child(_make_visual(_box_mesh(Vector3(0.07, 1.5, 0.07)),
			Vector3(fx, 0.75, 30.0), fence_mat))
		map.add_child(_make_visual(_box_mesh(Vector3(0.07, 1.5, 0.07)),
			Vector3(fx, 0.75, 46.0), fence_mat))
	# Short sides (east + west)
	for zi in range(4):
		var fz: float = 30.0 + zi * 5.4
		map.add_child(_make_visual(_box_mesh(Vector3(0.07, 1.5, 0.07)),
			Vector3(-52.0, 0.75, fz), fence_mat))
		map.add_child(_make_visual(_box_mesh(Vector3(0.07, 1.5, 0.07)),
			Vector3(-24.0, 0.75, fz), fence_mat))
	# Horizontal rails top
	map.add_child(_make_visual(_box_mesh(Vector3(28.0, 0.06, 0.07)),
		Vector3(-38, 1.48, 30.0), fence_mat))
	map.add_child(_make_visual(_box_mesh(Vector3(28.0, 0.06, 0.07)),
		Vector3(-38, 1.48, 46.0), fence_mat))
	map.add_child(_make_visual(_box_mesh(Vector3(0.07, 0.06, 16.0)),
		Vector3(-52.0, 1.48, 38), fence_mat))
	map.add_child(_make_visual(_box_mesh(Vector3(0.07, 0.06, 16.0)),
		Vector3(-24.0, 1.48, 38), fence_mat))

	# Two simple metal soccer goals (one at each end)
	var goal_mat := _make_mat(Color(0.80, 0.80, 0.82))
	for gx: float in [-52.0, -24.0]:
		# Posts
		map.add_child(_make_visual(_box_mesh(Vector3(0.08, 2.0, 0.08)),
			Vector3(gx, 1.0, 36.5), goal_mat))
		map.add_child(_make_visual(_box_mesh(Vector3(0.08, 2.0, 0.08)),
			Vector3(gx, 1.0, 39.5), goal_mat))
		# Crossbar
		map.add_child(_make_visual(_box_mesh(Vector3(0.08, 0.08, 3.1)),
			Vector3(gx, 2.0, 38.0), goal_mat))
		# Back post
		var depth_sign: float = 1.0 if gx < -38.0 else -1.0
		map.add_child(_make_visual(_box_mesh(Vector3(1.2, 0.06, 0.06)),
			Vector3(gx + depth_sign * 0.6, 1.0, 36.5), goal_mat))
		map.add_child(_make_visual(_box_mesh(Vector3(1.2, 0.06, 0.06)),
			Vector3(gx + depth_sign * 0.6, 1.0, 39.5), goal_mat))

	# Trees around the outside
	for tx: float in [-55.0, -45.0, -35.0, -25.0, -20.0]:
		_add_tree(map, Vector3(tx, 0, 26))
		_add_tree(map, Vector3(tx, 0, 50))

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

func _spawn_npc(pos: Vector3, color: Color, display_name: String, model_path: String = "") -> CharacterBody3D:
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
	npc.call("init", color, display_name, model_path)
	return npc

func _setup_npcs() -> void:
	_huncho_npc = _spawn_npc(Vector3(-50, 1.0, 2.5), Color(0.9, 0.6, 0.1), "Huncho", "res://characters/huncho.glb")
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
