extends CharacterBody2D

## Musuh: berkeliaran, mendeteksi player, mengejar, dan drop orb mana saat mati.

## Graph elemental (Air/Api/Petir). Preload, bukan global class_name, biar
## aman diparse walau cache class_name belum ter-update.
const Elements := preload("res://scripts/element.gd")

@export var max_health := 50.0
@export var move_speed := 130.0
## Radius deteksi player. Di luar ini musuh cuma jalan keliling.
@export var detect_range := 700.0
## Jarak minimum, musuh berhenti di sini biar nempelaben do催化剂.
@export var stop_distance := 40.0
@export var orb_drop_count := 2

## Elemen musuh (lihat scripts/element.gd): AIR / FIRE / LIGHTNING.
## Dipakai buat kalkulasi damage: x2 kalau dibalik attacker, NULL kalau kebal.
@export var element: int = Elements.Type.AIR
## Kalau true, elemen diacak ulang tiap spawn (buat placeholder).
@export var random_element := true

var health: float
var _tween: Tween
var _wander_target := Vector2.ZERO
var _wander_cooldown := 0.0
var _player: Node2D = null
## 1.0 = normal, <1.0 = lebih lambat (efek slow dari skill api).
var _slow_factor := 1.0
var _slow_timer := 0.0


func _ready() -> void:
	health = max_health
	if random_element:
		element = Elements.random_type()
	# Layer 2 = musuh. Mask 1 = cuma nabrak dunia (StaticBody2D),
	# TIDAK nabrak player (player di layer 4, mask 1 nggak nyentuh).
	collision_layer = 2
	collision_mask = 1
	_pick_wander_target()


func _physics_process(delta: float) -> void:
	_player = _find_player()

	if _player and global_position.distance_to(_player.global_position) <= detect_range:
		_chase(delta)
	else:
		_wander(delta)

	_tick_slow(delta)
	queue_redraw()
	move_and_slide()


## Slow ada durasinya, jadi kalau nggak di-refresh akan kedaluwarsa sendiri.
func _tick_slow(delta: float) -> void:
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0


## Elemen musuh, dibaca engine damage buat nentuin x2 / x1 / NULL.
func get_element() -> int:
	return element


## Dipanggil BurnCircle tiap tick selama musuh di dalam lingkaran api.
func apply_slow(factor: float, duration := 0.7) -> void:
	# Ambil yang paling lambat kalau somehow stack.
	_slow_factor = minf(_slow_factor, factor)
	_slow_timer = maxf(_slow_timer, duration)
	# Tint biru biar pemain baca "ini musuh lagi beku".
	modulate = Color(0.6, 0.82, 1.0)


## Dilepas pas musuh keluar dari area api / area mati.
func end_slow() -> void:
	_slow_factor = 1.0
	_slow_timer = 0.0
	if health > 0.0:
		modulate = Color.WHITE


func _find_player() -> Node2D:
	# Cari sekali lalu cache; cari ulang kalau hilang (mis. respawn).
	if is_instance_valid(_player):
		return _player
	for node in get_tree().get_nodes_in_group("player"):
		return node as Node2D
	return null


## Kejar player: jalan lurus ke arahnya, berhenti kalau sudah dekat.
func _chase(delta: float) -> void:
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var speed := move_speed * _slow_factor

	if dist <= stop_distance:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 4.0 * delta)
	else:
		velocity = velocity.move_toward(to_player.normalized() * speed, speed * 4.0 * delta)


## Jalan keliling kalau player jauh: pindah target acak sesekali.
func _wander(delta: float) -> void:
	_wander_cooldown -= delta
	if _wander_cooldown <= 0.0:
		_pick_wander_target()

	var to_target := _wander_target - global_position
	var speed := move_speed * 0.5 * _slow_factor
	if to_target.length() < 20.0:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 2.0 * delta)
	else:
		velocity = velocity.move_toward(to_target.normalized() * speed, speed * 2.0 * delta)


func _pick_wander_target() -> void:
	_wander_cooldown = randf_range(1.5, 3.5)
	_wander_target = global_position + Vector2.from_angle(randf() * TAU) * randf_range(80.0, 220.0)


func take_damage(amount: float, source: Node = null) -> void:
	if health <= 0.0:
		return
	health -= amount
	_flash_burn()
	queue_redraw()
	if health <= 0.0:
		_die()


func _die() -> void:
	_drop_orbs()
	queue_free()


## Lempar orb mana ke sekitar posisi musuh, tiap orb dapat arah random.
func _drop_orbs() -> void:
	const OrbScene := preload("res://scenes/orb.tscn")
	var world := get_tree().current_scene
	if world == null:
		return

	for i in range(orb_drop_count):
		var orb := OrbScene.instantiate()
		orb.global_position = global_position
		# Kasih velocity awal biar melompat kecil ke segala arah.
		orb.set("launch_velocity", Vector2.from_angle(randf() * TAU) * randf_range(120.0, 220.0))
		world.add_child(orb)


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
	# Badge elemen: kotak warna + nama, biar jelas saat testing.
	var ecol: Color = Elements.color_of(element)
	draw_rect(Rect2(-28.0, -136.0, 56.0, 20.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-26.0, -134.0, 52.0, 16.0), ecol)
	var font: Font = ThemeDB.fallback_font
	if font:
		var ename: String = Elements.name_of(element)
		var tw: float = font.get_string_size(ename, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(-tw * 0.5, -121.0), ename,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.1))

	# Penanda "sadar player" saat sedang mengejar.
	if _player and global_position.distance_to(_player.global_position) <= detect_range:
		draw_circle(Vector2(0, -104), 4.0, Color(1.0, 0.9, 0.3, 0.9))

	# Indikator efek slow: cincin biru beku + kilatan di sekitar badan.
	if _slow_factor < 1.0:
		draw_arc(Vector2(0, -50), 78.0, 0.0, TAU, 40, Color(0.5, 0.85, 1.0, 0.85), 3.0)
		draw_arc(Vector2(0, -50), 66.0, 0.0, TAU, 40, Color(0.7, 0.95, 1.0, 0.5), 2.0)
