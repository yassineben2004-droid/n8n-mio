extends Node

# Missione 02 — Difendi il Campetto
# Trigger: Peco al campetto (x=-38, z=40)
# Obiettivo: sconfiggi 3 nemici prima che scada il tempo
# Reward: €300

enum State { INACTIVE, NEAR_PECO, DIALOGUE, ACTIVE, COMPLETE, FAILED }

const TRIGGER_DIST := 3.5
const TIMER_MAX    := 90.0
const REWARD       := 300
const ENEMY_TOTAL  := 3

var state := State.INACTIVE
var player: Node3D
var peco: Node3D
var label_objective: Label
var label_dialogue: Label
var _e_prompt: Label
var _dialogue_timer  := 0.0
var _mission_timer   := 0.0
var _enemies: Array  = []
var _defeated_count  := 0
var _enemy_root: Node3D = null

func setup(p: Node3D, peco_npc: Node3D, obj_lbl: Label, dlg_lbl: Label) -> void:
	player = p
	peco   = peco_npc
	label_objective = obj_lbl
	label_dialogue  = dlg_lbl
	_e_prompt = Label.new()
	_e_prompt.anchor_left   = 0.5; _e_prompt.anchor_right  = 0.5
	_e_prompt.anchor_top    = 0.5; _e_prompt.anchor_bottom = 0.5
	_e_prompt.offset_left   = -150.0; _e_prompt.offset_right  = 150.0
	_e_prompt.offset_top    = 90.0;   _e_prompt.offset_bottom = 120.0
	_e_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_e_prompt.add_theme_font_size_override("font_size", 18)
	_e_prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5, 0.95))
	_e_prompt.visible = false
	var ui := get_parent().get_node_or_null("UI")
	if ui:
		ui.add_child(_e_prompt)

func _process(delta: float) -> void:
	if not player:
		return
	match state:
		State.INACTIVE:
			_check_peco_proximity()
		State.NEAR_PECO:
			_check_peco_proximity()
			if Input.is_key_pressed(KEY_E):
				_start_dialogue()
		State.DIALOGUE:
			_dialogue_timer += delta
			if _dialogue_timer >= 3.5:
				_begin_mission()
		State.ACTIVE:
			_mission_timer += delta
			var remaining := TIMER_MAX - _mission_timer
			_set_obj("[ Campetto — %d/3 nemici ]   Tempo: %ds" % [_defeated_count, int(remaining)])
			if remaining <= 0.0:
				_fail()
		State.FAILED, State.COMPLETE:
			pass

func _check_peco_proximity() -> void:
	if not peco:
		return
	var near := player.global_position.distance_to(peco.global_position) < TRIGGER_DIST
	if near and state == State.INACTIVE:
		state = State.NEAR_PECO
		_set_dlg("[ E ]  Parla con Peco")
		if _e_prompt:
			_e_prompt.text = "[ E ]  Parla con Peco"
			_e_prompt.visible = true
	elif not near and state == State.NEAR_PECO:
		state = State.INACTIVE
		_set_dlg("")
		if _e_prompt:
			_e_prompt.visible = false

func _start_dialogue() -> void:
	state = State.DIALOGUE
	_dialogue_timer = 0.0
	if _e_prompt:
		_e_prompt.visible = false
	_set_dlg("Peco: \"Frat, al campetto ci sono dei tizi che rompono. Cacciamoli!\"")

func _begin_mission() -> void:
	state = State.ACTIVE
	_mission_timer = 0.0
	_defeated_count = 0
	_set_dlg("")
	_set_obj("[ Difendi il Campetto — 0/3 nemici ]")
	_spawn_enemies()

func _spawn_enemies() -> void:
	_enemy_root = Node3D.new()
	_enemy_root.name = "M02Enemies"
	get_tree().current_scene.add_child(_enemy_root)

	var spawn_pts := [
		Vector3(-48.0, 1.0, 36.0),
		Vector3(-32.0, 1.0, 32.0),
		Vector3(-30.0, 1.0, 44.0)
	]
	for sp in spawn_pts:
		var enemy := CharacterBody3D.new()
		var col := CollisionShape3D.new()
		var cap_shape := CapsuleShape3D.new()
		cap_shape.radius = 0.35; cap_shape.height = 1.7
		col.shape = cap_shape; col.position = Vector3(0, 0.85, 0)
		enemy.add_child(col)
		enemy.position = sp
		enemy.set_script(load("res://scripts/npc.gd"))
		enemy.add_to_group("npc")
		_enemy_root.add_child(enemy)
		enemy.call("init", Color(0.82, 0.12, 0.12), "Nemico")
		enemy.knocked_down.connect(_on_enemy_knocked_down)
		_enemies.append(enemy)

func _on_enemy_knocked_down() -> void:
	if state != State.ACTIVE:
		return
	_defeated_count += 1
	if _defeated_count >= ENEMY_TOTAL:
		_complete()

func _complete() -> void:
	state = State.COMPLETE
	_set_dlg("Peco: \"Bravo frat! Campetto e nostro!\"")
	_set_obj("Campetto difeso!   +E%d" % REWARD)
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats:
		stats.add_money(REWARD)
	get_tree().create_timer(4.0).timeout.connect(_clear_ui)

func _fail() -> void:
	state = State.FAILED
	_set_obj("Missione fallita — tempo scaduto")
	_set_dlg("Peco: \"Troppo lenti! Ci hanno preso il campetto!\"")
	if _enemy_root and is_instance_valid(_enemy_root):
		_enemy_root.queue_free()
	get_tree().create_timer(4.0).timeout.connect(_retry)

func _retry() -> void:
	state = State.INACTIVE
	_mission_timer = 0.0
	_dialogue_timer = 0.0
	_enemies.clear()
	_defeated_count = 0
	_enemy_root = null
	_set_obj("")
	_set_dlg("")

func _clear_ui() -> void:
	_set_obj("")
	_set_dlg("")
	if _enemy_root and is_instance_valid(_enemy_root):
		_enemy_root.queue_free()
	_enemies.clear()
	_enemy_root = null

func _set_obj(text: String) -> void:
	if label_objective:
		label_objective.text = text

func _set_dlg(text: String) -> void:
	if label_dialogue:
		label_dialogue.text = text
