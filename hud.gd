extends CanvasLayer

var _hp_bar: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label
var _money_label: Label
var _star_labels: Array = []
var _stats: Node = null

func setup(stats: Node) -> void:
	_stats = stats
	_stats.hp_changed.connect(_on_hp_changed)
	_stats.money_changed.connect(_on_money_changed)
	_stats.wanted_changed.connect(_on_wanted_changed)

func _ready() -> void:
	_build_hp_bar()
	_build_money_label()
	_build_wanted_stars()

func _build_hp_bar() -> void:
	# Sfondo barra HP
	_hp_bar = ColorRect.new()
	_hp_bar.color = Color(0.15, 0.05, 0.05, 0.85)
	_hp_bar.size = Vector2(180, 18)
	_hp_bar.position = Vector2(16, 16)
	add_child(_hp_bar)
	# Fill barra HP
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.18, 0.78, 0.18)
	_hp_fill.size = Vector2(178, 14)
	_hp_fill.position = Vector2(17, 18)
	add_child(_hp_fill)
	# Label HP
	_hp_label = Label.new()
	_hp_label.text = "HP 100"
	_hp_label.position = Vector2(16, 36)
	_hp_label.add_theme_font_size_override("font_size", 14)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(_hp_label)

func _build_money_label() -> void:
	_money_label = Label.new()
	_money_label.text = "€ 0"
	_money_label.anchor_left  = 1.0
	_money_label.anchor_right = 1.0
	_money_label.offset_left  = -160.0
	_money_label.offset_top   = 16.0
	_money_label.add_theme_font_size_override("font_size", 26)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.1))
	add_child(_money_label)

func _build_wanted_stars() -> void:
	for i in range(5):
		var star := Label.new()
		star.text = "★"
		star.anchor_left  = 1.0
		star.anchor_right = 1.0
		star.offset_left  = -155.0 + i * 28.0
		star.offset_top   = 48.0
		star.add_theme_font_size_override("font_size", 24)
		star.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 0.7))
		add_child(star)
		_star_labels.append(star)

func _on_hp_changed(new_hp: int) -> void:
	var pct := float(new_hp) / 100.0
	_hp_fill.size.x = 178.0 * pct
	_hp_label.text = "HP %d" % new_hp
	if pct > 0.5:
		_hp_fill.color = Color(0.18, 0.78, 0.18)
	elif pct > 0.25:
		_hp_fill.color = Color(0.9, 0.72, 0.06)
	else:
		_hp_fill.color = Color(0.85, 0.10, 0.10)

func _on_money_changed(new_money: int) -> void:
	_money_label.text = "€ %d" % new_money

func _on_wanted_changed(new_level: int) -> void:
	for i in range(5):
		var active := i < new_level
		_star_labels[i].add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.0) if active else Color(0.3, 0.3, 0.3, 0.7))
