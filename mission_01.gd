extends Node

enum State { INACTIVE, NEAR_NPC, DIALOGUE, ACTIVE, FAILED, COMPLETE }

const TRIGGER_DIST := 3.5
const GOAL_DIST    := 4.0
const GOAL_POS     := Vector3(-100.0, 0.0, -2.0)
const TIME_LIMIT   := 60.0
const REWARD       := 200

var state := State.INACTIVE
var player: Node3D
var huncho: Node3D
var label_objective: Label
var label_dialogue: Label
var _dialogue_timer := 0.0
var _mission_timer  := 0.0
var _e_prompt: Label = null

func setup(p: Node3D, h: Node3D, obj_lbl: Label, dlg_lbl: Label) -> void:
	player = p
	huncho = h
	label_objective = obj_lbl
	label_dialogue = dlg_lbl
	# Prompt "E" — visibile solo quando sei vicino a Huncho
	_e_prompt = Label.new()
	_e_prompt.anchor_left  = 0.5; _e_prompt.anchor_right  = 0.5
	_e_prompt.anchor_top   = 0.5; _e_prompt.anchor_bottom = 0.5
	_e_prompt.offset_left  = -150.0; _e_prompt.offset_right  = 150.0
	_e_prompt.offset_top   = 60.0;   _e_prompt.offset_bottom = 90.0
	_e_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_e_prompt.add_theme_font_size_override("font_size", 18)
	_e_prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5, 0.95))
	_e_prompt.visible = false
	get_parent().get_node("UI").add_child(_e_prompt)

func _process(delta: float) -> void:
	if not player:
		return
	match state:
		State.INACTIVE:
			_check_npc_proximity()
		State.NEAR_NPC:
			_check_npc_proximity()
			if Input.is_key_pressed(KEY_E):
				_start_dialogue()
		State.DIALOGUE:
			_dialogue_timer += delta
			if _dialogue_timer >= 3.5:
				_begin_mission()
		State.ACTIVE:
			_mission_timer += delta
			var remaining := TIME_LIMIT - _mission_timer
			var dist := player.global_position.distance_to(GOAL_POS)
			_set_obj("[ Caffè Molinari — %dm ]   ⏱ %ds" % [int(dist), int(remaining)])
			if remaining <= 0.0:
				_fail()
			elif dist < GOAL_DIST:
				_complete()
		State.FAILED, State.COMPLETE:
			pass

func _check_npc_proximity() -> void:
	if not huncho:
		return
	var near := player.global_position.distance_to(huncho.global_position) < TRIGGER_DIST
	if near and state == State.INACTIVE:
		state = State.NEAR_NPC
		_set_dlg("[ E ]  Parla con Huncho")
		if _e_prompt:
			_e_prompt.text = "[ E ]  Parla con Huncho"
			_e_prompt.visible = true
	elif not near and state == State.NEAR_NPC:
		state = State.INACTIVE
		_set_dlg("")
		if _e_prompt:
			_e_prompt.visible = false

func _start_dialogue() -> void:
	state = State.DIALOGUE
	_dialogue_timer = 0.0
	if _e_prompt:
		_e_prompt.visible = false
	_set_dlg("Huncho: \"Porta 'sta roba al bar, frat! Muoviti!\"")
	_set_obj("")

func _begin_mission() -> void:
	state = State.ACTIVE
	_mission_timer = 0.0
	_set_dlg("")
	_set_obj("[ Consegna al Caffè Molinari ]")
	_set_goal_marker(true)

func _complete() -> void:
	state = State.COMPLETE
	_set_goal_marker(false)
	_set_dlg("Hai consegnato! Bella mossa, frat.")
	_set_obj("✓ Missione completata!   +$%d" % REWARD)
	get_tree().create_timer(4.0).timeout.connect(_clear_ui)

func _fail() -> void:
	state = State.FAILED
	_set_goal_marker(false)
	_set_dlg("Huncho: \"Dove eri?! Troppo tardi!\"")
	_set_obj("✗ Missione fallita")
	get_tree().create_timer(4.0).timeout.connect(_retry)

func _set_goal_marker(visible_flag: bool) -> void:
	var markers := get_tree().get_nodes_in_group("goal_marker")
	for m in markers:
		m.visible = visible_flag

func _retry() -> void:
	state = State.INACTIVE
	_mission_timer = 0.0
	_dialogue_timer = 0.0
	_set_obj("")
	_set_dlg("")

func _clear_ui() -> void:
	_set_obj("")
	_set_dlg("")

func _set_obj(text: String) -> void:
	if label_objective:
		label_objective.text = text

func _set_dlg(text: String) -> void:
	if label_dialogue:
		label_dialogue.text = text
