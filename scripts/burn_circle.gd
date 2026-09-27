class_name BurnCircle
extends Area2D

## Lingkaran api: membakar semua musuh di dalamnya (DoT per tick).

## Graph elemental (Air/Api/Petir). Pakai preload, bukan global class_name,
## biar script ini bisa diparse walau cache class_name belum ter-update.
const Elements := preload("res://scripts/element.gd")

@export var radius := 150.0
@export var burn_damage_per_tick := 5.0
@export var tick_interval := 0.5
@export var lifetime := 3.0
## Efek slow: 0.45 = musuh bergerak cuma 45% dari kecepatan normal.
## Set 1.0 untuk mematikan efek slow.
@export var slow_factor := 0.45
## Berapa lama slow nempel tiap di-refresh (detik).
@export var slow_refresh_duration := 0.7
## Elemen skill ini (dipakai buat kalkulasi x2 / NULL vs elemen musuh).
@export var element: int = Elements.Type.FIRE

# --- Visual magic circle (rune berputar) ---
## Kecepatan putar cincin luar (rad/detik). Negatif = berlawanan arah jam.
@export var spin_speed := 1.2
## Kecepatan putar cincin dalam (default berlawanan arah biar kaya).
@export var inner_spin_speed := -0.8
## Besar denyut skala cincin (0.04 = ±4%).
@export var pulse_amount := 0.04
## Kecepatan denyut.
@export var pulse_speed := 2.0
## OPSIONAL: gambar magic circle (png). Kalau diisi, cincin Line2D
## disembunyikan dan texture ini yang dipakai (tetap ikut berputar).
@export var ring_texture: Texture2D
## Skala texture magic circle supaya pas sama radius.
@export var ring_texture_scale := 1.0

var _age := 0.0
var _tick_accum := 0.0
## Musuh yang lagi dikasih slow, biar bisa dilepas pas keluar area.
var _slowed: Array[Node2D] = []

var _rings: Node2D
var _outer: Node2D
var _inner: Node2D
var _pulse_time := 0.0


func _ready() -> void:
	# Shape lingkaran dibuat lewat kode biar scene tetap simpel.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

	# Layer 1 = area ini. Mask 1|2 = deteksi dunia (1) + musuh (2).
	# Musuh di-set layer 2 di enemy.gd, makanya mask harus 3.
	collision_layer = 1
	collision_mask = 1 | 2
	monitoring = true

	# Pop-in kecil biar terasa "mekar".
	scale = Vector2.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_setup_rings()
	_setup_flames()
	_setup_spawn_burst()
	_setup_smoke()
	_setup_chill()

	# Mati sendiri setelah lifetime habis, dengan fade-out.
	var fade := get_tree().create_timer(lifetime - 0.3)
	fade.timeout.connect(func() -> void:
		_release_slows()
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.3)
		t.tween_callback(queue_free)
	)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		return

	# DoT + slow: setiap tick_interval, bakar + perlambat semua yang di dalam.
	_tick_accum += delta
	if _tick_accum >= tick_interval:
		_tick_accum = 0.0
		_tick_damage_and_slow()

	_spin_rings(delta)


## Putar magic circle. Cuma node visual yang muter, Area2D + partikel tetap
## diam di tempat (biar DoT & partikel nggak ikut "berganti arah").
## Dijalanin di _physics_process (bukan _process) karena project ini pakai
## physics interpolation -> transform yang diupdate tiap frame physics
## tetap mulus di render.
func _spin_rings(delta: float) -> void:
	if _rings == null:
		return

	_outer.rotation += spin_speed * delta
	_inner.rotation += inner_spin_speed * delta

	# Denyut: luar mengembang, dalam menyempit (efek bernapas).
	_pulse_time += delta
	var pulse := 1.0 + sin(_pulse_time * pulse_speed) * pulse_amount
	_outer.scale = Vector2.ONE * pulse
	_inner.scale = Vector2.ONE * (2.0 - pulse)


func _tick_damage_and_slow() -> void:
	var inside: Array[Node2D] = []

	for body in get_overlapping_bodies():
		var b := body as Node2D
		if b == null:
			continue

		# Kalkulasi elemental: x2 kalau counter, x1 kalau sama, NULL kalau
		# element-nya kebal (reverse dari siklus).
		var mult := 1.0
		if b.has_method("get_element"):
			mult = Elements.get_multiplier(element, b.get_element())
		var dmg := burn_damage_per_tick * mult

		# NULL = kebal: nggak kena damage, nggak kena slow, tapi tetep kelihatan
		# "NULL" biar player ngerti kenapa gak ada damage.
		if mult > 0.0:
			# Kompatibel dengan musuh apa pun yang punya take_damage().
			if b.has_method("take_damage"):
				b.take_damage(dmg, self)

			# Efek slow (nempel selama masih di dalam lingkaran).
			if slow_factor < 1.0 and b.has_method("apply_slow"):
				b.apply_slow(slow_factor, slow_refresh_duration)
				inside.append(b)

		_spawn_damage_text(dmg, mult, b)

	# Musuh yang udah keluar area -> lepas slow-nya.
	for b in _slowed:
		if b != null and not inside.has(b) and b.has_method("end_slow"):
			b.end_slow()
	_slowed = inside


## Angka damage melayang biar keliatan efek x2 / NULL dari elemental.
func _spawn_damage_text(amount: float, mult: float, target: Node2D) -> void:
	var world := get_tree().current_scene
	if world == null or target == null:
		return

	var defender: int = element
	if target.has_method("get_element"):
		defender = target.get_element()

	var text := "NULL"
	var color := Color(0.65, 0.65, 0.65)
	if mult > 0.0:
		text = str(int(round(amount)))
		if mult >= Elements.strong_multiplier:
			color = Color(1.0, 0.85, 0.25)  # gold = kena weakness (x2)
		else:
			color = Color.WHITE
	text += " (%s)" % str(Elements.get_relation(element, defender))

	var label := Label.new()
	label.text = text
	label.z_index = 100
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	label.position = target.global_position + Vector2(randf_range(-16.0, 16.0), -80.0)
	world.add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _draw() -> void:
	# Isi api transluen + garis tepi menyala + inti lebih terang.
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.05, 0.18))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.55, 0.1, 0.9), 4.0)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 0.7, 0.2, 0.25))


func _setup_rings() -> void:
	## Siapkan 2 lapis cincin rune: luar clockwise, dalam counter-clockwise.
	_rings = get_node_or_null("Rings")
	if _rings == null:
		_rings = Node2D.new()
		_rings.name = "Rings"
		add_child(_rings)

	_outer = get_node_or_null("Rings/OuterRing")
	if _outer == null:
		_outer = Line2D.new()
		_outer.name = "OuterRing"
		_rings.add_child(_outer)

	_inner = get_node_or_null("Rings/InnerRing")
	if _inner == null:
		_inner = Line2D.new()
		_inner.name = "InnerRing"
		_rings.add_child(_inner)

	if ring_texture != null:
		# Pakai gambar magic circle -> Line2D disembunyiin.
		_outer.visible = false
		_inner.visible = false
		var tex_outer := Sprite2D.new()
		tex_outer.texture = ring_texture
		tex_outer.scale = Vector2.ONE * ring_texture_scale
		tex_outer.modulate = Color(1.0, 0.7, 0.3, 1.0)
		_rings.add_child(tex_outer)
		_outer = tex_outer

		var tex_inner := Sprite2D.new()
		tex_inner.texture = ring_texture
		# Kecil + lebih terang biar ada kedalaman.
		tex_inner.scale = Vector2.ONE * ring_texture_scale * 0.6
		tex_inner.modulate = Color(1.0, 0.9, 0.5, 1.0)
		_rings.add_child(tex_inner)
		_inner = tex_inner
	else:
		_style_ring(_outer, radius, 6.0, Color(1.0, 0.6, 0.15, 0.95))
		_style_ring(_inner, radius * 0.72, 3.0, Color(1.0, 0.85, 0.35, 0.8))


## Bikin satu cincin: radius, lebar, warna, + tick rune biar berasa "sihir".
func _style_ring(node: Node2D, r: float, width: float, color: Color) -> void:
	var line := node as Line2D
	if line == null:
		return
	line.points = _circle_points(r, 72)
	line.width = width
	line.default_color = color
	line.antialiased = true

	# Tick rune: garis pendek radial tiap 30 derajat, cuma di cincin luar.
	if line.get_child_count() > 0:
		return
	if r >= radius * 0.9:
		for i in range(12):
			var a := TAU * i / 12.0
			var dir := Vector2(cos(a), sin(a))
			var tick := Line2D.new()
			tick.points = PackedVector2Array([dir * r * 0.93, dir * r * 1.06])
			tick.width = width * 0.6
			tick.default_color = Color(1.0, 0.8, 0.3, 0.7)
			tick.antialiased = true
			line.add_child(tick)


## Titik-titik lingkaran (72 segmen udah cukup bulat & murah).
func _circle_points(r: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		var a := TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _setup_flames() -> void:
	## Api kecil yang terus menyala sepanjang umur lingkaran.
	var fire := CPUParticles2D.new()
	fire.name = "Flames"
	fire.amount = 60
	fire.lifetime = 0.7
	fire.local_coords = false

	# Muncul di seluruh luas lingkaran, bergerak naik.
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = radius * 0.9
	fire.direction = Vector2(0, -1)
	fire.spread = 15.0
	fire.initial_velocity_min = 40.0
	fire.initial_velocity_max = 120.0
	fire.gravity = Vector2(0, -30)  # ditarik ke atas, khas api
	fire.scale_amount_min = 2.0
	fire.scale_amount_max = 5.0
	fire.scale_amount_curve = _make_fade_curve()

	# Warna: kuning terang -> oranye -> merah pudar habis.
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.4, 0.9))
	grad.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	fire.color_ramp = grad

	add_child(fire)


func _setup_spawn_burst() -> void:
	## Semburan besar sekali saat lingkaran di-cast.
	var burst := CPUParticles2D.new()
	burst.name = "SpawnBurst"
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 40
	burst.lifetime = 0.5
	burst.local_coords = false

	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = radius * 0.3
	burst.direction = Vector2(0, -1)
	burst.spread = 60.0
	burst.initial_velocity_min = 250.0
	burst.initial_velocity_max = 450.0
	burst.gravity = Vector2(0, 900)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	grad.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	burst.color_ramp = grad

	add_child(burst)
	burst.emitting = true


func _setup_smoke() -> void:
	## Asap tipis yang muncul menjelang lingkaran padam.
	var smoke := CPUParticles2D.new()
	smoke.name = "Smoke"
	smoke.amount = 25
	smoke.lifetime = 1.5
	smoke.local_coords = false
	smoke.emitting = false

	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = radius * 0.7
	smoke.direction = Vector2(0, -1)
	smoke.spread = 20.0
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 60.0
	smoke.gravity = Vector2(0, -15)
	smoke.scale_amount_min = 6.0
	smoke.scale_amount_max = 10.0
	smoke.scale_amount_curve = _make_fade_curve()

	var grad := Gradient.new()
	grad.set_color(0, Color(0.35, 0.35, 0.35, 0.35))
	grad.set_color(1, Color(0.35, 0.35, 0.35, 0.0))
	smoke.color_ramp = grad

	add_child(smoke)

	# Nyalakan asap saat api mulai fade-out (0.3 detik terakhir).
	get_tree().create_timer(lifetime - 0.4).timeout.connect(func() -> void:
		smoke.emitting = true
	)


func _setup_chill() -> void:
	## Per/partikel "dingin" (biru) yang menandakan efek slow aktif.
	var chill := CPUParticles2D.new()
	chill.name = "Chill"
	chill.amount = 20
	chill.lifetime = 0.8
	chill.local_coords = false
	chill.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	chill.emission_sphere_radius = radius * 0.8
	chill.direction = Vector2(0, -1)
	chill.spread = 20.0
	chill.initial_velocity_min = 10.0
	chill.initial_velocity_max = 40.0
	chill.gravity = Vector2(0, 20)
	chill.scale_amount_min = 1.5
	chill.scale_amount_max = 3.5
	chill.scale_amount_curve = _make_fade_curve()

	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.85, 1.0, 0.7))
	grad.set_color(1, Color(0.3, 0.6, 1.0, 0.0))
	chill.color_ramp = grad

	add_child(chill)


## Lepas efek slow dari semua musuh (dipakai pas lingkaran mati).
func _release_slows() -> void:
	for b in _slowed:
		if b != null and b.has_method("end_slow"):
			b.end_slow()
	_slowed.clear()


func _make_fade_curve() -> Curve:
	## Skala partikel: mulai kecil, membesar sedikit, lalu mengecil habis.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
