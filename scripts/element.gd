class_name Element
extends RefCounted

## "Engine graph TD" — graph siklus elemental 3 elemen.
##
##   💧 Air  --x2-->  🔥 Api  --x2-->  ⚡ Petir  --x2-->  💧 Air
##   (balik arah selalu NULL / 0 damage)
##   elemen yg sama = damage normal
##
## Rules:
##   get_multiplier(attacker, defender):
##     - attacker stun "counter" terhadap defender  -> strong_multiplier (x2)
##     - attacker element == defender element      -> normal_multiplier  (x1)
##     - sisanya (reverse dari siklus)              -> null_multiplier    (x0)

enum Type {
	AIR = 0,
	FIRE = 1,
	LIGHTNING = 2,
}

## Nilai default. Bisa dioverride per-pemanggil kalau mau balance sendiri.
const strong_multiplier := 2.0
const normal_multiplier := 1.0
const null_multiplier := 0.0

## SIKLUS UTAMA: attacker -> defender yang dikalahkannya (x2 damage).
const STRONG_AGAINST := {
	Type.AIR: Type.FIRE,
	Type.FIRE: Type.LIGHTNING,
	Type.LIGHTNING: Type.AIR,
}

const NAMES := {
	Type.AIR: "Air",
	Type.FIRE: "Api",
	Type.LIGHTNING: "Petir",
}

## Warna per elemen (dipakai badge musuh + angka damage).
const COLORS := {
	Type.AIR: Color(0.35, 0.65, 1.0),
	Type.FIRE: Color(1.0, 0.35, 0.25),
	Type.LIGHTNING: Color(1.0, 0.8, 0.2),
}


## Multiplier damage attacker -> defender.
static func get_multiplier(attacker: int, defender: int) -> float:
	if attacker == defender:
		return normal_multiplier
	if STRONG_AGAINST.get(attacker, -1) == defender:
		return strong_multiplier
	return null_multiplier


## Label hasil hubungan: "x2", "x1", "NULL".
static func get_relation(attacker: int, defender: int) -> String:
	var m := get_multiplier(attacker, defender)
	if m <= 0.0:
		return "NULL"
	if m >= strong_multiplier:
		return "x%.0f" % m
	return "x%.0f" % m


static func name_of(element: int) -> String:
	return NAMES.get(element, "???")


static func color_of(element: int) -> Color:
	return COLORS.get(element, Color.WHITE)


## Elemen acak buat musuh placeholder.
static func random_type() -> int:
	var all: Array[int] = [Type.AIR, Type.FIRE, Type.LIGHTNING]
	return all.pick_random()
