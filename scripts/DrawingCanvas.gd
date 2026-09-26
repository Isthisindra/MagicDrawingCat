extends Node2D

@onready var line_2d: Line2D = get_node_or_null("Line2D") as Line2D

const NUMBER_OF_POINTS = 32
var current_points: Array[Vector2] = []
var templates: Dictionary = {}
var is_drawing: bool = false

# KEDUA FUNGSI _READY SUDAH DIGABUNGKAN DI SINI
func _ready() -> void:
	# 1. Kode Pengaman Pembuatan/Pencarian Line2D otomatis
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

	# 2. MENDAFTARKAN TEMPLATE BENTUK DASAR SIHIR
	# Template 1: Garis Horizontal Kiri ke Kanan
	templates["Garis Horizontal"] = _process_points([Vector2(0,0), Vector2(100,0)])
	
	# Template 2: Huruf "V"
	templates["Huruf V"] = _process_points([Vector2(0,0), Vector2(50,100), Vector2(100,0)])
	
	# Template 3: Huruf "L"
	templates["Huruf L"] = _process_points([Vector2(0,0), Vector2(0,100), Vector2(100,100)])

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_drawing = true
			current_points.clear()
			line_2d.points = []
			current_points.append(event.position)
			line_2d.add_point(event.position)
		else:
			is_drawing = false
			_evaluate_drawing()

	elif event is InputEventMouseMotion and is_drawing:
		if current_points.is_empty() or current_points.back().distance_to(event.position) > 10.0:
			current_points.append(event.position)
			line_2d.add_point(event.position)

func _evaluate_drawing() -> void:
	if current_points.size() < 5:
		print("Coretan terlalu pendek!")
		return
		
	var result = _recognize(current_points, templates)
	var threshold = 0.80
	
	if result["score"] >= threshold:
		print("Spell Sukses! Bentuk: ", result["name"], " (Skor Kemiripan: ", snapped(result["score"] * 100, 0.1), "%)")
	else:
		print("Sihir Gagal! Bentuk tidak jelas. Terdekat: ", result["name"], " Skor: ", snapped(result["score"] * 100, 0.1), "%")

# =========================================================================
# FUNGSI INTERNAL ALGORITMA UTAMA ($1 RECOGNIZER)
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
