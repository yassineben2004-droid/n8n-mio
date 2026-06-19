extends CharacterBody3D

enum State { IDLE, WALK, REACT }

const WALK_SPEED    := 1.4
const WANDER_RADIUS := 12.0
const REACT_DISTANCE := 3.0
const GRAVITY       := -9.8

var state        := State.IDLE
var _idle_timer  := 0.0
var _idle_wait   := 0.0
var _waypoint    := Vector3.ZERO
var _react_timer := 0.0
var _player: Node3D = null
var _color       := Color.WHITE
var npc_name     := "NPC"

var _ap_idle: AnimationPlayer = null
var _ap_walk: AnimationPlayer = null
var _model_root: Node3D = null

func init(color: Color, display_name: String, model_path: String = "") -> void:
	_color = color
	npc_name = display_name
	if model_path != "":
		_load_model(model_path)
	else:
		_build_mesh()
	_idle_wait = randf_range(1.5, 4.0)

func _load_model(path: String) -> void:
	var packed = load(path)
	if not packed:
		print("WARN NPC: modello non trovato ", path)
		_build_mesh()
		return
	_model_root = packed.instantiate()
	_model_root.name = "NPCModel"
	_model_root.scale = Vector3(1.0, 1.0, 1.0)
	_model_root.position = Vector3(0, 0.9, 0)
	add_child(_model_root)
	_unshade(_model_root)
	# Prendi l'AnimationPlayer e mettilo in loop
	var ap: AnimationPlayer = _model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.get_animation_list().size() > 0:
		var anim_name: String = ap.get_animation_list()[0]
		var anim: Animation = ap.get_animation(anim_name)
		anim.loop_mode = Animation.LOOP_LINEAR
		ap.play(anim_name)
		_ap_idle = ap
	print("NPC modello caricato: ", npc_name)

func _build_mesh() -> void:
	var mesh_inst := MeshInstance3D.new()
	var cap       := CapsuleMesh.new()
	cap.radius    = 0.35
	cap.height    = 1.7
	var mat       := StandardMaterial3D.new()
	mat.albedo_color = _color
	cap.material  = mat
	mesh_inst.mesh = cap
	mesh_inst.position.y = 0.85
	add_child(mesh_inst)

func _unshade(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var mat = mi.mesh.surface_get_material(i)
				if mat is BaseMaterial3D:
					var dup: BaseMaterial3D = mat.duplicate()
					dup.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					mi.mesh.surface_set_material(i, dup)
	for c in node.get_children():
		_unshade(c)

func _ready() -> void:
	_waypoint = global_position
	_find_player()

func _find_player() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match state:
		State.IDLE:
			_do_idle(delta)
		State.WALK:
			_do_walk(delta)
		State.REACT:
			_do_react(delta)

	move_and_slide()
	_check_player_proximity()

func _do_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
	_idle_timer += delta
	if _idle_timer >= _idle_wait:
		_idle_timer = 0.0
		_idle_wait = randf_range(2.0, 5.0)
		_pick_waypoint()
		state = State.WALK

func _do_walk(delta: float) -> void:
	var diff := _waypoint - global_position
	diff.y = 0.0
	if diff.length() < 0.5:
		state = State.IDLE
		return
	var dir := diff.normalized()
	velocity.x = dir.x * WALK_SPEED
	velocity.z = dir.z * WALK_SPEED
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 6.0 * delta)

func _do_react(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
	if _player:
		var look_dir := (_player.global_position - global_position)
		look_dir.y = 0.0
		if look_dir.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(look_dir.x, look_dir.z), 6.0 * delta)
	_react_timer += delta
	if _react_timer >= 2.0:
		_react_timer = 0.0
		state = State.IDLE

func _check_player_proximity() -> void:
	if state == State.REACT or not _player:
		return
	if global_position.distance_to(_player.global_position) < REACT_DISTANCE:
		state = State.REACT
		_react_timer = 0.0

func _pick_waypoint() -> void:
	var angle := randf() * TAU
	var dist  := randf_range(3.0, WANDER_RADIUS)
	_waypoint = global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
