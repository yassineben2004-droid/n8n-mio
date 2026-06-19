extends Node

const COOLDOWN_START  := 10.0
const STAR_DROP_RATE  := 5.0
const POLICE_SPAWN_DIST := 30.0

var _stats: Node = null
var _player: Node3D = null
var _cooldown_timer := 0.0
var _star_drop_timer := 0.0
var _police_nodes: Array = []

func setup(player: Node3D, stats: Node) -> void:
	_player = player
	_stats = stats
	_stats.wanted_changed.connect(_on_wanted_changed)

func on_npc_hit() -> void:
	_cooldown_timer = COOLDOWN_START
	_star_drop_timer = 0.0

func _process(delta: float) -> void:
	if not _stats or _stats.wanted_level == 0:
		return
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		return
	# Nessun danno recente → scendi stelle
	_star_drop_timer += delta
	if _star_drop_timer >= STAR_DROP_RATE:
		_star_drop_timer = 0.0
		_stats.add_wanted(-1)

func _on_wanted_changed(level: int) -> void:
	# Spawn / despawn polizia
	if level >= 2 and _police_nodes.size() == 0:
		_spawn_police(1)
	elif level >= 3 and _police_nodes.size() < 2:
		_spawn_police(1)
	elif level == 0:
		_despawn_all_police()

func _spawn_police(count: int) -> void:
	for i in range(count):
		var angle := randf() * TAU
		var spawn_pos := _player.global_position + Vector3(
			cos(angle) * POLICE_SPAWN_DIST, 0, sin(angle) * POLICE_SPAWN_DIST)
		# Usa main per spawnare NPC poliziotto
		var main := get_tree().current_scene
		if main.has_method("_spawn_npc"):
			var cop = main.call("_spawn_npc", spawn_pos,
				Color(0.15, 0.20, 0.55), "Madama", "")
			if cop:
				cop.set("npc_type", "FIGHTER")
				_police_nodes.append(cop)

func _despawn_all_police() -> void:
	for cop in _police_nodes:
		if is_instance_valid(cop):
			cop.queue_free()
	_police_nodes.clear()
