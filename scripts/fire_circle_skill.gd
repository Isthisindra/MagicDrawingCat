class_name FireCircleSkill
extends Node2D

## Skill API AoE: tekan tombol -> muncul lingkaran api di posisi player
## yang membakar musuh di dalamnya (DoT).

@export var cooldown := 2.0
## Aksi input yang memicu skill.
@export var action := "ui_accept"

const BurnCircleScript := preload("res://scripts/burn_circle.gd")

var _cooldown_left := 0.0


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if Input.is_action_just_pressed(action) and _cooldown_left <= 0.0:
		_cast()
		_cooldown_left = cooldown


func _cast() -> void:
	# Parent ke dunia (bukan player) supaya lingkaran diam di tempat saat di-cast.
	var world := get_tree().current_scene

	var circle := Area2D.new()
	circle.set_script(BurnCircleScript)
	circle.global_position = global_position
	circle.name = "BurnCircle"
	world.add_child(circle)
