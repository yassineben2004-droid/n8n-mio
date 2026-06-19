extends Node

# Missione 03 — Consegna Urgente
# Trigger: Behope su Viale Pavia (x=-45, z=-2)
# Stage 1: ritira il pacco al Garage (x=62, z=56)
# Stage 2: consegna al Sottoponte (x=-52, z=56)
# Timer: 120 secondi — Reward: €450

enum State { INACTIVE, NEAR_BEHOPE, DIALOGUE, STAGE1_GO_GARAGE, STAGE2_GO_SOTTOPONTE, COMPLETE, FAILED }

const TRIGGER_DIST    := 3.5
const PICKUP_POS      := Vector3(62.0, 0.0, 56.0)
const DELIVERY_POS    := Vector3(-52.0, 0.0, 56.0)
const GOAL_RADIUS     := 5.0
const TIMER_MAX       := 120.0
const REWARD          := 450

var state := State.INACTIVE
var player: Node3D
var behope: Node3D
var label_objective: Label
var label_dialogue: Label
var _e_prompt: Label
var _dialogue_timer := 0.0
var _mission_timer  := 0.0
var _marker_pickup: Node3D   = null
var _marker_delivery: Node3D = null

func setup(p: Node3D, behope_npc: Node3D, obj_lbl: Label, dlg_lbl: Label) -> void:
	player  = p
	behope  = behope_npc
	label_objective = obj_lbl
	label_dialogue  = dlg_lbl
	_e_prompt = Label.new()
	_e_prompt.anchor_left   = 0.5; _e_prompt.anchor_right  = 0.5
	_e_prompt.anchor_top    = 0.5; _e_prompt.anchor_bottom = 0.5
	_e_prompt.offset_left   = -150.0; _e_prompt.offset_right  = 150.0
	_e_prompt.offset_top    = 90.0;   _e_prompt.offset_bottom = 120.0
	_e_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_e_prompt.add_theme_font_size_override("font_size", 18)
	_e_prompt.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 0.95))
	_e_prompt.visible = false
	var ui := get_parent().get_node_or_null("UI")
	if ui:
		ui.add_child(_e_prompt)

func _ready() -> void:
	_build_marker(PICKUP_POS, Color(0.0, 0.8, 1.0), "M03Pickup")
	_build_marker(DELIVERY_POS, Color(0.0, 1.0, 0.4), "M03Delivery")

func _build_marker(pos: Vector3, color: Color, group: String) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var root := Node3D.new()
	root.name = group
	root.add_to_group(group)
	root.visible = false
	var disc := CylinderMesh.new()
	disc.top_radius = 2.0; disc.bottom_radius = 2.0; disc.height = 0.08
	disc.material = mat
	var disc_mi := MeshInstance3D.new()
	disc_mi.mesh = disc; disc_mi.position = Vector3(0, 0.05, 0)
	root.add_child(disc_mi)
	var beam := CylinderMesh.new()
	beam.top_radius = 0.22; beam.bottom_radius = 0.22; beam.height = 8.0
	beam.material = mat
	var beam_mi := MeshInstance3D.new()
	beam_mi.mesh = beam; beam_mi.position = Vector3(0, 4.0, 0)
	root.add_child(beam_mi)
	root.position = pos
	get_tree().current_scene.add_child(root)
	return root

func _process(delta: float) -> void:
	if not player:
		return
	match state:
		State.INACTIVE:
			_check_behope_proximity()
		State.NEAR_BEHOPE:
			_check_behope_proximity()
			if Input.is_key_pressed(KEY_E):
				_start_dialogue()
		State.DIALOGUE:
			_dialogue_timer += delta
			if _dialogue_timer >= 3.5:
				_begin_stage1()
		State.STAGE1_GO_GARAGE:
			_mission_timer += delta
			var remaining := TIMER_MAX - _mission_timer
			var dist := player.global_position.distance_to(PICKUP_POS)
			_set_obj("[ Garage — %dm ]   Tempo: %ds" % [int(dist), int(remaining)])
			if remaining <= 0.0:
				_fail()
			elif dist < GOAL_RADIUS:
				_begin_stage2()
		State.STAGE2_GO_SOTTOPONTE:
			_mission_timer += delta
			var remaining := TIMER_MAX - _mission_timer
			var dist := player.global_position.distance_to(DELIVERY_POS)
			_set_obj("[ Sottoponte — %dm ]   Tempo: %ds" % [int(dist), int(remaining)])
			if remaining <= 0.0:
				_fail()
			elif dist < GOAL_RADIUS:
				_complete()
		State.FAILED, State.COMPLETE:
			pass

func _check_behope_proximity() -> void:
	if not behope:
		return
	var near := player.global_position.distance_to(behope.global_position) < TRIGGER_DIST
	if near and state == State.INACTIVE:
		state = State.NEAR_BEHOPE
		_set_dlg("[ E ]  Parla con Behope")
		if _e_prompt:
			_e_prompt.text = "[ E ]  Parla con Behope"
			_e_prompt.visible = true
	elif not near and state == State.NEAR_BEHOPE:
		state = State.INACTIVE
		_set_dlg("")
		if _e_prompt:
			_e_prompt.visible = false

func _start_dialogue() -> void:
	state = State.DIALOGUE
	_dialogue_timer = 0.0
	if _e_prompt:
		_e_prompt.visible = false
	_set_dlg("Behope: \"Frat serve un favore — ritira il pacco al garage e portalo sotto al ponte!\"")

func _begin_stage1() -> void:
	state = State.STAGE1_GO_GARAGE
	_set_dlg("")
	_set_obj("[ Ritira al Garage ]")
	_set_marker_visible("M03Pickup", true)
	_set_marker_visible("M03Delivery", false)

func _begin_stage2() -> void:
	state = State.STAGE2_GO_SOTTOPONTE
	_set_dlg("Pacco preso! Portalo al Sottoponte.")
	_set_obj("[ Consegna al Sottoponte ]")
	_set_marker_visible("M03Pickup", false)
	_set_marker_visible("M03Delivery", true)
	get_tree().create_timer(2.5).timeout.connect(func(): _set_dlg(""))

func _complete() -> void:
	state = State.COMPLETE
	_set_marker_visible("M03Pickup", false)
	_set_marker_visible("M03Delivery", false)
	_set_dlg("Behope: \"Sei il migliore frat! Tieni.\"")
	_set_obj("Consegna completata!   +E%d" % REWARD)
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats:
		stats.add_money(REWARD)
	get_tree().create_timer(4.0).timeout.connect(_clear_ui)

func _fail() -> void:
	state = State.FAILED
	_set_marker_visible("M03Pickup", false)
	_set_marker_visible("M03Delivery", false)
	_set_obj("Missione fallita — troppo tardi!")
	_set_dlg("Behope: \"Cazzo frat, troppo lento!\"")
	get_tree().create_timer(4.0).timeout.connect(_retry)

func _retry() -> void:
	state = State.INACTIVE
	_mission_timer = 0.0
	_dialogue_timer = 0.0
	_set_obj("")
	_set_dlg("")

func _clear_ui() -> void:
	_set_obj("")
	_set_dlg("")

func _set_marker_visible(group: String, vis: bool) -> void:
	for m in get_tree().get_nodes_in_group(group):
		m.visible = vis

func _set_obj(text: String) -> void:
	if label_objective:
		label_objective.text = text

func _set_dlg(text: String) -> void:
	if label_dialogue:
		label_dialogue.text = text
