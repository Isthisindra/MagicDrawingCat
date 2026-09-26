extends CharacterBody2D

## Player dengan gerakan 8 arah (top-down).

@export var speed := 1000.0
## 1.0 = langsung penuh kecepatan, lebih kecil = akselerasi halus.
@export var acceleration := 2.0

@onready var sprite: Node2D = get_node_or_null("AnimatedSprite2D") if get_node_or_null("AnimatedSprite2D") else get_node_or_null("Sprite2D")
@onready var camera: Camera2D = get_node_or_null("Camera2D")

# Tombol gerak: WASD utama, panah sebagai cadangan.
# is_physical_key_pressed -> pakai posisi tombol, jadi tetap pas di AZERTY/QWERTZ.
const KEYS_LEFT: Array = [KEY_A, KEY_LEFT]
const KEYS_RIGHT: Array = [KEY_D, KEY_RIGHT]
const KEYS_UP: Array = [KEY_W, KEY_UP]
const KEYS_DOWN: Array = [KEY_S, KEY_DOWN]


func _ready() -> void:
	# Cegah kamera "menyapu" dari posisi lama saat scene baru dimuat.
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_ON)
	if camera:
		camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	# Vektor 8 arah dari WASD (di-normalisasi, jadi diagonal sama cepat).
	var direction := _input_direction().limit_length(1.0)

	if direction != Vector2.ZERO:
		# Gerak 8 arah + akselerasi supaya mulus.
		velocity = velocity.move_toward(direction * speed, speed * acceleration * delta)

		# Balik sprite mengikuti arah horizontal.
		if sprite and direction.x != 0.0:
			sprite.flip_h = direction.x < 0.0
	else:
		# Tidak ada input -> melambat sampai berhenti.
		velocity = velocity.move_toward(Vector2.ZERO, speed * acceleration * delta)

	move_and_slide()


## Arah gerak dari keyboard. Stik kiri gamepad jadi cadangan.
func _input_direction() -> Vector2:
	var dir := Vector2(
		_pressed_any(KEYS_RIGHT) - _pressed_any(KEYS_LEFT),
		_pressed_any(KEYS_DOWN) - _pressed_any(KEYS_UP)
	)
	if dir != Vector2.ZERO:
		return dir
	return Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)


func _pressed_any(keys: Array) -> float:
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return 1.0
	return 0.0
