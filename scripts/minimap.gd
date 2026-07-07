extends CanvasLayer

var _viewport: SubViewport
var _cam: Camera3D
var _player: Node3D = null
var _stats: Node = null

const MAP_SIZE   := 140
const CAM_RANGE  := 80.0
const DOT_SIZE   := 6

func setup(player: Node3D, stats: Node) -> void:
	_player = player
	_stats  = stats

func _ready() -> void:
	_build_map_ui()

func _build_map_ui() -> void:
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

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08, 0.82)
	bg.size  = Vector2(MAP_SIZE, MAP_SIZE)
	container.add_child(bg)

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

	var tex := TextureRect.new()
	tex.texture = _viewport.get_texture()
	tex.size    = Vector2(MAP_SIZE, MAP_SIZE)
	container.add_child(tex)

	for edge in [Vector2(0,0), Vector2(0, MAP_SIZE-2), Vector2(MAP_SIZE-2, 0)]:
		var b := ColorRect.new()
		b.color = Color(0.55, 0.55, 0.60, 0.9)
		b.size  = Vector2(MAP_SIZE, 2) if edge.x == 0 else Vector2(2, MAP_SIZE)
		b.position = edge
		container.add_child(b)
	var br := ColorRect.new()
	br.color = Color(0.55, 0.55, 0.60, 0.9)
	br.size = Vector2(2, MAP_SIZE)
	br.position = Vector2(MAP_SIZE - 2, 0)
	container.add_child(br)

	var player_dot := ColorRect.new()
	player_dot.name  = "PlayerDot"
	player_dot.color = Color(1, 1, 1)
	player_dot.size  = Vector2(DOT_SIZE, DOT_SIZE)
	player_dot.position = Vector2(MAP_SIZE / 2.0 - DOT_SIZE / 2.0, MAP_SIZE / 2.0 - DOT_SIZE / 2.0)
	container.add_child(player_dot)

func _process(_delta: float) -> void:
	if not _player or not _viewport:
		return
	_cam.global_position = _player.global_position + Vector3(0, 60, 0)
	_cam.rotation_degrees = Vector3(-90, 0, 0)
