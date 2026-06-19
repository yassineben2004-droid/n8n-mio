extends Node

const COOLDOWN_START    := 10.0
const STAR_DROP_RATE    := 5.0
const POLICE_SPAWN_DIST := 35.0
const ARREST_DIST       := 2.2
const ARREST_FINE       := 50
const CAR_SPEED         := 7.5
const CAR_CHASE_DIST    := 60.0

var _stats: Node = null
var _player: Node3D = null
var _cooldown_timer  := 0.0
var _star_drop_timer := 0.0
var _police_nodes: Array = []
var _police_cars: Array  = []
var _arrest_label: Label = null
var _arrested := false

func setup(player: Node3D, stats: Node) -> void:
	_player = player
	_stats  = stats
	_stats.wanted_changed.connect(_on_wanted_changed)
	_build_arrest_label()

func _build_arrest_label() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "WantedUI"
	get_parent().add_child(canvas)
	_arrest_label = Label.new()
	_arrest_label.anchor_left   = 0.5; _arrest_label.anchor_right  = 0.5
	_arrest_label.anchor_top    = 0.5; _arrest_label.anchor_bottom = 0.5
	_arrest_label.offset_left   = -250; _arrest_label.offset_right  = 250
	_arrest_label.offset_top    = -30;  _arrest_label.offset_bottom = 30
	_arrest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrest_label.add_theme_font_size_override("font_size", 32)
	_arrest_label.add_theme_color_override("font_color", Color(0.2, 0.5, 1.0))
	_arrest_label.visible = false
	canvas.add_child(_arrest_label)

func on_npc_hit() -> void:
	_cooldown_timer  = COOLDOWN_START
	_star_drop_timer = 0.0

func _process(delta: float) -> void:
	if _arrested or not _stats:
		return

	if _stats.wanted_level > 0:
		if _cooldown_timer > 0.0:
			_cooldown_timer -= delta
		else:
			_star_drop_timer += delta
			if _star_drop_timer >= STAR_DROP_RATE:
				_star_drop_timer = 0.0
				_stats.add_wanted(-1)

	_update_police_cars(delta)

	if _stats.wanted_level > 0 and _player:
		for cop in _police_nodes:
			if is_instance_valid(cop):
				if cop.global_position.distance_to(_player.global_position) < ARREST_DIST:
					_arrest()
					return

func _update_police_cars(delta: float) -> void:
	if not _player:
		return
	for car in _police_cars:
		if not is_instance_valid(car):
			continue
		var dist: float = car.global_position.distance_to(_player.global_position)
		if dist > CAR_CHASE_DIST:
			continue
		var dir: Vector3 = (_player.global_position - car.global_position)
		dir.y = 0.0
		if dir.length() > 1.0:
			dir = dir.normalized()
			car.global_position += dir * CAR_SPEED * delta
			car.rotation.y = lerp_angle(car.rotation.y, atan2(dir.x, dir.z), 4.0 * delta)
		if dist < ARREST_DIST + 1.0:
			_arrest()
			return

func _on_wanted_changed(level: int) -> void:
	if level >= 2 and _police_nodes.size() == 0:
		_spawn_police_npc(1)
	elif level >= 3 and _police_nodes.size() < 2:
		_spawn_police_npc(1)
		_spawn_police_car()
	if level == 0:
		_despawn_all()

func _spawn_police_npc(count: int) -> void:
	var main := get_tree().current_scene
	if not main.has_method("_spawn_npc"):
		return
	for i in range(count):
		var angle: float = randf() * TAU
		var pos := _player.global_position + Vector3(
			cos(angle) * POLICE_SPAWN_DIST, 0, sin(angle) * POLICE_SPAWN_DIST)
		var cop = main.call("_spawn_npc", pos, Color(0.15, 0.20, 0.55), "Madama", "")
		if cop:
			cop.set("npc_type", "FIGHTER")
			_police_nodes.append(cop)

func _spawn_police_car() -> void:
	if not _player:
		return
	var angle: float = randf() * TAU
	var pos := _player.global_position + Vector3(
		cos(angle) * POLICE_SPAWN_DIST, 0, sin(angle) * POLICE_SPAWN_DIST)
	var car_root := Node3D.new()
	car_root.name  = "PoliceCar"
	car_root.position = pos
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.8, 4.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.18, 0.72)
	mi.mesh = mesh; mi.material_override = mat
	mi.position.y = 0.7
	car_root.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color  = Color(0.2, 0.3, 1.0)
	light.light_energy = 3.0
	light.omni_range   = 12.0
	light.position     = Vector3(0, 1.6, 0)
	car_root.add_child(light)
	get_tree().current_scene.add_child(car_root)
	_police_cars.append(car_root)
	var tw := car_root.create_tween().set_loops()
	tw.tween_callback(func(): light.light_color = Color(1.0, 0.1, 0.1)).set_delay(0.4)
	tw.tween_callback(func(): light.light_color = Color(0.2, 0.3, 1.0)).set_delay(0.4)

func _arrest() -> void:
	if _arrested:
		return
	_arrested = true
	var fine := min(ARREST_FINE, _stats.money)
	_stats.add_money(-fine)
	_stats.set_wanted(0)
	_despawn_all()
	_arrest_label.text = "ARRESTATO!  -€%d" % fine
	_arrest_label.visible = true
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(_player):
			_player.global_position = Vector3(-40, 1.0, 0)
		_arrested = false
		_arrest_label.visible = false)

func _despawn_all() -> void:
	for cop in _police_nodes:
		if is_instance_valid(cop):
			cop.queue_free()
	_police_nodes.clear()
	for car in _police_cars:
		if is_instance_valid(car):
			car.queue_free()
	_police_cars.clear()
