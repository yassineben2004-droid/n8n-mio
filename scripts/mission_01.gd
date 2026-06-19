extends Node

enum State { INACTIVE, DIALOGUE, ACTIVE, COMPLETE }

const TRIGGER_DIST := 3.5
const GOAL_DIST    := 4.0
const GOAL_POS     := Vector3(-100.0, 0.0, -2.0)  # davanti al bar, non dentro
const REWARD       := 200

var state := State.INACTIVE
var player: Node3D
var huncho: Node3D
var label_objective: Label
var label_dialogue: Label
var _dialogue_timer := 0.0

func setup(p: Node3D, h: Node3D, obj_lbl: Label, dlg_lbl: Label) -> void:
	player = p
	huncho = h
	label_objective = obj_lbl
	label_dialogue = dlg_lbl

func _process(delta: float) -> void:
	if not player:
		return
	match state:
		State.INACTIVE:
			if huncho and player.global_position.distance_to(huncho.global_position) < TRIGGER_DIST:
				_start_dialogue()
		State.DIALOGUE:
			_dialogue_timer += delta
			if _dialogue_timer >= 3.5:
				_begin_mission()
		State.ACTIVE:
			var dist := player.global_position.distance_to(GOAL_POS)
			_set_obj("[ Caffè Molinari — %dm ]" % int(dist))
			if dist < GOAL_DIST:
				_complete()
		State.COMPLETE:
			pass

func _start_dialogue() -> void:
	state = State.DIALOGUE
	_dialogue_timer = 0.0
	_set_dlg("Huncho: \"Porta 'sta roba al bar, frat!\"")
	print("Missione 01: dialogo")

func _begin_mission() -> void:
	state = State.ACTIVE
	_set_dlg("")
	_set_obj("[ Consegna al Caffè Molinari ]")
	print("Missione 01: attiva")

func _complete() -> void:
	state = State.COMPLETE
	_set_dlg("")
	_set_obj("Missione completata!  +$%d" % REWARD)
	print("Missione 01: completata!")
	get_tree().create_timer(4.0).timeout.connect(_clear_ui)

func _clear_ui() -> void:
	_set_obj("")

func _set_obj(text: String) -> void:
	if label_objective:
		label_objective.text = text

func _set_dlg(text: String) -> void:
	if label_dialogue:
		label_dialogue.text = text
