class_name BurnCircle
extends Area2D

## Lingkaran api: membakar semua musuh di dalamnya (DoT per tick).

@export var radius := 150.0
@export var burn_damage_per_tick := 5.0
@export var tick_interval := 0.5
@export var lifetime := 3.0

var _age := 0.0
var _tick_accum := 0.0


func _ready() -> void:
	# Shape lingkaran dibuat lewat kode biar scene tetap simpel.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

	# Layer 1 = default; musuh harus ada di layer ini.
	collision_layer = 1
	collision_mask = 1
	monitoring = true

	# Pop-in kecil biar terasa "mekar".
	scale = Vector2.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_setup_flames()
	_setup_spawn_burst()
	_setup_smoke()

	# Mati sendiri setelah lifetime habis, dengan fade-out.
	var fade := get_tree().create_timer(lifetime - 0.3)
	fade.timeout.connect(func() -> void:
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.3)
		t.tween_callback(queue_free)
	)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		return

	# DoT: setiap tick_interval, bakar semua body di dalam lingkaran.
	_tick_accum += delta
	if _tick_accum >= tick_interval:
		_tick_accum = 0.0
		for body in get_overlapping_bodies():
			# Kompatibel dengan musuh apa pun yang punya take_damage().
			if body.has_method("take_damage"):
				body.take_damage(burn_damage_per_tick, self)


func _draw() -> void:
	# Isi api transluen + garis tepi menyala + inti lebih terang.
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.05, 0.18))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.55, 0.1, 0.9), 4.0)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 0.7, 0.2, 0.25))


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


func _make_fade_curve() -> Curve:
	## Skala partikel: mulai kecil, membesar sedikit, lalu mengecil habis.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
