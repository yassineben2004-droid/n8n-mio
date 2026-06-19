extends CharacterBody3D

signal knocked_down

enum State { IDLE, WALK, REACT, FIGHT, FLEE, KNOCKDOWN }

const WALK_SPEED     := 1.4
const RUN_SPEED      := 4.2
const FIGHT_SPEED    := 2.8
const WANDER_RADIUS  := 12.0
const REACT_DISTANCE := 3.0
const FIGHT_DISTANCE := 1.6
const GRAVITY        := -9.8
const PUNCH_DAMAGE   := 15
const PUNCH_INTERVAL := 1.4

var state        := State.IDLE
var _idle_timer  := 0.0
var _idle_wait   := 0.0
var _waypoint    := Vector3.ZERO
var _react_timer := 0.0
var _fight_timer := 0.0
var _knockdown_timer := 0.0
var _player: Node3D = null
var _color       := Color.WHITE
var npc_name     := "NPC"
var npc_type     := "CIVILIAN"
var npc_hp       := 60
var defeated     := false

var _hp_bar: Node3D = null

const FIGHTER_INSULTS := [
	"Sei morto!", "Vaffanculo!", "Ti spacco!",
	"Hai rotto i coglioni!", "Adesso ti sistemo io!"
]
const CIVILIAN_INSULTS := [
	"Aiuto!", "Che cavolo fai?!", "Chiamo la madama!",
	"Sei scemo?!", "Ma sei matto?!"
]

func init(color: Color, display_name: String, model_path: String = "") -> void:
	_color = color
	npc_name = display_name
	if display_name in ["Huncho", "Chakour", "Peco", "Yzilow", "Mimmo", "Lucas", "Madama", "Nemico"]:
		npc_type = "FIGHTER"
	else:
		npc_type = "CIVILIAN"
	add_to_group("npc")
	_build_mesh()
	_idle_wait = randf_range(1.5, 4.0)

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
		State.IDLE:      _do_idle(delta)
		State.WALK:      _do_walk(delta)
		State.REACT:     _do_react(delta)
		State.FIGHT:     _do_fight(delta)
		State.FLEE:      _do_flee(delta)
		State.KNOCKDOWN: _do_knockdown(delta)

	move_and_slide()
	if state not in [State.FIGHT, State.FLEE, State.KNOCKDOWN]:
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
	_look_at_player(delta)
	_react_timer += delta
	if _react_timer >= 2.0:
		_react_timer = 0.0
		state = State.IDLE

func _do_fight(delta: float) -> void:
	if not _player:
		state = State.IDLE
		return
	_look_at_player(delta)
	var dist := global_position.distance_to(_player.global_position)
	if dist > FIGHT_DISTANCE + 1.0:
		var dir := (_player.global_position - global_position).normalized()
		dir.y = 0.0
		velocity.x = dir.x * FIGHT_SPEED
		velocity.z = dir.z * FIGHT_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		_fight_timer += delta
		if _fight_timer >= PUNCH_INTERVAL:
			_fight_timer = 0.0
			_punch_player()

func _do_flee(delta: float) -> void:
	if not _player:
		state = State.IDLE
		return
	var away := (global_position - _player.global_position).normalized()
	away.y = 0.0
	velocity.x = away.x * RUN_SPEED
	velocity.z = away.z * RUN_SPEED
	rotation.y = lerp_angle(rotation.y, atan2(away.x, away.z), 6.0 * delta)
	_react_timer += delta
	if _react_timer >= 8.0:
		state = State.IDLE
		_react_timer = 0.0

func _do_knockdown(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	_knockdown_timer -= delta
	if _knockdown_timer <= 0.0:
		if not defeated:
			npc_hp = 30
			if npc_type == "FIGHTER":
				state = State.FIGHT
			else:
				state = State.FLEE

func _check_player_proximity() -> void:
	if not _player:
		return
	if global_position.distance_to(_player.global_position) < REACT_DISTANCE:
		state = State.REACT
		_react_timer = 0.0

func _look_at_player(delta: float) -> void:
	if not _player:
		return
	var look_dir := (_player.global_position - global_position)
	look_dir.y = 0.0
	if look_dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(look_dir.x, look_dir.z), 6.0 * delta)

func _punch_player() -> void:
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats:
		stats.take_damage(PUNCH_DAMAGE)
	_show_insult(FIGHTER_INSULTS)

func take_hit(dmg: int, is_combo: bool = false) -> void:
	if defeated:
		return
	npc_hp -= dmg
	_show_hp_bar()
	if npc_type == "FIGHTER":
		_show_insult(FIGHTER_INSULTS)
		if npc_hp <= 0:
			_enter_knockdown()
		else:
			state = State.FIGHT
			_fight_timer = 0.0
	else:
		_show_insult(CIVILIAN_INSULTS)
		if npc_hp <= 0:
			_enter_knockdown()
		else:
			state = State.FLEE
			_react_timer = 0.0

func _enter_knockdown() -> void:
	state = State.KNOCKDOWN
	_knockdown_timer = 5.0
	rotation_degrees.x = 0.0
	knocked_down.emit()

func _show_insult(insults: Array) -> void:
	var line: String = insults[randi() % insults.size()]
	var lbl := Label3D.new()
	lbl.text = line
	lbl.font_size = 44
	lbl.modulate = Color(1, 0.2, 0.2) if npc_type == "FIGHTER" else Color(1, 0.9, 0.2)
	lbl.outline_size = 6
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = global_position + Vector3(0, 2.6, 0)
	get_tree().current_scene.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 0.0, 2.0)
	tw.tween_callback(lbl.queue_free)

func _show_hp_bar() -> void:
	if _hp_bar:
		return
	_hp_bar = Node3D.new()
	_hp_bar.position = Vector3(0, 2.1, 0)
	add_child(_hp_bar)
	var bg := MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(0.8, 0.08, 0.02)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.15, 0.05, 0.05)
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg.mesh = bg_mesh; bg.material_override = bg_mat
	_hp_bar.add_child(bg)
	var fill := MeshInstance3D.new()
	fill.name = "HPFill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(0.78, 0.06, 0.025)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.9, 0.1, 0.1)
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill.mesh = fill_mesh; fill.material_override = fill_mat
	_hp_bar.add_child(fill)

func _pick_waypoint() -> void:
	var angle := randf() * TAU
	var dist  := randf_range(3.0, WANDER_RADIUS)
	_waypoint = global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
