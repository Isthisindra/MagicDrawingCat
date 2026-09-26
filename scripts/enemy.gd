extends CharacterBody2D

## Musuh dummy untuk tes skill api. Punya take_damage() agar bisa kena DoT.

@export var max_health := 50.0

var health: float
var _tween: Tween


func _ready() -> void:
	health = max_health


func _physics_process(_delta: float) -> void:
	# Dummy: diem di tempat.
	velocity = Vector2.ZERO
	move_and_slide()


func take_damage(amount: float, source: Node = null) -> void:
	if health <= 0.0:
		return
	health -= amount
	_flash_burn()
	queue_redraw()
	if health <= 0.0:
		queue_free()


func _flash_burn() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	modulate = Color(1.0, 0.4, 0.2)
	_tween = create_tween()
	_tween.tween_property(self, "modulate", Color.WHITE, 0.25)


func _draw() -> void:
	# Bar HP kecil di atas kepala.
	var w := 60.0
	draw_rect(Rect2(-w / 2.0, -90.0, w, 8.0), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-w / 2.0, -90.0, w * health / max_health, 8.0), Color(0.9, 0.2, 0.15))
