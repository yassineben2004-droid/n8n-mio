extends CharacterBody3D

signal punched

const SPEED        := 5.0
const SPRINT_SPEED := 9.0
const GRAVITY      := -9.8
const JUMP_SPEED   := 6.5

var in_vehicle   := false
var _state       := ""
var _models      := {}
var _punch_timer := 0.0

# Code-based animation
var _visual_root  : Node3D = null
var _anim_player  : AnimationPlayer = null
var _anim_t       := 0.0
var _land_squash  := 0.0
var _was_on_floor := true

func _ready() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	_load_models()

func _find_glb(base: String) -> String:
	# Cerca il GLB sia in characters/ che nella radice del progetto
	for path in ["res://characters/" + base + ".glb", "res://" + base + ".glb"]:
		if ResourceLoader.exists(path):
			return path
	return ""

func _load_models() -> void:
	var states := ["idle", "walk", "run", "jump", "punch"]
	for state in states:
		var path := _find_glb("sugo_" + state)
		if path == "":
			continue
		var packed = load(path)
		if not packed:
			continue
		var model: Node3D = packed.instantiate()
		model.name = "SugoModel_" + state
		model.visible = false
		_visual_root.add_child(model)
		_unshade(model)
		var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.get_animation_list().size() > 0:
			for anim_name in ap.get_animation_list():
				ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
			ap.play(ap.get_animation_list()[0])
		_models[state] = model
		print("Animazione caricata: ", state)

	if _models.is_empty():
		_load_fallback()
		return

	# Hide capsule placeholder
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false

	await get_tree().process_frame
	_scale_all_models()
	_switch("idle")

func _load_fallback() -> void:
	var path := _find_glb("sugo")
	if path == "":
		print("WARN: nessun modello trovato — rimane capsula")
		return
	var packed = load(path)
	if not packed:
		print("WARN: nessun modello trovato — rimane capsula")
		return
	var model: Node3D = packed.instantiate()
	model.name = "SugoModel"
	_visual_root.add_child(model)
	_unshade(model)

	# Try to grab the AnimationPlayer for clip-based animations
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		_anim_player = ap
		print("AnimationPlayer trovato: ", ap.get_animation_list())

	for child in get_children():
		if child is MeshInstance3D and child.name != "VisualRoot":
			child.visible = false

	await get_tree().process_frame
	_scale_single_model(model)
	print("Fallback: sugo.glb caricato")

func _scale_single_model(model: Node3D) -> void:
	var combined := AABB()
	var first := true
	for mi in _collect_meshes(model):
		var aabb: AABB = mi.get_aabb()
		var global_aabb: AABB = mi.global_transform * aabb
		var local_aabb: AABB = model.global_transform.affine_inverse() * global_aabb
		if first:
			combined = local_aabb
			first = false
		else:
			combined = combined.merge(local_aabb)
	var height: float = combined.size.y
	if height > 0.01:
		var sf: float = 2.2 / height
		model.scale = Vector3.ONE * sf
		model.position.y = -combined.position.y * sf

func _scale_all_models() -> void:
	for state in _models:
		_scale_single_model(_models[state])

func _collect_meshes(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		result.append(node)
	for c in node.get_children():
		result.append_array(_collect_meshes(c))
	return result

func _unshade(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
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
	# Try AnimationPlayer clip first (single GLB with named animations)
	if _anim_player and _anim_player.has_animation(new_state):
		_anim_player.play(new_state)
		_state = new_state
		return
	# Multi-model switching
	if _state in _models:
		_models[_state].visible = false
	_state = new_state
	if _state in _models:
		_models[_state].visible = true

func _animate_visual(delta: float) -> void:
	if not _visual_root:
		return

	# Con i GLB animati veri il movimento lo fa lo scheletro:
	# teniamo solo lo squash di atterraggio
	if not _models.is_empty():
		var floor_now := is_on_floor()
		if floor_now and not _was_on_floor:
			_land_squash = 0.25
		_was_on_floor = floor_now
		_land_squash = move_toward(_land_squash, 0.0, delta * 4.0)
		var sy := 1.0 - _land_squash * 0.35
		var sxz := 1.0 + _land_squash * 0.20
		_visual_root.scale = Vector3(sxz, sy, sxz)
		return

	var on_floor := is_on_floor()
	var horiz    := Vector2(velocity.x, velocity.z).length()

	# Land squash on touchdown
	if on_floor and not _was_on_floor:
		_land_squash = 0.25
	_was_on_floor = on_floor

	_land_squash = move_toward(_land_squash, 0.0, delta * 4.0)

	var bob_y    := 0.0
	var roll     := 0.0
	var tilt     := 0.0
	var scale_y  := 1.0
	var scale_xz := 1.0
	var shake_x  := 0.0

	if _punch_timer > 0.0:
		_anim_t += delta * 18.0
		shake_x = sin(_anim_t) * 0.04 * (_punch_timer / 0.7)
		tilt     = deg_to_rad(-12.0) * (_punch_timer / 0.7)

	elif not on_floor:
		scale_y  = 1.12
		scale_xz = 0.92
		tilt     = deg_to_rad(-8.0)

	elif horiz > 6.5:
		_anim_t += delta * 14.0
		bob_y = sin(_anim_t) * 0.07
		roll  = sin(_anim_t * 0.5) * deg_to_rad(4.0)
		tilt  = deg_to_rad(-10.0)

	elif horiz > 0.5:
		_anim_t += delta * 9.0
		bob_y = sin(_anim_t) * 0.04
		roll  = sin(_anim_t * 0.5) * deg_to_rad(2.5)

	else:
		_anim_t += delta * 1.8
		bob_y = sin(_anim_t) * 0.008

	if _land_squash > 0.0:
		scale_y  = 1.0 - _land_squash * 0.35
		scale_xz = 1.0 + _land_squash * 0.20

	_visual_root.position.y = bob_y
	_visual_root.position.x = shake_x
	_visual_root.rotation.z = roll
	_visual_root.rotation.x = tilt
	_visual_root.scale = Vector3(scale_xz, scale_y, scale_xz)

func _get_move_dir() -> Vector2:
	if InputMap.has_action("move_forward"):
		return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var x := 0.0; var y := 0.0
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
			punched.emit()

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
		_animate_visual(delta)
		if _punch_timer <= 0.0:
			_switch("idle")
		return

	var cam: Camera3D = get_tree().get_first_node_in_group("camera")
	var input_dir := _get_move_dir()
	var direction := Vector3.ZERO

	if cam and input_dir.length() > 0.01:
		var forward := -cam.global_transform.basis.z
		var right   := cam.global_transform.basis.x
		forward.y = 0.0; right.y = 0.0
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
	_animate_visual(delta)

	var horiz := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		_switch("jump")
	elif horiz > 6.5:
		_switch("run")
	elif horiz > 0.5:
		_switch("walk")
	else:
		_switch("idle")
