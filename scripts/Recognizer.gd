extends Node2D

## Sihir Gambar: coretan di layar dikenali (algoritma $1) lalu
## memanggil skill sesuai bentuknya. Lingkaran = Sihir Api AoE.

# 1. ATUR REQUISITE COMPONENT
@onready var line_2d: Line2D = get_node_or_null("Line2D") as Line2D

# 2. VARIABEL CONFIGURATION
const NUMBER_OF_POINTS = 32
var current_points: Array[Vector2] = []
var templates: Dictionary = {}
var is_drawing: bool = false

const FireSkillScene := preload("res://scenes/fireskill.tscn")

var _line_fade_tween: Tween

func _ready() -> void:
	# Kode Pengaman Pembuatan/Pencarian Line2D otomatis
	if line_2d == null:
		for child in get_children():
			if child is Line2D:
				line_2d = child
				break
				
	if line_2d == null:
		line_2d = Line2D.new()
		add_child(line_2d)
		line_2d.width = 6.0
		line_2d.default_color = Color.RED

	# MENDAFTARKAN TEMPLATE BENTUK DASAR SIHIR
	templates["Garis Horizontal"] = _process_points([Vector2(0,0), Vector2(100,0)])
	templates["Huruf V"] = _process_points([Vector2(0,0), Vector2(50,100), Vector2(100,0)])
	templates["Huruf L"] = _process_points([Vector2(0,0), Vector2(0,100), Vector2(100,100)])

	# Template 4: Lingkaran (lingkaran penuh tertutup), untuk Sihir Api AoE.
	var circle_pts: Array[Vector2] = []
	for i in range(32):
		var angle := TAU * i / 32.0
		circle_pts.append(Vector2(cos(angle), sin(angle)) * 50.0)
	circle_pts.append(circle_pts[0])  # tutup lingkaran, kembali ke titik awal
	templates["Lingkaran"] = _process_points(circle_pts)

func _input(event: InputEvent) -> void:
	# Deteksi Klik Kiri / Sentuhan Layar
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_drawing = true
			# Kalau fade-garis lama masih jalan, hentikan dan reset opacity.
			if _line_fade_tween and _line_fade_tween.is_running():
				_line_fade_tween.kill()
			line_2d.modulate.a = 1.0
			current_points.clear()
			line_2d.points = []
			var world_pos: Vector2 = get_canvas_transform().affine_inverse() * event.position
			current_points.append(world_pos)
			line_2d.add_point(world_pos)
		else:
			is_drawing = false
			var shape_name = _evaluate_drawing() # Mengevaluasi dan mendapatkan nama bentuk
			print("Hasil dari return fungsi: ", shape_name)

	# Deteksi Gerakan Mouse saat Menggambar
	elif event is InputEventMouseMotion and is_drawing:
		if current_points.is_empty() or current_points.back().distance_to(get_canvas_transform().affine_inverse() * event.position) > 10.0:
			var world_pos: Vector2 = get_canvas_transform().affine_inverse() * event.position
			current_points.append(world_pos)
			line_2d.add_point(world_pos)

# 3. FUNGSI EVALUASI DRAWING
func _evaluate_drawing() -> String:
	if current_points.size() < 5:
		print("Coretan terlalu pendek/singkat!")
		return "Too Short"

	# PRIORITAS 1: Deteksi lingkaran pakai geometri (bukan $1),
	# karena $1 sensitif terhadap titik mulai coretan pada lingkaran.
	var circle_score := _circle_score(current_points)
	if circle_score >= 0.75:
		print("Bentuk Dikenali: Lingkaran (Kebulatan: ", snapped(circle_score * 100, 0.1), "%)")
		_trigger_game_action("Lingkaran")
		return "Lingkaran"

	# PRIORITAS 2: Algoritma $1 untuk bentuk lain (V, L, garis, dll).
	var result = _recognize(current_points, templates)
	var threshold = 0.70 # Diturunkan dari 0.80 agar lebih pemaaf

	if result["score"] >= threshold:
		var nama_bentuk = result["name"]
		print("Bentuk Dikenali: ", nama_bentuk, " (Kemiripan: ", snapped(result["score"] * 100, 0.1), "%)")
		_trigger_game_action(nama_bentuk)
		return nama_bentuk
	else:
		print("Sihir Gagal! Bentuk tidak jelas. Terdekat: ", result["name"], " (Skor: ", snapped(result["score"] * 100, 0.1), "%)")
		return "Unknown"


## Skor "seberapa lingkaran" suatu coretan (0.0 - 1.0):
## gabungan dari (a) konsistensi jari-jari ke centroid,
## (b) kebulatan area vs keliling, (c) coretannya menutup.
func _circle_score(points: Array[Vector2]) -> float:
	var length := _path_length(points)
	if length < 100.0:
		return 0.0
	if points.size() < 8:
		return 0.0

	# (a) Konsistensi jari-jari: jarak tiap titik ke centroid harus seragam.
	var center := _centroid(points)
	var radii: Array[float] = []
	for p in points:
		radii.append(p.distance_to(center))
	var r_avg := 0.0
	for r in radii:
		r_avg += r
	r_avg /= radii.size()
	if r_avg < 30.0:
		return 0.0
	var r_dev := 0.0
	for r in radii:
		r_dev += (r - r_avg) * (r - r_avg)
	r_dev = sqrt(r_dev / radii.size())
	var radial_consistency := clampf(1.0 - (r_dev / r_avg), 0.0, 1.0)

	# (b) Kebulatan: 4*PI*area / keliling^2, lingkaran sempurna = 1.0.
	var area := 0.0
	for i in range(points.size()):
		var j := (i + 1) % points.size()
		area += points[i].x * points[j].y - points[j].x * points[i].y
	area = absf(area) * 0.5
	var circularity := clampf(4.0 * PI * area / (length * length), 0.0, 1.0)

	# (c) Ketertutupan: ujung awal dan akhir coretan harus bertemu.
	var closure := 1.0 - clampf(points[0].distance_to(points[points.size() - 1]) / (length * 0.35), 0.0, 1.0)

	return radial_consistency * 0.45 + circularity * 0.35 + closure * 0.20

# 4. FUNGSI PEMICU GAME ACTION (SPAWN SKILL SESUAI BENTUK)
func _trigger_game_action(bentuk: String) -> void:
	match bentuk:
		"Garis Horizontal":
			print("AKSI: Menembakkan Fireball lurus ke depan!")

		"Huruf V":
			print("AKSI: Memanggil Petir (Lightning Strike) dari langit!")

		"Huruf L":
			print("AKSI: Membuat Dinding Pelindung (Magic Wall)!")

		"Lingkaran":
			# Sihir Api: lingkaran api muncul tepat di tempat coretan,
			# ukuran mengikuti ukuran coretan.
			_spawn_fire_circle()
			print("AKSI: Sihir Api terpanggil di area coretan!")

		_:
			print("AKSI: Bentuk terdaftar tapi belum memiliki logika aksi.")


func _spawn_fire_circle() -> void:
	# Titik tengah coretan = pusat lingkaran api.
	var center := _centroid(current_points)

	# Jari-jari coretan = jarak terjauh dari titik ke pusatnya.
	var radius := 0.0
	for p in current_points:
		var d := p.distance_to(center)
		if d > radius:
			radius = d

	# Batasi ukuran biar wajar di layar.
	radius = clampf(radius, 80.0, 400.0)

	var world := get_tree().current_scene
	var circle := FireSkillScene.instantiate()
	circle.global_position = center
	# Ukuran area ikut coretan lu (di-clamp di _spawn_fire_circle).
	circle.set("radius", radius)
	circle.name = "FireSkill"
	world.add_child(circle)

	# Garis sihir (coretan) tetap nampak sampai skill berakhir,
	# lalu memudar perlahan. Kill tween fade lama biar coretan baru
	# nggak ikut ke-fade.
	var spell_life: float = circle.get("lifetime")
	if _line_fade_tween and _line_fade_tween.is_running():
		_line_fade_tween.kill()
	var fade := create_tween()
	_line_fade_tween = fade
	fade.tween_interval(spell_life)
	fade.tween_property(line_2d, "modulate:a", 0.0, 0.5)
	fade.tween_callback(func() -> void:
		line_2d.points = []
		line_2d.modulate.a = 1.0
	)

# =========================================================================
# INTERNAL ALGORITMA ($1 RECOGNIZER) - JANGAN DIUBAH
# =========================================================================
func _recognize(points: Array[Vector2], total_templates: Dictionary) -> Dictionary:
	var processed_points = _process_points(points)
	var best_score = 0.0
	var best_match = "Unknown"
	
	for template_name in total_templates.keys():
		var template_points: Array[Vector2] = total_templates[template_name]
		var distance = _path_distance(processed_points, template_points)
		var score = max(1.0 - (distance / (0.5 * sqrt(2.0))), 0.0)
		if score > best_score:
			best_score = score
			best_match = template_name
			
	return {"name": best_match, "score": best_score}

func _process_points(points: Array[Vector2]) -> Array[Vector2]:
	var new_points: Array[Vector2] = [points[0]]
	var i_len = _path_length(points) / (NUMBER_OF_POINTS - 1)
	var D = 0.0
	var i = 1
	var pts_copy = points.duplicate()
	while i < pts_copy.size():
		var d = pts_copy[i-1].distance_to(pts_copy[i])
		if (D + d) >= i_len:
			var q = pts_copy[i-1].lerp(pts_copy[i], (i_len - D) / d)
			new_points.append(q)
			pts_copy.insert(i, q)
			D = 0.0
		else:
			D += d
		i += 1
	if new_points.size() < NUMBER_OF_POINTS:
		new_points.append(points[points.size() - 1])
	
	var c = _centroid(new_points)
	var theta = (new_points[0] - c).angle()
	var rotated_pts: Array[Vector2] = []
	for p in new_points:
		rotated_pts.append((p - c).rotated(-theta) + c)
		
	var min_x = INF; var max_x = -INF; var min_y = INF; var max_y = -INF
	for p in rotated_pts:
		min_x = min(min_x, p.x); max_x = max(max_x, p.x)
		min_y = min(min_y, p.y); max_y = max(max_y, p.y)
	var B_width = max(max_x - min_x, 1.0)
	var B_height = max(max_y - min_y, 1.0)
	var scaled_pts: Array[Vector2] = []
	for p in rotated_pts:
		scaled_pts.append(Vector2(p.x * (1.0 / B_width), p.y * (1.0 / B_height)))
		
	var new_c = _centroid(scaled_pts)
	var final_pts: Array[Vector2] = []
	for p in scaled_pts:
		final_pts.append(p - new_c)
		
	return final_pts

func _path_length(points: Array[Vector2]) -> float:
	var d = 0.0
	for i in range(1, points.size()):
		d += points[i-1].distance_to(points[i])
	return d

func _centroid(points: Array[Vector2]) -> Vector2:
	var c = Vector2.ZERO
	for p in points:
		c += p
	return c / points.size()

func _path_distance(pts1: Array[Vector2], pts2: Array[Vector2]) -> float:
	var d = 0.0
	var min_size = min(pts1.size(), pts2.size())
	for i in range(min_size):
		d += pts1[i].distance_to(pts2[i])
	return d / min_size
