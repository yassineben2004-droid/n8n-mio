extends Node

const PLAYER_TRIGGER_DIST := 4.0
const NPC_PAIR_DIST        := 3.0
const PLAYER_COOLDOWN      := 8.0
const PAIR_INTERVAL        := 6.0
const LABEL_DURATION       := 3.0

var _player: Node3D = null
var _npc_cooldowns: Dictionary = {}
var _pair_timer := 0.0

var NPC_LINES := {
	"Huncho":   ["Ue frat, tutto ok?", "Sei pronto per stasera?", "Non fare il coglione eh", "Ue sugo che si dice"],
	"Chakour":  ["Bro che fai in giro?", "Stai attento alla madama", "Vieni al campetto dopo?", "Tutto ok?"],
	"Behope":   ["Tutto apposto?", "Hai visto Mimmo?", "Stasera si esce frat", "Bella giornata bro"],
	"Peco":     ["Ue!", "Che si dice?", "Tutto a posto frat", "Stai bene?"],
	"default":  ["Ciao", "Bella giornata eh", "Lasciami stare", "Mmh"]
}

var PAIR_CONVOS := [
	["Hai sentito di ieri sera?", "Sì bro, situazione pesante", "Stasera ci becchiamo giù"],
	["Che fai stanotte?", "Niente di speciale frat", "Vieni giù allora"],
	["Hai visto il nuovo ragazzo?", "Quale? Quello di via Colombo?", "Sì sì quello lì"],
	["Freddo stasera eh", "Sempre così da queste parti", "Almeno c'è il campetto"],
]

func setup(player: Node3D) -> void:
	_player = player

func _process(delta: float) -> void:
	if not _player:
		return
	_check_player_proximity()
	_pair_timer += delta
	if _pair_timer >= PAIR_INTERVAL:
		_pair_timer = 0.0
		_check_npc_pairs()
	# Aggiorna cooldown
	var to_remove := []
	for npc_name in _npc_cooldowns:
		_npc_cooldowns[npc_name] -= delta
		if _npc_cooldowns[npc_name] <= 0.0:
			to_remove.append(npc_name)
	for k in to_remove:
		_npc_cooldowns.erase(k)

func _check_player_proximity() -> void:
	for npc in get_tree().get_nodes_in_group("npc"):
		var dist := _player.global_position.distance_to(npc.global_position)
		if dist > PLAYER_TRIGGER_DIST:
			continue
		var npc_name: String = npc.get("npc_name") if npc.get("npc_name") else "default"
		if npc_name in _npc_cooldowns:
			continue
		var lines: Array = NPC_LINES.get(npc_name, NPC_LINES["default"])
		var line: String = lines[randi() % lines.size()]
		_show_label(npc, "%s: \"%s\"" % [npc_name, line], LABEL_DURATION)
		_npc_cooldowns[npc_name] = PLAYER_COOLDOWN

func _check_npc_pairs() -> void:
	var npcs := get_tree().get_nodes_in_group("npc")
	for i in range(npcs.size()):
		for j in range(i + 1, npcs.size()):
			var a: Node3D = npcs[i]
			var b: Node3D = npcs[j]
			if a.global_position.distance_to(b.global_position) < NPC_PAIR_DIST:
				_start_pair_convo(a, b)
				return  # Una coppia per volta

func _start_pair_convo(a: Node3D, b: Node3D) -> void:
	var convo: Array = PAIR_CONVOS[randi() % PAIR_CONVOS.size()]
	var delay := 0.0
	for ci in range(convo.size()):
		var speaker: Node3D = a if ci % 2 == 0 else b
		var line: String = convo[ci]
		var t := get_tree().create_timer(delay)
		t.timeout.connect(func(): _show_label(speaker, line, LABEL_DURATION))
		delay += LABEL_DURATION + 0.4

func _show_label(npc: Node3D, text: String, duration: float) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 42
	lbl.modulate = Color(1, 1, 1, 0)
	lbl.outline_size = 6
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = npc.global_position + Vector3(0, 2.4, 0)
	get_tree().current_scene.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.3)
	tw.tween_interval(duration - 0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lbl.queue_free)
