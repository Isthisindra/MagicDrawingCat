class_name ManaOrb
extends Area2D

## Orb mana yang di-drop musuh. Melompat kecil di tempat, lalu tertarik
## (magnet) ke player dan otomatis nambah mana begitu kena.

@export var mana_amount := 15.0
## Jarak di mana orb mulai tertarik ke player.
@export var magnet_range := 160.0
@export var pull_speed := 520.0
## OPSIONAL: gambar orb. Kalau diisi, pakai Sprite2D; kalau kosong,
## fallback ke bulatan yang digambar lewat kode.
@export var orb_texture: Texture2D
## Skala texture orb (default diameter ~32px).
@export var orb_texture_scale := 1.0
## Besaran + kecepatan efek ngambang naik-turun.
@export var hover_amplitude := 6.0
@export var hover_speed := 3.0
## Kecepatan putar visual.
@export var spin_speed := 2.0
## Kecepatan awal saat terlempar (di-set musuh saat drop).
var launch_velocity := Vector2.ZERO

var _player: Node2D = null
var _time := 0.0
var _visual: Node2D
var _collected := false
## Velocity manual (Area2D gak punya velocity bawaan).
var _velocity := Vector2.ZERO


func _ready() -> void:
	# Magnet pakai cek jarak, jadi layer/mask dimatikan.
	collision_layer = 0
	collision_mask = 0

	_velocity = launch_velocity
	scale = Vector2.ZERO

	# Efek visual dipisah ke node anak supaya gerak fisika (lompat)
	# tidak ketimpa efek ngambang.
	_visual = get_node_or_null("Visual")
	if _visual == null:
		_visual = Node2D.new()
		_visual.name = "Visual"
		add_child(_visual)

	# Kalau ada asset orb, pakai Sprite2D; kalau tidak, andalkan _draw().
	if orb_texture != null:
		var sprite := Sprite2D.new()
		sprite.name = "OrbSprite"
		sprite.texture = orb_texture
		sprite.scale = Vector2.ONE * orb_texture_scale
		_visual.add_child(sprite)

	# Pop-in gitu biar ada impact.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_setup_particles()


func _physics_process(delta: float) -> void:
	if _collected:
		return

	_time += delta

	# Ngambang naik-turun + muter pelan (visual, bukan fisika).
	_visual.position.y = sin(_time * hover_speed) * hover_amplitude
	_visual.rotation += delta * spin_speed

	# Kecepatan awal طرح bungkus (biar berhenti, nggak ng indefinite fly).
	_velocity = _velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	var player := _find_player()

	if player:
		var to_player := player.global_position - global_position
		var dist := to_player.length()
		# Magnet: makin dekat, makin ngaruk.
		if dist < magnet_range:
			var strength := pull_speed * (1.0 - dist / magnet_range + 0.35)
			_velocity = _velocity.move_toward(to_player.normalized() * strength, pull_speed * 5.0 * delta)
		if dist < 26.0:
			_collect(player)

	global_position += _velocity * delta


func _find_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("player"):
		return node as Node2D
	return null


func _collect(player: Node2D) -> void:
	if _collected:
		return
	_collected = true

	# Mana masuk ke player kalau punya collect_orb().
	if player.has_method("collect_orb"):
		player.collect_orb(mana_amount)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free)


func _setup_particles() -> void:
	## Kilau halus yang menempel di orb.
	var glow := CPUParticles2D.new()
	glow.name = "Glow"
	glow.amount = 12
	glow.lifetime = 0.6
	glow.local_coords = false
	glow.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	glow.emission_sphere_radius = 8.0
	glow.direction = Vector2(0, -1)
	glow.spread = 25.0
	glow.initial_velocity_min = 8.0
	glow.initial_velocity_max = 24.0
	glow.gravity = Vector2(0, -10)
	glow.scale_amount_min = 1.5
	glow.scale_amount_max = 3.0

	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.9, 1.0, 0.9))
	grad.set_color(1, Color(0.4, 0.7, 1.0, 0.0))
	glow.color_ramp = grad
	_visual.add_child(glow)


func _draw() -> void:
	# Fallback kalau orb_texture kosong: bulatan cyan glowing + inti putih.
	if orb_texture != null:
		return
	draw_circle(Vector2.ZERO, 16.0, Color(0.3, 0.7, 1.0, 0.25))
	draw_circle(Vector2.ZERO, 9.0, Color(0.4, 0.8, 1.0, 0.9))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 1.0, 0.95))
