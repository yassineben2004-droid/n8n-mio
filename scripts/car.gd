extends CharacterBody3D

const ACCEL := 15.0
const MAX_SPEED := 22.0
const DECEL := 18.0
const STEER_SPEED := 1.8
const GRAVITY := -9.8

var _speed := 0.0
var _steer := 0.0

func _accel_input() -> float:
	if InputMap.has_action("move_forward"):
		if Input.is_action_pressed("move_forward"):  return 1.0
		if Input.is_action_pressed("move_backward"): return -1.0
		return 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):   return 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): return -1.0
	return 0.0

func _steer_input() -> float:
	if InputMap.has_action("move_left"):
		return Input.get_axis("move_right", "move_left")
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  return 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): return -1.0
	return 0.0

func _enter_exit_pressed() -> bool:
	if InputMap.has_action("enter_exit_vehicle"):
		return Input.is_action_just_pressed("enter_exit_vehicle")
	return Input.is_key_pressed(KEY_E)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var accel := _accel_input()
	if accel > 0.0:
		_speed = move_toward(_speed, MAX_SPEED, ACCEL * delta)
	elif accel < 0.0:
		_speed = move_toward(_speed, -MAX_SPEED * 0.4, ACCEL * delta)
	else:
		_speed = move_toward(_speed, 0.0, DECEL * delta)

	if abs(_speed) > 0.5:
		_steer = move_toward(_steer, _steer_input(), STEER_SPEED * delta * 3.0)
		rotation.y += _steer * sign(_speed) * delta * 1.2
	else:
		_steer = move_toward(_steer, 0.0, STEER_SPEED * delta * 5.0)

	var forward := -global_transform.basis.z
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed

	move_and_slide()

	# Sync _speed with actual post-collision velocity to prevent stutter/blocking
	if get_slide_collision_count() > 0:
		var actual := Vector2(velocity.x, velocity.z).length()
		if _speed != 0.0:
			_speed = actual * sign(_speed)
