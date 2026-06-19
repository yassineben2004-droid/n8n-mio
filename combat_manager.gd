extends Node

const HIT_RADIUS    := 2.5
const DMG_SINGLE    := 25
const DMG_COMBO     := 45
const COMBO_WINDOW  := 0.4
const MONEY_DROP    := 15

var _player: Node3D = null
var _stats: Node = null
var _last_punch_time := 0.0
var _combo_count := 0

var FIGHTER_INSULTS := [
	"Sei morto!", "Vaffanculo!", "Ti spacco!",
	"Hai rotto i coglioni!", "Adesso ti sistemo io!", "Vieni qui figlio di..."
]
var CIVILIAN_INSULTS := [
	"Aiuto!", "Che cavolo fai?!", "Chiamo la madama!",
	"Sei scemo?!", "Ma sei matto?!", "Lasciami stare!"
]

func setup(player: Node3D, stats: Node) -> void:
	_player = player
	_stats = stats

func on_player_punch() -> void:
	if not _player:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var is_combo := (now - _last_punch_time) < COMBO_WINDOW and _combo_count > 0
	_last_punch_time = now
	_combo_count = (_combo_count + 1) if is_combo else 1

	var dmg := DMG_COMBO if is_combo else DMG_SINGLE
	var hit_npc := _find_npc_in_range()
	if hit_npc:
		_apply_hit(hit_npc, dmg, is_combo)

func _find_npc_in_range() -> Node3D:
	var origin: Vector3 = _player.global_position + Vector3(0, 0.9, 0)
	var best: Node3D = null
	var best_dist := HIT_RADIUS
	for npc in get_tree().get_nodes_in_group("npc"):
		var dist: float = origin.distance_to(npc.global_position)
		if dist < best_dist:
			best_dist = dist
			best = npc
	return best

func _apply_hit(npc: Node3D, dmg: int, is_combo: bool) -> void:
	if not npc.has_method("take_hit"):
		return
	npc.call("take_hit", dmg, is_combo)
	# Wanted: solo se è un civile (non fighter dei nostri)
	var npc_type: String = npc.get("npc_type") if npc.get("npc_type") != null else "CIVILIAN"
	if npc_type == "CIVILIAN" and _stats:
		_stats.add_wanted(1)
	# Money drop se FIGHTER e morto
	var npc_hp: int = npc.get("npc_hp") if npc.get("npc_hp") != null else 60
	if npc_type == "FIGHTER" and npc_hp <= 0 and _stats:
		_stats.add_money(MONEY_DROP)
		_show_money_popup(npc.global_position)

func _show_money_popup(pos: Vector3) -> void:
	var lbl := Label3D.new()
	lbl.text = "+€%d" % MONEY_DROP
	lbl.modulate = Color(1.0, 0.92, 0.1)
	lbl.font_size = 48
	lbl.position = pos + Vector3(0, 2.2, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	get_tree().current_scene.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", pos.y + 3.5, 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)
