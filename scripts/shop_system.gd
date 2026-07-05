extends Node

const SHOP_RADIUS := 5.0

var _player: Node3D = null
var _stats: Node = null
var _near_shop := false
var _shop_open := false
var _prompt_label: Label = null
var _menu_panel: Control = null
var _canvas: CanvasLayer = null

const ITEMS := [
	{"name": "Panino",      "price": 10, "hp": 25},
	{"name": "Birra",       "price": 5,  "hp": 10},
	{"name": "Caffe",       "price": 3,  "hp": 5},
	{"name": "Pizza slice", "price": 15, "hp": 40},
]

const SHOP_POS := Vector3(-100.0, 0.0, -3.0)

func setup(player: Node3D, stats: Node) -> void:
	_player = player
	_stats  = stats

func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "ShopUI"
	get_parent().add_child(_canvas)
	_build_prompt()
	_build_menu()

func _build_prompt() -> void:
	_prompt_label = Label.new()
	_prompt_label.anchor_left   = 0.5; _prompt_label.anchor_right  = 0.5
	_prompt_label.anchor_top    = 0.5; _prompt_label.anchor_bottom = 0.5
	_prompt_label.offset_left   = -200; _prompt_label.offset_right  = 200
	_prompt_label.offset_top    = 80;   _prompt_label.offset_bottom = 110
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	_prompt_label.visible = false
	_canvas.add_child(_prompt_label)

func _build_menu() -> void:
	_menu_panel = Control.new()
	_menu_panel.name = "ShopMenu"
	_menu_panel.anchor_left   = 0.5; _menu_panel.anchor_right  = 0.5
	_menu_panel.anchor_top    = 0.5; _menu_panel.anchor_bottom = 0.5
	_menu_panel.offset_left   = -180; _menu_panel.offset_right  = 180
	_menu_panel.offset_top    = -130; _menu_panel.offset_bottom = 130
	_menu_panel.visible = false
	_canvas.add_child(_menu_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.04, 0.92)
	bg.size  = Vector2(360, 260)
	_menu_panel.add_child(bg)

	var title := Label.new()
	title.text = "Caffe Molinari"
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_menu_panel.add_child(title)

	for i in range(ITEMS.size()):
		var item: Dictionary = ITEMS[i]
		var row   := Label.new()
		row.name  = "Item%d" % i
		row.text  = "[%d] %s  +%dHP  E%d" % [i + 1, item["name"], item["hp"], item["price"]]
		row.position = Vector2(20, 50 + i * 42)
		row.add_theme_font_size_override("font_size", 18)
		row.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		_menu_panel.add_child(row)

	var close_lbl := Label.new()
	close_lbl.text = "[ESC] Chiudi"
	close_lbl.position = Vector2(20, 222)
	close_lbl.add_theme_font_size_override("font_size", 15)
	close_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_menu_panel.add_child(close_lbl)

func _process(_delta: float) -> void:
	if not _player:
		return
	var dist: float = _player.global_position.distance_to(SHOP_POS)
	var near := dist < SHOP_RADIUS

	if near and not _near_shop:
		_near_shop = true
		_prompt_label.text = "[ E ]  Entra al Caffe Molinari"
		_prompt_label.visible = true
	elif not near and _near_shop:
		_near_shop = false
		_prompt_label.visible = false
		_close_menu()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E and _near_shop and not _shop_open:
			_open_menu()
			return
		if _shop_open:
			if event.keycode == KEY_ESCAPE:
				_close_menu()
			elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
				var idx: int = event.keycode - KEY_1
				_buy(idx)

func _open_menu() -> void:
	_shop_open = true
	_prompt_label.visible = false
	_menu_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_menu() -> void:
	_shop_open = false
	_menu_panel.visible = false
	if _near_shop:
		_prompt_label.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _buy(idx: int) -> void:
	if idx < 0 or idx >= ITEMS.size():
		return
	var item: Dictionary = ITEMS[idx]
	if _stats.money < item["price"]:
		_flash_row(idx, Color(0.9, 0.1, 0.1))
		return
	_stats.add_money(-item["price"])
	_stats.heal(item["hp"])
	_flash_row(idx, Color(0.2, 0.9, 0.2))
	_close_menu()

func _flash_row(idx: int, color: Color) -> void:
	var row := _menu_panel.get_node_or_null("Item%d" % idx) as Label
	if not row:
		return
	row.add_theme_color_override("font_color", color)
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(row):
			row.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9)))
