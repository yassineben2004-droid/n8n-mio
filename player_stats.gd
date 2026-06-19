extends Node

signal hp_changed(new_hp: int)
signal money_changed(new_money: int)
signal wanted_changed(new_level: int)

var hp: int = 100
var money: int = 0
var wanted_level: int = 0

func take_damage(amount: int) -> void:
	hp = clamp(hp - amount, 0, 100)
	hp_changed.emit(hp)
	if hp <= 0:
		_on_death()

func heal(amount: int) -> void:
	hp = clamp(hp + amount, 0, 100)
	hp_changed.emit(hp)

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func set_wanted(level: int) -> void:
	wanted_level = clamp(level, 0, 5)
	wanted_changed.emit(wanted_level)

func add_wanted(delta: int) -> void:
	set_wanted(wanted_level + delta)

func _on_death() -> void:
	print("GAME OVER")
	# Respawn semplice: torna posizione iniziale con HP piena
	hp = 100
	hp_changed.emit(hp)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = Vector3(-40, 1.0, 0)
