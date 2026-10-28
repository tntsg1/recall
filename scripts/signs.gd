class_name Signs
extends Node2D
# Neon signs of 第十三街: each chapter hangs its own two signs on the widest
# pillars (or on the top wall when it has none). They hum, and now and then a
# letter stutters off for a moment, the way old neon does.

var game
var font: Font
var _t := 0.0


func _ready() -> void:
	z_index = 3          # on the pillars (the arena draws at 2)
	z_as_relative = false
	font = Fonts.get_font("SemiBold")


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _spots() -> Array:
	var out: Array = []
	for r in game.arena.inner:
		if r.size.x >= 140.0 and r.size.y >= 34.0 and r.size.y < r.size.x:
			out.append(r)
	out.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	if out.size() >= 2:
		return [out[0], out[out.size() - 1]]
	var top := Arena.ROOM.position.y
	return [Rect2(330, top - 58, 300, 44), Rect2(1290, top - 58, 300, 44)]


func _draw() -> void:
	if game == null or game.tutorial != null:
		return
	var ch: int = clampi(game.chapter, 0, 4)
	var texts: Array = [Txt.t("sign_%d_a" % (ch + 1)), Txt.t("sign_%d_b" % (ch + 1))]
	var spots := _spots()
	var dim: float = 1.0 - 0.5 * game.focus
	for i in 2:
		var r: Rect2 = spots[i]
		var s: String = texts[i]
		var size := int(clampf(r.size.y * 0.62, 18.0, 30.0))
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := r.get_center() + Vector2(-w / 2.0, size * 0.36)
		# a stutter: one sign drops out for a few frames every so often
		var seed := floorf(_t * 6.0) + i * 31.0
		var off := fposmod(sin(seed * 12.9898) * 43758.5453, 1.0) > 0.965
		var hum := 0.88 + 0.12 * sin(_t * 23.0 + i)
		var col := Pal.ink(1.0, 1.15)
		var a: float = (0.08 if off else 0.38 * hum) * dim
		draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(col.r, col.g, col.b, a * 0.1))
		draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.r, col.g, col.b, a))
