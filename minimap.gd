extends CanvasLayer

var _viewport: SubViewport
var _cam: Camera3D
var _player: Node3D = null
var _stats: Node = null

const MAP_SIZE   := 140  # pixel dimensione minimappa
const CAM_RANGE  := 80.0 # metri visibili attorno al player
const DOT_SIZE   := 6

func setup(player: Node3D, stats: Node) -> void:
	_player = player
	_stats  = stats

func _ready() -> void:
	_build_map_ui()

func _build_map_ui() -> void:
	# Container circolare in basso a sinistra
	var margin := 14
	var container := Control.new()
	container.name = "MinimapContainer"
	container.position = Vector2(margin, 0)
	container.anchor_top    = 1.0
	container.anchor_bottom = 1.0
	container.offset_top    = -(MAP_SIZE + margin)
	container.offset_bottom = -margin
	container.size          = Vector2(MAP_SIZE, MAP_SIZE)
	add_child(container)

	# Sfondo cerchio scuro semitrasparente
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08, 0.82)
	bg.size  = Vector2(MAP_SIZE, MAP_SIZE)
	container.add_child(bg)

	# SubViewport — camera ortografica dall'alto
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(MAP_SIZE, MAP_SIZE)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = true
	container.add_child(_viewport)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = CAM_RANGE
	_cam.rotation_degrees = Vector3(-90, 0, 0)
	_cam.position = Vector3(0, 60, 0)
	_cam.near = 1.0
	_cam.far  = 200.0
	_viewport.add_child(_cam)

	# Texture rect che mostra il viewport
	var tex := TextureRect.new()
	tex.texture = _viewport.get_texture()
	tex.size    = Vector2(MAP_SIZE, MAP_SIZE)
	container.add_child(tex)

	# Bordo cerchio
	var border := ColorRect.new()
	border.color = Color(0.55, 0.55, 0.60, 0.9)
	border.size  = Vector2(MAP_SIZE, 2)
	border.position = Vector2(0, 0)
	container.add_child(border)
	var border_b := ColorRect.new()
	border_b.color = Color(0.55, 0.55, 0.60, 0.9)
	border_b.size  = Vector2(MAP_SIZE, 2)
	border_b.position = Vector2(0, MAP_SIZE - 2)
	container.add_child(border_b)
	var border_l := ColorRect.new()
	border_l.color = Color(0.55, 0.55, 0.60, 0.9)
	border_l.size  = Vector2(2, MAP_SIZE)
	container.add_child(border_l)
	var border_r := ColorRect.new()
	border_r.color = Color(0.55, 0.55, 0.60, 0.9)
	border_r.size  = Vector2(2, MAP_SIZE)
	border_r.position = Vector2(MAP_SIZE - 2, 0)
	container.add_child(border_r)

	# Dot player (bianco, centro fisso)
	var player_dot := ColorRect.new()
	player_dot.name  = "PlayerDot"
	player_dot.color = Color(1, 1, 1)
	player_dot.size  = Vector2(DOT_SIZE, DOT_SIZE)
	player_dot.position = Vector2(MAP_SIZE / 2 - DOT_SIZE / 2, MAP_SIZE / 2 - DOT_SIZE / 2)
	container.add_child(player_dot)

func _process(_delta: float) -> void:
	if not _player or not _viewport:
		return
	# Muovi la camera sopra il player
	_cam.global_position = _player.global_position + Vector3(0, 60, 0)
	_cam.rotation_degrees = Vector3(-90, 0, 0)
