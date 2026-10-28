class_name Fx
extends Node2D
# Short-lived marks: sparks, rings, shards, damage numbers, additive flashes
# and the slow dust that keeps the room breathing. Pooled in plain arrays,
# drawn in one pass per layer.

var game
var sp_list: Array = []   # [pos, vel, t, dur, color, width, len, drag]
var rings: Array = []    # [pos, r0, r1, t, dur, color, width]
var shards: Array = []   # [pos, a, b, rot, vel, spin, t, dur, color, width]
var numbers: Array = []  # [text, pos, vel, t, dur, size, color, pop]
var flashes: Array = []  # [pos, r, t, dur, color]
var motes: Array = []    # [pos, vel, phase, size]
var add_layer: Node2D
var glow_tex: Texture2D
var num_font: Font


func _ready() -> void:
	z_index = 5
	z_as_relative = false
	add_layer = Node2D.new()
	add_layer.z_index = 7
	add_layer.z_as_relative = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_layer.material = m
	add_layer.draw.connect(_draw_add)
	add_child(add_layer)
	glow_tex = make_glow_texture()
	num_font = Fonts.get_font("SemiBold")
	var room := Arena.ROOM
	for i in 70:
		motes.append([Vector2(randf_range(room.position.x, room.end.x), randf_range(room.position.y, room.end.y)),
			Vector2.from_angle(randf() * TAU) * randf_range(4.0, 12.0), randf() * TAU, randf_range(0.8, 1.8)])


static func make_ring_texture() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			var a := clampf(1.0 - absf(d - 0.84) / 0.12, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func make_glow_texture() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func spark(pos: Vector2, vel: Vector2, dur: float, c: Color, w: float = 1.5, l: float = 10.0, drag: float = 7.0) -> void:
	if sp_list.size() >= 700:
		return
	sp_list.append([pos, vel, 0.0, dur, c, w, l, drag])


func sparks(pos: Vector2, dir: Vector2, n: int, c: Color, speed: float, dur: float, spread: float = 0.9) -> void:
	for i in n:
		var a := dir.angle() + randf_range(-spread, spread)
		spark(pos, Vector2.from_angle(a) * speed * randf_range(0.45, 1.0), dur * randf_range(0.6, 1.0), c, randf_range(1.0, 2.0), randf_range(6.0, 14.0))


func ring(pos: Vector2, r0: float, r1: float, dur: float, c: Color, w: float = 1.5) -> void:
	if rings.size() >= 120:
		return
	rings.append([pos, r0, r1, 0.0, dur, c, w])


func shard(pos: Vector2, a: Vector2, b: Vector2, vel: Vector2, spin: float, dur: float, c: Color, w: float = 2.0) -> void:
	if shards.size() >= 200:
		return
	shards.append([pos, a, b, 0.0, vel, spin, 0.0, dur, c, w])


func number(pos: Vector2, value: float, ret: bool) -> void:
	if numbers.size() >= 48:
		numbers.remove_at(0)
	var size := 30 if ret else 20
	var c := Pal.ink(1.0, 1.6 if ret else 1.0)
	var v := Vector2(randf_range(-40, 40), -110.0 if ret else -70.0)
	numbers.append([str(int(round(value))), pos + Vector2(randf_range(-8, 8), -10), v, 0.0, 0.75 if ret else 0.6, size, c, 1.0])


func flash(pos: Vector2, r: float, dur: float, c: Color) -> void:
	if flashes.size() >= 300:
		return
	if Settings.soft:
		# softer flashes: smaller and dimmer
		r *= 0.6
		c.a *= 0.45
	flashes.append([pos, r, 0.0, dur, c])


func wave_push(center: Vector2, radius: float, strength: float) -> void:
	for m in motes:
		var d: Vector2 = m[0] - center
		var l := d.length()
		if l < radius and l > 1.0:
			m[1] += d / l * strength * (1.0 - l / radius)


func step(dt: float, real_dt: float) -> void:
	_age(sp_list, 2, 3, dt)
	for s in sp_list:
		s[0] += s[1] * dt
		s[1] *= exp(-s[7] * dt)
	_age(rings, 3, 4, dt)
	_age(shards, 6, 7, dt)
	for s in shards:
		s[0] += s[4] * dt
		s[4] *= exp(-3.2 * dt)
		s[3] += s[5] * dt
		s[5] *= exp(-2.0 * dt)
	_age(numbers, 3, 4, real_dt * 0.5 + dt * 0.5)
	for n in numbers:
		n[1] += n[2] * dt
		n[2] *= exp(-5.0 * dt)
	_age(flashes, 2, 3, dt)
	var room := Arena.ROOM
	for m in motes:
		m[2] += dt
		m[0] += (m[1] + Vector2(sin(m[2] * 0.31), cos(m[2] * 0.27)) * 5.0) * dt
		m[1] = Pal.damp2(m[1], m[1].normalized() * 8.0, 0.8, dt)
		if not room.has_point(m[0]):
			m[0] = Vector2(fposmod(m[0].x - room.position.x, room.size.x) + room.position.x, fposmod(m[0].y - room.position.y, room.size.y) + room.position.y)
	queue_redraw()
	add_layer.queue_redraw()


func _age(arr: Array, ti: int, di: int, dt: float) -> void:
	var i := 0
	while i < arr.size():
		arr[i][ti] += dt
		if arr[i][ti] >= arr[i][di]:
			arr.remove_at(i)
		else:
			i += 1


func _draw() -> void:
	var f: float = game.focus
	for m in motes:
		var a := (0.05 + 0.04 * sin(m[2] * 0.7 + m[3] * 3.0)) * (1.0 - 0.6 * f)
		draw_circle(m[0], m[3], Pal.ink(a))
	# all sparks in one batch
	var segs := PackedVector2Array()
	var cols := PackedColorArray()
	for s in sp_list:
		var k: float = 1.0 - s[2] / s[3]
		var v: Vector2 = s[1]
		var dir := v.normalized() if v.length_squared() > 1.0 else Vector2.RIGHT
		var l: float = s[6] * (0.3 + 0.7 * k) + v.length() * 0.012
		var c: Color = s[4]
		segs.append(s[0])
		segs.append(s[0] - dir * l)
		cols.append(Color(c.r, c.g, c.b, c.a * k))
	if segs.size() > 0:
		draw_multiline_colors(segs, cols, 1.6)
	for r in rings:
		var e := Pal.ease_out(r[3] / r[4])
		var c2: Color = r[5]
		var rad := lerpf(r[1], r[2], e)
		draw_arc(r[0], rad, 0.0, TAU, maxi(16, int(rad * 0.6)), Color(c2.r, c2.g, c2.b, c2.a * (1.0 - e)), r[6] * (1.0 - 0.6 * e), false)
	for s in shards:
		var k2: float = 1.0 - s[6] / s[7]
		var c3: Color = s[8]
		var tr := Transform2D(s[3], s[0])
		draw_line(tr * s[1], tr * s[2], Color(c3.r, c3.g, c3.b, c3.a * Pal.ease_out(k2 * 1.4)), s[9])
	for n in numbers:
		var t: float = n[3]
		var pop := lerpf(1.7, 1.0, Pal.back(t / 0.14, 2.2))
		var a2 := clampf((n[4] - t) / 0.22, 0.0, 1.0)
		var c4: Color = n[6]
		var txt: String = n[0]
		var size: int = n[5]
		var w := num_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_set_transform(n[1], 0.0, Vector2(pop, pop))
		draw_string(num_font, Vector2(-w / 2.0 + 1.5, size * 0.35 + 1.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * a2))
		draw_string(num_font, Vector2(-w / 2.0, size * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c4.r, c4.g, c4.b, a2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_add() -> void:
	for fl in flashes:
		var k: float = 1.0 - fl[2] / fl[3]
		var r: float = fl[1] * (0.6 + 0.4 * Pal.ease_out(fl[2] / fl[3] * 2.0))
		var c: Color = fl[4]
		add_layer.draw_texture_rect(glow_tex, Rect2(fl[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c.r, c.g, c.b, c.a * k * k))
