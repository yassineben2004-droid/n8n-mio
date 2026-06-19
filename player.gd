extends CharacterBody3D

const SPEED        := 5.0
const SPRINT_SPEED := 9.0
const GRAVITY      := -9.8
const JUMP_SPEED   := 6.5

var in_vehicle   := false
var _state       := ""
var _models      := {}
var _punch_timer := 0.0

func _ready() -> void:
	_hide_capsule()
	_load_models()

func _hide_capsule() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false

func _load_models() -> void:
	var files := {
		"idle":  "res://characters/sugo_idle.glb",
		"walk":  "res://characters/sugo_walk.glb",
		"run":   "res://characters/sugo_run.glb",
		"jump":  "res://characters/sugo_jump.glb",
		"punch": "res://characters/sugo_punch.glb"
	}
	for state in files:
		var packed = load(files[state])
		if not packed:
			continue
		var model: Node3D = packed.instantiate()
		model.name = "SugoModel_" + state
		model.visible = false
		add_child(model)
		_unshade(model)
		var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.get_animation_list().size() > 0:
			var anim_name: String = ap.get_animation_list()[0]
			# Imposta loop
			var anim: Animation = ap.get_animation(anim_name)
			anim.loop_mode = Animation.LOOP_LINEAR
			ap.play(anim_name)
		_models[state] = model
		print("Animazione caricata: ", state)

	if _models.is_empty():
		_load_fallback()
	else:
		_switch("idle")
		_align_all_models()

func _load_fallback() -> void:
	var packed = load("res://characters/sugo.glb")
	if not packed:
		print("WARN: sugo.glb non trovato")
		return
	var model: Node3D = packed.instantiate()
	model.name = "SugoFallback"
	model.visible = true
	add_child(model)
	_unshade(model)
	_align_model(model)
	print("Fallback: sugo.glb caricato")

func _align_model(model: Node3D) -> void:
	model.scale = Vector3(1.0, 1.0, 1.0)
	model.position = Vector3(0, 0.0, 0)

func _align_all_models() -> void:
	for state in _models:
		_align_model(_models[state] as Node3D)

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

func _switch(new_state: String) -> void:
	if new_state == _state:
		return
	if _state in _models:
		_models[_state].visible = false
	_state = new_state
	if _state in _models:
		var model: Node3D = _models[_state]
		model.visible = true
		# Riavvia l'animazione da capo al cambio stato
		var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.get_animation_list().size() > 0:
			ap.play(ap.get_animation_list()[0])

func _get_move_dir() -> Vector2:
	if InputMap.has_action("move_forward"):
		return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var x := 0.0
	var y := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): x += 1.0
	return Vector2(x, y)

func _is_sprinting() -> bool:
	if InputMap.has_action("sprint"):
		return Input.is_action_pressed("sprint")
	return Input.is_key_pressed(KEY_SHIFT)

func _input(event: InputEvent) -> void:
	if in_vehicle:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_on_floor():
			velocity.y = JUMP_SPEED
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_on_floor() and _state != "punch":
			_punch_timer = 0.7
			_switch("punch")
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if is_on_floor() and _state != "punch":
			_punch_timer = 0.7
			_switch("punch")

func _physics_process(delta: float) -> void:
	if in_vehicle:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if _punch_timer > 0.0:
		_punch_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		move_and_slide()
		if _punch_timer <= 0.0:
			_switch("idle")
		return

	var cam: Camera3D = get_tree().get_first_node_in_group("camera")
	var input_dir := _get_move_dir()
	var direction := Vector3.ZERO

	if cam and input_dir.length() > 0.01:
		var forward := -cam.global_transform.basis.z
		var right   := cam.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		direction = (forward.normalized() * -input_dir.y + right.normalized() * input_dir.x).normalized()

	var spd := SPRINT_SPEED if _is_sprinting() else SPEED

	if direction.length() > 0.1:
		velocity.x = direction.x * spd
		velocity.z = direction.z * spd
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, spd * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, spd * 3.0)

	move_and_slide()

	var horiz := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		_switch("jump")
	elif horiz > 6.5:
		_switch("run")
	elif horiz > 0.5:
		_switch("walk")
	else:
		_switch("idle")
