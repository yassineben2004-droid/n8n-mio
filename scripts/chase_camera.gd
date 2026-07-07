extends Camera3D

var target: Node3D = null
var offset_dist   := 6.0
var offset_height := 3.0

var _yaw        := 0.0
var _pitch      := 0.2
var _mouse_idle := 0.0

const PITCH_MIN := -0.1
const PITCH_MAX :=  0.72
const MOUSE_SENS := 0.003

# Auto-align: camera torna dietro al target quando non muovi il mouse
const DELAY_WALK := 1.2   # secondi prima dell'auto-align a piedi
const DELAY_CAR  := 0.7   # più reattivo in macchina
const SPEED_WALK := 2.2   # velocità di riallineamento a piedi
const SPEED_CAR  := 5.0   # velocità in macchina

# Camera follow: più scattante in macchina
const CAM_FOLLOW_WALK := 8.0
const CAM_FOLLOW_CAR  := 18.0

func _ready() -> void:
	add_to_group("camera")

func set_target(node: Node3D) -> void:
	target = node
	print("Camera target: ", str(node.name) if node else "null")

func align_to_node(node: Node3D) -> void:
	_yaw = node.rotation.y
	_mouse_idle = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw      -= event.relative.x * MOUSE_SENS
		_pitch    -= event.relative.y * MOUSE_SENS
		_pitch     = clamp(_pitch, PITCH_MIN, PITCH_MAX)
		_mouse_idle = 0.0

func _process(delta: float) -> void:
	if not target:
		return

	_mouse_idle += delta

	var is_car := target is CharacterBody3D and target.name == "Car"

	# Auto-align yaw dietro al target
	var delay := DELAY_CAR if is_car else DELAY_WALK
	var align_spd := SPEED_CAR if is_car else SPEED_WALK
	var min_spd := 2.5 if is_car else 0.8

	# Auto-align solo in macchina — a piedi crea feedback loop (player segue camera che segue player)
	if _mouse_idle > delay and is_car:
		var horiz := Vector2(target.velocity.x, target.velocity.z).length()
		if horiz > min_spd:
			_yaw = lerp_angle(_yaw, target.rotation.y, align_spd * delta)

	# Posizione camera
	var horizontal := Vector3(sin(_yaw), 0.0, cos(_yaw)) * offset_dist
	var vertical   := Vector3(0.0, offset_height + _pitch * offset_dist, 0.0)
	var desired    := target.global_position + horizontal + vertical

	var follow_spd := CAM_FOLLOW_CAR if is_car else CAM_FOLLOW_WALK
	global_position = global_position.lerp(desired, clamp(follow_spd * delta, 0.0, 1.0))
	look_at(target.global_position + Vector3(0, 1.2, 0), Vector3.UP)
