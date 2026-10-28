class_name Hud
extends CanvasLayer
# Screen-space layer: reticle, ammo count, the pierce counter that climbs
# during a recall and stamps when it ends, key hints, vignette and pause.

var game
var view: Control
var vig: TextureRect
var font_l: Font
var font_s: Font
var font_b: Font
var reticle := Vector2(960, 540)
var ammo_pop := 0.0
var combo := 0
var combo_pop := 0.0
var combo_t := -1.0       # time since the recall ended; <0 while it runs or hidden
var combo_live := false
var combo_stamp := 0.0
var combo_seize := false   # counting a seized shell's hits (cyan, "combo") instead of pierces
var hint_a := 1.0
var hint_fade := false
var hint_timer := 0.0
var paused := false
var pause_a := 0.0
var title_i := -1
var title_t := -1.0
var title_note := ""
var stamp_t := -1.0
var stamp_g := ""
var stamp_time := 0.0
var pens: Array = []       # [from (screen), t]
var timer_bump := 0.0
var shown_grade := "S"
var grade_flip := 0.0
var final_t := -1.0
var final_rows: Array = []
var font_xl: Font
var boss_hp_shown := 1.0
var boss_hp_chip := 1.0
var boss_flash := 0.0


func _ready() -> void:
	layer = 5
	font_l = Fonts.get_font("Light")
	font_s = Fonts.get_font("Regular")
	font_b = Fonts.get_font("SemiBold")
	font_xl = Fonts.get_font("Medium")
	vig = TextureRect.new()
	vig.texture = _vignette_texture()
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	view = Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view)
	add_child(view)
	_motion_ready()


static func _vignette_texture() -> Texture2D:
	var w := 192
	var h := 108
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h * 2.0 - 1.0
			var d := sqrt(u * u * 0.8 + v * v * 1.1)
			var a := clampf((d - 0.55) / 0.75, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * 0.85))
	return ImageTexture.create_from_image(img)


func fired() -> void:
	ammo_s.kick(-2.5)
	ret_gap.kick(240.0)
	ret_rot.kick(randf_range(-1.0, 1.0) * 1.6)
	ret_dot.kick(9.0)
	ring_hold = 1.2


func ammo_in() -> void:
	ammo_pop = 1.0
	ammo_s.kick(4.0)
	ring_hold = 1.2


# A round connected: four diagonal ticks flash out of the reticle. Kills are
# red and wider, pass hits on a recall glow red.
func hit_confirm(ret: bool) -> void:
	var kind := 1 if ret else 0
	if hitm > 0.4 and hitm_kind > kind:
		kind = hitm_kind
	hitm = 1.0
	hitm_kind = kind
	ret_dot.kick(5.0)


func kill_confirm(big: bool) -> void:
	hitm = 1.0
	hitm_kind = 3 if big else 2
	hitm_k.kick(9.0 if big else 6.0)
	ret_gap.kick(200.0 if big else 120.0)


# Trigger pulled on an empty magazine: the reticle shakes its head.
func dry() -> void:
	dry_k = 1.0
	dry_sign = -dry_sign
	ret_shake.v += Vector2(520.0 * dry_sign, 0.0)


# Rounds called home: the ticks snap inward and whirl.
# The recall: a ring of streaks rushes in toward you from beyond the screen.
var lines: Array = []          # [angle, start radius, length, t, red]


func speed_lines(k: float) -> void:
	for i in int(36 + 40 * k):
		lines.append([randf() * TAU, randf_range(700.0, 1250.0), randf_range(70.0, 190.0) * (0.6 + 0.6 * k), -randf() * 0.08, randf() < 0.55])


func _step_lines(dt: float) -> void:
	var i := 0
	while i < lines.size():
		lines[i][3] += dt
		if lines[i][3] > 0.4:
			lines.remove_at(i)
		else:
			i += 1


func _draw_lines() -> void:
	if lines.is_empty():
		return
	var c: Vector2 = game.get_viewport().get_canvas_transform() * game.player.pos
	var pr := PackedVector2Array()
	var pw := PackedVector2Array()
	for l in lines:
		var tt: float = l[3]
		if tt < 0.0:
			continue
		var e := Pal.ease_in(tt / 0.4)
		var r: float = lerpf(l[1], 40.0, e)
		var d := Vector2.from_angle(l[0])
		var a: Vector2 = c + d * r
		var b: Vector2 = c + d * (r + l[2] * (1.0 - e * 0.7))
		if l[4]:
			pr.append(a)
			pr.append(b)
		else:
			pw.append(a)
			pw.append(b)
	if pr.size() > 0:
		view.draw_multiline(pr, Pal.red(0.8, 2.4), 2.0)
	if pw.size() > 0:
		view.draw_multiline(pw, Pal.ink(0.55, 1.4), 1.2)


func recall_pull() -> void:
	ret_gap.kick(-260.0)
	ret_rot.kick(11.0)
	ret_dot.kick(14.0)


func combo_hit(n: int, seize: bool = false) -> void:
	combo = n
	combo_seize = seize
	combo_s.kick(5.0)
	combo_live = true
	combo_t = -1.0
	combo_pop = 1.0


func combo_end() -> void:
	if combo <= 0:
		return
	combo_live = false
	combo_t = 0.0
	combo_stamp = 1.0


func wave_title(i: int, note: String) -> void:
	title_i = i
	title_t = 0.0
	title_note = note


func stamp(_i: int, time: float, grade: String) -> void:
	stamp_t = 0.0
	stamp_landed = false
	stamp_g = grade
	stamp_time = time


func penalty(from_screen: Vector2) -> void:
	pens.append([from_screen, 0.0])


func final(rows: Array) -> void:
	final_rows = rows
	final_t = 0.0


func boss_phase() -> void:
	boss_flash = 1.0
	game.post.pulse(0.012)
	game.post.shock(Vector2(0.5, 0.5), 1.6, 2.6)
	# a piece of the bar breaks off where the health stands
	var vp := view.get_viewport_rect().size
	var x := vp.x / 2.0 - 280.0 + 560.0 * boss_hp_shown
	for k in 12:
		var h := randf_range(4.0, 14.0)
		var at := Vector2(x + randf_range(-40.0, 10.0), 94.0)
		ui_shards.append([at, Vector2(-h / 2.0, 0), Vector2(h / 2.0, 0), Vector2(randf_range(-160, 160), randf_range(-220, -60)), 0.0, randf_range(-10, 10), 0.0, k % 3 == 0])


func recalled_once() -> void:
	if not hint_fade:
		hint_fade = true
		hint_timer = 3.5


func step(dt: float) -> void:
	var vp := view.get_viewport_rect().size
	if game.bot == null and not game.pad_aim:
		reticle = view.get_global_mouse_position()
	else:
		reticle = game.get_viewport().get_canvas_transform() * game.aim_world()
	ammo_pop = maxf(0.0, ammo_pop - dt / 0.25)
	combo_pop = maxf(0.0, combo_pop - dt / 0.16)
	combo_stamp = maxf(0.0, combo_stamp - dt / 0.3)
	if combo_t >= 0.0:
		combo_t += dt
		if combo_t > 1.6:
			combo_t = -1.0
			combo = 0
	if hint_fade:
		hint_timer -= dt
		if hint_timer < 0.0:
			hint_a = maxf(0.0, hint_a - dt / 1.2)
	pause_a = Pal.damp(pause_a, 1.0 if paused else 0.0, 14.0, dt)
	if title_t >= 0.0:
		title_t += dt
		if title_t > 2.2:
			title_t = -1.0
	if stamp_t >= 0.0:
		stamp_t += dt
		if stamp_t > 2.5:
			stamp_t = -1.0
	if final_t >= 0.0:
		final_t += dt
	var i := 0
	while i < pens.size():
		pens[i][1] += dt
		if pens[i][1] >= 0.55:
			pens.remove_at(i)
			timer_bump = 1.0
			game.sfx.play("tick", 0.8, -6.0)
		else:
			i += 1
	timer_bump = maxf(0.0, timer_bump - dt / 0.35)
	grade_flip = maxf(0.0, grade_flip - dt / 0.3)
	var w = game.wave_ctl
	if w.phase == Waves.FIGHT:
		var g: String = w.grade_for(w.index, w.time_now())
		if g != shown_grade:
			shown_grade = g
			grade_flip = 1.0
			game.sfx.play("tick", 0.6, -8.0)
	elif w.phase == Waves.TITLE:
		shown_grade = "S"
	vig.modulate.a = 0.75 + 0.25 * game.focus
	vig.size = vp
	_step_cards(dt)
	var bf: float = clampf(game.boss.hp / game.boss.max_hp(), 0.0, 1.0)
	boss_hp_chip = Pal.damp(boss_hp_chip, bf, 2.5, dt) if boss_hp_chip > bf else bf
	boss_flash = maxf(0.0, boss_flash - dt / 0.6)
	_step_motion(dt)
	_step_tip(dt, vp)
	_step_lines(dt)
	view.queue_redraw()


func _draw_view() -> void:
	var vp := view.get_viewport_rect().size
	var f: float = game.focus
	_draw_reticle(f)
	# ammo
	var ammo: int = game.ammo
	var s := str(ammo)
	var size := int(44 * (1.0 + clampf(ammo_s.x, -0.2, 0.3)))
	var base := Vector2(vp.x / 2.0, vp.y - 46.0)
	var ac := Pal.ink(0.9) if ammo > 0 else Pal.ink(0.35)
	ammo_odo.set_text(s, 1.0 if ammo > ammo_last else -1.0)
	ammo_last = ammo
	ammo_odo.draw(view, font_l, base.x - 4.0, base.y, size, ac, 1)
	view.draw_string(font_s, base + Vector2(6.0, 0), "/ %d" % game.mag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.35))
	var emb: int = game.bullets.count_state(Bullets.EMBED)
	if emb > 0:
		var qa := 0.35 + 0.25 * sin(game.real_time * 3.0)
		var qc := Pal.ink(qa).lerp(Pal.red(1.0, 2.0), f)
		var qs := "Q  " + str(emb)
		view.draw_string(font_b, base + Vector2(60.0, 0), qs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, qc)
	# pierce counter
	if game.tutorial == null and combo > 0 and (combo_live or combo_t >= 0.0):
		var a := 1.0
		var rise := 0.0
		if combo_t >= 0.0:
			a = clampf((1.6 - combo_t) / 0.5, 0.0, 1.0)
			rise = Pal.ease_in(clampf((combo_t - 1.1) / 0.5, 0.0, 1.0)) * 24.0
		var k := 1.0 + clampf(combo_s.x, -0.2, 0.4) + 0.5 * Pal.ease_out(combo_stamp)
		var cs := "×" + str(combo)
		var csz := 64
		var cp := Vector2(vp.x / 2.0, 150.0 - rise)
		# step aside for the player when they stand right under it
		var ps: Vector2 = game.get_viewport().get_canvas_transform() * game.player.pos
		if ps.distance_to(cp) < 170.0:
			a *= lerpf(0.3, 1.0, ps.distance_to(cp) / 170.0)
		view.draw_set_transform(cp, 0.0, Vector2(k, k))
		combo_odo.set_text(cs, 1.0)
		combo_odo.draw(view, font_b, 0.0, 22.0, csz, Possess.cyan(a, 2.4 + 2.0 * combo_stamp) if combo_seize else Pal.red(a, 2.4 + 2.0 * combo_stamp), 0)
		view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var lab := Txt.t("possess_combo" if combo_seize else "pierce")
		var lw := font_s.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		view.draw_string(font_s, cp + Vector2(-lw / 2.0, 56.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.55 * a))
		if combo_stamp > 0.0:
			var e := 1.0 - combo_stamp
			view.draw_arc(cp, lerpf(40.0, 150.0, Pal.ease_out(e)), 0.0, TAU, 64, Possess.cyan(combo_stamp * 0.8, 2.0) if combo_seize else Pal.red(combo_stamp * 0.8, 2.0), 2.0, false)
	if game.trial:
		_draw_yard(vp)
	if game.tutorial == null:
		_draw_timer(vp)
		_draw_title(vp)
	_draw_stamp(vp)
	_draw_cards(vp)
	_draw_final(vp)
	_draw_dev(vp)
	# hints
	if hint_a > 0.0:
		var y := vp.y - 52.0
		for key in ["hint_fire", "hint_recall", "hint_dash"]:
			view.draw_string(font_s, Vector2(40.0, y), Txt.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.42 * hint_a))
			y += 22.0
	_draw_lines()
	_draw_tip(vp)
	_draw_motion(vp)
	if game.tutorial != null and not paused:
		game.tutorial.draw_hud(self, vp)


# Each character springs up into place a beat after the one before it, then
# on the way out they drift apart and lift away in the same order.
func _text_stagger(font: Font, txt: String, center: Vector2, size: int, c: Color, tin: float, tout: float, gap: float = 0.035) -> void:
	if tin <= 0.0:
		return
	var n := txt.length()
	var ws: Array = []
	var total := 0.0
	for ch in txt:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		ws.append(w)
		total += w
	var x := center.x - total / 2.0
	for i in n:
		var pin := clampf((tin - i * gap) / 0.34, 0.0, 1.0)
		var ain := clampf((tin - i * gap) / 0.16, 0.0, 1.0)
		var pout := 0.0
		if tout > 0.0:
			pout = Pal.ease_in(clampf((tout - i * gap * 0.6) / 0.32, 0.0, 1.0))
		var a := ain * (1.0 - pout)
		if a > 0.003:
			var off := Vector2((i - (n - 1) / 2.0) * 9.0 * pout, (1.0 - Pal.back(pin, 1.8)) * 26.0 - 16.0 * pout)
			view.draw_string(font, Vector2(x, center.y) + off, txt[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c.r, c.g, c.b, c.a * a))
		x += ws[i]


func _text_c(font: Font, txt: String, center: Vector2, size: int, c: Color) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	view.draw_string(font, Vector2(center.x - w / 2.0, center.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _draw_timer(vp: Vector2) -> void:
	var w = game.wave_ctl
	if w.index < 0 or w.phase == Waves.DONE:
		return
	var appear := 1.0
	if w.phase == Waves.TITLE:
		appear = Pal.ease_out(w.t / 0.6)
	var cx := vp.x / 2.0
	var y := 46.0 - (1.0 - appear) * 20.0
	var tm: float = w.time_now() if w.phase != Waves.TITLE else 0.0
	if w.phase == Waves.CLEAR and w.results.size() > 0:
		tm = w.results[w.results.size() - 1][0]
	var k := 1.0 + 0.25 * Pal.ease_out(timer_bump)
	view.draw_set_transform(Vector2(cx, y), 0.0, Vector2(k, k))
	timer_odo.set_text("%.1f" % tm, 1.0 if tm >= timer_last else -1.0)
	timer_last = tm
	timer_odo.draw(view, font_l, 0.0, 10.0, 34, Pal.ink(0.92 * appear), 0)
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	view.draw_string(font_s, Vector2(cx - 150.0, y + 4.0), "%02d" % (w.index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.4 * appear))
	view.draw_line(Vector2(cx - 120.0, y - 2.0), Vector2(cx - 70.0, y - 2.0), Pal.ink(0.18 * appear), 1.0)
	view.draw_line(Vector2(cx + 70.0, y - 2.0), Vector2(cx + 120.0, y - 2.0), Pal.ink(0.18 * appear), 1.0)
	# the grade still within reach, flipping over as each threshold passes
	var flip := absf(cos(grade_flip * PI))
	view.draw_set_transform(Vector2(cx + 140.0, y - 2.0), 0.0, Vector2(1.0, maxf(0.05, flip)))
	_text_c(font_b, shown_grade, Vector2(0, 8), 22, Pal.ink(0.75 * appear))
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if w.phase == Waves.FIGHT:
		var p: Array = w.par(w.index)
		var nxt := 0.0
		if shown_grade == "S":
			nxt = p[0]
		elif shown_grade == "A":
			nxt = p[1]
		if nxt > 0.0:
			var left := clampf((nxt - tm) / nxt, 0.0, 1.0)
			view.draw_line(Vector2(cx - 60.0, y + 22.0), Vector2(cx + 60.0, y + 22.0), Pal.ink(0.1), 2.0)
			view.draw_line(Vector2(cx - 60.0, y + 22.0), Vector2(cx - 60.0 + 120.0 * left, y + 22.0), Pal.ink(0.45), 2.0)
	_draw_boss_bar(vp, cx, y, appear)
	# +5 seconds fly from the player into the clock
	for pe in pens:
		var f: float = pe[1] / 0.55
		var e := Pal.ease_io(f)
		var from: Vector2 = pe[0]
		var to := Vector2(cx, y)
		var mid := from.lerp(to, 0.5) + Vector2(0, -120)
		var p2 := from.lerp(mid, e).lerp(mid.lerp(to, e), e)
		var pop := 1.0 + 0.6 * (1.0 - Pal.ease_out(f * 3.0))
		view.draw_set_transform(p2, 0.0, Vector2(pop, pop))
		_text_c(font_b, "+5", Vector2(0, 8), 26, Pal.ink(1.0, 1.6))
		view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_title(vp: Vector2) -> void:
	if title_t < 0.0:
		return
	var t := title_t
	var cy := vp.y * 0.38
	# two hairlines sweep in from the sides, the label rises between them, then all wipe out
	var inn := Pal.ease_out(t / 0.45)
	var out := Pal.ease_in(clampf((t - 1.55) / 0.45, 0.0, 1.0))
	var half := 360.0 * inn
	var a := 1.0 - out
	var cx := vp.x / 2.0
	var shift := out * 80.0
	view.draw_line(Vector2(cx - half + shift, cy - 44.0), Vector2(cx + half * (1.0 - out) + shift, cy - 44.0), Pal.ink(0.5 * a), 1.0)
	view.draw_line(Vector2(cx - half * (1.0 - out) - shift, cy + 28.0), Vector2(cx + half - shift, cy + 28.0), Pal.ink(0.5 * a), 1.0)
	var label := Txt.t("wave") % (title_i + 1)
	if title_i == Waves.BOSS:
		label = Txt.t(game.boss.name_key())
		var ba := clampf((t - 0.05) / 0.2, 0.0, 1.0) * a
		_text_c(font_b, "BOSS", Vector2(cx, cy - 58.0), 14, Pal.ink(0.55 * ba))
	var rise := (1.0 - Pal.back(clampf((t - 0.12) / 0.4, 0.0, 1.0))) * 26.0
	var la := clampf((t - 0.12) / 0.25, 0.0, 1.0) * a
	_text_stagger(font_xl, label, Vector2(cx, cy), 56 if title_i == Waves.BOSS else 46, Pal.ink(1.0, 1.1), t - 0.12, t - 1.5)
	if title_note != "":
		var na := clampf((t - 0.45) / 0.3, 0.0, 1.0) * a
		_text_c(font_s, Txt.t(title_note), Vector2(cx, cy + 62.0), 17, Pal.ink(0.7 * na))
	var tick := Pal.ease_out(clampf((t - 0.2) / 0.5, 0.0, 1.0))
	for sd in [-1.0, 1.0]:
		var x: float = cx + sd * (half + 14.0)
		view.draw_line(Vector2(x, cy - 44.0), Vector2(x, cy - 44.0 + 72.0 * tick), Pal.ink(0.35 * a), 1.0)


func _draw_stamp(vp: Vector2) -> void:
	if stamp_t < 0.0:
		return
	var t := stamp_t
	var c := Vector2(vp.x / 2.0, vp.y * 0.3)
	var land := Pal.ease_in(clampf(t / 0.16, 0.0, 1.0))
	var k := lerpf(2.6, 1.0, land)
	if t > 0.16:
		var u := t - 0.16
		k = 1.0 - 0.1 * exp(-8.0 * u) * cos(u * 34.0)
	var a := clampf(t / 0.08, 0.0, 1.0) * (1.0 - Pal.ease_in(clampf((t - 2.0) / 0.5, 0.0, 1.0)))
	var rot := lerpf(-0.35, -0.06, land)
	var bright := 1.0
	if t > 0.16:
		bright = 1.0 + 1.6 * maxf(0.0, 1.0 - (t - 0.16) / 0.3)
	view.draw_set_transform(c, rot, Vector2(k, k))
	_text_c(font_b, stamp_g, Vector2(0, 42), 120, Pal.ink(a, bright * (1.25 if stamp_g == "S" else 1.0)))
	view.draw_rect(Rect2(-70, -68, 140, 136), Pal.ink(0.55 * a), false, 3.0)
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if t > 0.16:
		var e := Pal.ease_out((t - 0.16) / 0.5)
		view.draw_arc(c, lerpf(70.0, 230.0, e), 0.0, TAU, 72, Pal.ink(0.6 * (1.0 - e)), 2.0, false)
		var ta := a * clampf((t - 0.2) / 0.2, 0.0, 1.0)
		_text_c(font_l, "%.1f s" % stamp_time, c + Vector2(0, 112.0 + (1.0 - Pal.ease_out((t - 0.16) / 0.4)) * 14.0), 24, Pal.ink(0.75 * ta))


func _draw_final(vp: Vector2) -> void:
	if final_t < 0.0:
		return
	var t := final_t
	var a := Pal.ease_out(t / 0.6)
	view.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.82 * a))
	var cx := vp.x / 2.0
	var y := vp.y * 0.26
	_text_stagger(font_xl, Txt.t("done"), Vector2(cx, y), 44, Pal.ink(1.0, 1.1), t - 0.1, -1.0, 0.06)
	view.draw_line(Vector2(cx - 220.0 * a, y + 26.0), Vector2(cx + 220.0 * a, y + 26.0), Pal.ink(0.4 * a), 1.0)
	var total := 0.0
	for i in final_rows.size():
		var row: Array = final_rows[i]
		total += row[1]
		var rt := clampf((t - 0.4 - i * 0.12) / 0.3, 0.0, 1.0)
		if rt <= 0.0:
			continue
		var ry := y + 80.0 + i * 46.0
		var ra := Pal.ease_out(rt)
		var dx := (1.0 - ra) * 30.0
		view.draw_string(font_s, Vector2(cx - 260.0 - dx, ry), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.6 * ra))
		var roll := Pal.ease_out(clampf((t - 0.45 - i * 0.12) / 0.7, 0.0, 1.0))
		view.draw_string(font_l, Vector2(cx - 10.0 - dx, ry), "%.1f s" % (row[1] * roll), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.ink(0.9 * ra))
		var gk := lerpf(1.8, 1.0, Pal.back(clampf((t - 0.55 - i * 0.12) / 0.25, 0.0, 1.0)))
		view.draw_set_transform(Vector2(cx + 190.0, ry - 8.0), 0.0, Vector2(gk, gk))
		_text_c(font_b, row[2], Vector2(0, 8), 20, Pal.ink(ra, 1.1))
		view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var n := final_rows.size()
	var bt := clampf((t - 0.5 - n * 0.12) / 0.4, 0.0, 1.0)
	if bt > 0.0:
		var by := y + 80.0 + n * 46.0 + 24.0
		view.draw_line(Vector2(cx - 220.0, by - 22.0), Vector2(cx + 220.0, by - 22.0), Pal.ink(0.25 * bt), 1.0)
		view.draw_string(font_s, Vector2(cx - 200.0, by + 8.0), Txt.t("total"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.6 * bt))
		view.draw_string(font_l, Vector2(cx - 10.0, by + 8.0), "%.1f s" % (total * Pal.ease_out(bt)), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.ink(bt))
		view.draw_string(font_s, Vector2(cx + 120.0, by + 8.0), "%s  %d" % [Txt.t("hits"), game.hits_taken], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.55 * bt))
		_run_stats(cx, by + 60.0, bt)
		_text_c(font_s, Txt.t("done_next"), Vector2(cx, by + 150.0), 16, Pal.ink(0.45 * bt))
		var pulse := 0.55 + 0.25 * sin(t * 3.0)
		_text_c(font_b, Txt.t("restart"), Vector2(cx, by + 190.0), 20, Pal.ink(pulse * bt))


# Best pierce, crosses, last-second recalls, and what this run unlocked.
func _run_stats(cx: float, y: float, a: float) -> void:
	var k := Pal.ease_out(a)
	var line := "%s %d   ·   %s %d   ·   %s %d" % [Txt.t("r_combo"), int(round(game.max_combo * k)), Txt.t("r_cross"), int(round(game.crosses * k)), Txt.t("r_crit"), int(round(game.crit_recalls * k))]
	_text_c(font_s, line, Vector2(cx, y), 16, Pal.ink(0.65 * a))
	if not game.run_ach.is_empty():
		var names: Array = []
		for id in game.run_ach:
			names.append(Ach.name_of(id))
		_text_c(font_s, Txt.t("r_new") + "  " + "  ·  ".join(names.slice(0, 6)), Vector2(cx, y + 30.0), 15, Pal.ink(0.85 * a, 1.2))


# ---------------------------------------------------------------- cards and slots

const CARD := Vector2(300, 400)
const CARD_GAP := 340.0
const SLOT := 40.0

var cards: Array = []        # offers: {type, id, level?, full?}
var cards_t := -1.0
var chosen := -1
var chosen_t := 0.0
var chosen_card := {}
var school_pop := {"bounce": 0.0, "split": 0.0, "orbit": 0.0, "magnet": 0.0, "blast": 0.0, "charge": 0.0, "shadow": 0.0, "chain": 0.0}
var relic_pop := {}
var hover := -1
var hover_k := [0.0, 0.0, 0.0]
var reroll_k := 0.0
var rep_card := {}
var rep_t := -1.0
var rep_hover := -2
var cracks_shown := 5
var crack_anim := []          # per crack: >0 breaking, <0 mending
var flashes: Array = []       # [text, world_pos or null, t]
var over_t := -1.0
var intro_t := -1.0


func show_cards(offers: Array) -> void:
	cards = offers.duplicate()
	cards_t = 0.0
	chosen = -1
	reroll_k = 0.0
	var vp := view.get_viewport_rect().size
	for i in card_y.size():
		card_y[i].snap(vp.y * 0.75 + i * 90.0)
		card_tilt[i].snap(Vector2.ZERO)


func pick(i: int, c: Dictionary) -> void:
	chosen = i
	chosen_t = 0.0
	for j in cards.size():
		if j != i:
			_shatter_card(j)
	chosen_card = c
	arrived = false


func show_replace(c: Dictionary) -> void:
	rep_card = c
	rep_t = 0.0


func replace_done() -> void:
	rep_t = -1.0
	rep_card = {}


func crack_break(n: int) -> void:
	_ensure_cracks()
	if n >= 0 and n < crack_anim.size():
		crack_anim[n] = 1.0
		var vp := view.get_viewport_rect().size
		var c := Vector2(vp.x / 2.0 - 230.0, vp.y - 60.0) + Vector2(n * 24.0, 0)
		var pts := [Vector2(0, -9), Vector2(5.6, 0), Vector2(0, 9), Vector2(-5.6, 0)]
		for e in 4:
			var a: Vector2 = pts[e]
			var b: Vector2 = pts[(e + 1) % 4]
			var mid := (a + b) * 0.5
			ui_shards.append([c + mid, a - mid, b - mid, mid.normalized() * randf_range(120, 260) + Vector2(0, -260), 0.0, randf_range(-14, 14), 0.0, true])
		slot_rings.append([c, 0.0, true])


func crack_mend(n: int) -> void:
	_ensure_cracks()
	for i in n:
		if i >= cracks_shown:
			crack_anim[i] = -1.0
			var vp := view.get_viewport_rect().size
			mend_rings.append([Vector2(vp.x / 2.0 - 230.0, vp.y - 60.0) + Vector2(i * 24.0, 0), -0.04 * (i - cracks_shown)])
	cracks_shown = n


func _ensure_cracks() -> void:
	if crack_anim.size() != game.max_cracks:
		crack_anim.resize(game.max_cracks)
		for i in crack_anim.size():
			if crack_anim[i] == null:
				crack_anim[i] = 0.0


func flash_text(txt: String, world = null) -> void:
	flashes.append([txt, world, 0.0])


func game_over() -> void:
	over_t = 0.0


func chapter_intro() -> void:
	intro_t = 0.0


func _card_center(i: int, vp: Vector2) -> Vector2:
	var n := cards.size()
	return Vector2(vp.x / 2.0 + (i - (n - 1) / 2.0) * CARD_GAP, vp.y * 0.48)


func card_at(p: Vector2) -> int:
	if cards_t < 0.0 or chosen >= 0:
		return -1
	var vp := view.get_viewport_rect().size
	for i in cards.size():
		if Rect2(_card_center(i, vp) - CARD / 2.0, CARD).has_point(p):
			return i
	return -1


func _reroll_rect(vp: Vector2) -> Rect2:
	return Rect2(vp.x / 2.0 - 90.0, vp.y * 0.48 + CARD.y / 2.0 + 30.0, 180.0, 40.0)


func reroll_hit(p: Vector2) -> bool:
	return cards_t >= 0.0 and chosen < 0 and _reroll_rect(view.get_viewport_rect().size).has_point(p)


# Bottom-right: schools on the lower row, relics above.
func _school_slot_i(i: int, vp: Vector2) -> Vector2:
	return Vector2(vp.x - 96.0 - (Cards.SCHOOL_SLOTS - 1 - i) * 62.0, vp.y - 58.0)


func _relic_slot_i(i: int, vp: Vector2) -> Vector2:
	return Vector2(vp.x - 78.0 - (Cards.RELIC_SLOTS - 1 - i) * (SLOT + 8.0), vp.y - 128.0)


func _held_schools() -> Array:
	var out: Array = []
	for k in Cards.SCHOOLS:
		if game.lv.get(k, 0) > 0:
			out.append(k)
	return out


func _fly_target(c: Dictionary, vp: Vector2) -> Vector2:
	if c.type == "school":
		var held := _held_schools()
		var i := held.find(c.id)
		return _school_slot_i(maxi(0, i if i >= 0 else held.size()), vp)
	if c.type == "relic":
		var j: int = game.relics.find(c.id)
		return _relic_slot_i(maxi(0, j if j >= 0 else game.relics.size()), vp)
	return Vector2(vp.x / 2.0 - 160.0, vp.y - 50.0)


# j index under the cursor in the replace row; -1 = "keep mine"; -2 = nothing
func replace_at(p: Vector2) -> int:
	if rep_t < 0.0:
		return -2
	var vp := view.get_viewport_rect().size
	var n := _rep_count()
	for j in n:
		if Rect2(_rep_center(j, n, vp) - Vector2(80, 90), Vector2(160, 180)).has_point(p):
			return j
	if Rect2(vp.x / 2.0 - 120.0, vp.y * 0.5 + 150.0, 240.0, 40.0).has_point(p):
		return -1
	return -2


func _rep_count() -> int:
	return _held_schools().size() if rep_card.get("type", "") == "school" else game.relics.size()


func _rep_center(j: int, n: int, vp: Vector2) -> Vector2:
	return Vector2(vp.x / 2.0 + (j - (n - 1) / 2.0) * 190.0, vp.y * 0.5 + 20.0)


func _step_cards(dt: float) -> void:
	for k in school_pop:
		school_pop[k] = maxf(0.0, school_pop[k] - dt / 0.6)
	for k in relic_pop:
		relic_pop[k] = maxf(0.0, relic_pop[k] - dt / 0.6)
	_ensure_cracks()
	for i in crack_anim.size():
		if crack_anim[i] > 0.0:
			crack_anim[i] = maxf(0.0, crack_anim[i] - dt / 0.6)
		elif crack_anim[i] < 0.0:
			crack_anim[i] = minf(0.0, crack_anim[i] + dt / 0.6)
	cracks_shown = game.cracks
	var i2 := 0
	while i2 < flashes.size():
		flashes[i2][2] += dt
		if flashes[i2][2] > 1.4:
			flashes.remove_at(i2)
		else:
			i2 += 1
	if over_t >= 0.0:
		over_t += dt
	if intro_t >= 0.0:
		intro_t += dt
		if intro_t > 2.8:
			intro_t = -1.0
	if rep_t >= 0.0:
		rep_t += dt
		rep_hover = replace_at(reticle)
	if cards_t < 0.0:
		return
	cards_t += dt
	hover = card_at(reticle)
	for i in 3:
		hover_k[i] = Pal.damp(hover_k[i], 1.0 if i == hover else 0.0, 14.0, dt)
	reroll_k = Pal.damp(reroll_k, 1.0 if reroll_hit(reticle) else 0.0, 14.0, dt)
	if chosen >= 0:
		chosen_t += dt
		if chosen_t > 0.9:
			cards_t = -1.0
			cards.clear()


# A small animated glyph per school.
func _icon(key: String, c: Vector2, r: float, t: float, col: Color, w: float = 2.0) -> void:
	match key:
		"bounce":
			var pts := PackedVector2Array([c + Vector2(-r, -r * 0.7), c + Vector2(-r * 0.3, r * 0.7), c + Vector2(r * 0.35, -r * 0.7), c + Vector2(r, r * 0.7)])
			view.draw_polyline(pts, col, w, false)
			var f := fmod(t * 0.8, 1.0) * 3.0
			var seg := int(f)
			var p := pts[seg].lerp(pts[seg + 1], f - seg)
			view.draw_circle(p, w * 1.6, Pal.red(1.0, 2.2))
		"split":
			var root := c + Vector2(-r, 0)
			var mid := c + Vector2(-r * 0.1, 0)
			view.draw_line(root, mid, col, w)
			for a in [-0.55, 0.55]:
				view.draw_line(mid, mid + Vector2.from_angle(a) * r * 1.05, col, w)
			var f2 := fmod(t * 0.9, 1.0)
			if f2 < 0.45:
				view.draw_circle(root.lerp(mid, f2 / 0.45), w * 1.6, Pal.red(1.0, 2.2))
			else:
				for a in [-0.55, 0.55]:
					view.draw_circle(mid + Vector2.from_angle(a) * r * 1.05 * (f2 - 0.45) / 0.55, w * 1.3, Pal.red(1.0, 2.2))
		"chain":
			# a jagged arc hopping between two dots
			var f9 := fmod(t * 1.2, 1.0)
			var pa := c + Vector2(-r, r * 0.4)
			var pb := c + Vector2(r, -r * 0.4)
			view.draw_circle(pa, w * 1.6, col)
			view.draw_circle(pb, w * 1.6, col)
			if f9 < 0.6:
				var z := PackedVector2Array([pa, pa.lerp(pb, 0.33) + Vector2(0, -r * 0.4), pa.lerp(pb, 0.66) + Vector2(0, r * 0.4), pb])
				view.draw_polyline(z, Pal.red(1.0 - f9 / 0.6, 2.2), w, false)
		"shadow":
			# a line, and its ghost a beat behind
			var f8 := fmod(t * 0.9, 1.0)
			view.draw_line(c + Vector2(-r, -r * 0.3), c + Vector2(r, -r * 0.3), col, w)
			view.draw_circle(c + Vector2(lerpf(r, -r, f8), -r * 0.3), w * 1.5, Pal.red(1.0, 2.2))
			view.draw_line(c + Vector2(-r, r * 0.3), c + Vector2(r, r * 0.3), Color(col.r, col.g, col.b, col.a * 0.4), w)
			view.draw_circle(c + Vector2(lerpf(r, -r, maxf(0.0, f8 - 0.2)), r * 0.3), w * 1.2, Pal.ink(0.5))
		"charge":
			# an hourglass that fills
			var f7 := fmod(t * 0.4, 1.0)
			var top := PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r * 0.6, -r), c, c + Vector2(-r * 0.6, -r)])
			var bot := PackedVector2Array([c, c + Vector2(r * 0.6, r), c + Vector2(-r * 0.6, r), c])
			view.draw_polyline(top, col, w, false)
			view.draw_polyline(bot, col, w, false)
			view.draw_rect(Rect2(c + Vector2(-r * 0.45 * f7, r - r * 0.8 * f7), Vector2(r * 0.9 * f7, r * 0.8 * f7)), Pal.red(1.0, 2.2))
		"blast":
			# a round coming home, then a burst
			var f4 := fmod(t * 0.8, 1.0)
			if f4 < 0.55:
				view.draw_line(c + Vector2(-r, 0), c + Vector2(-r + r * 2.0 * f4 / 0.55, 0), col, w)
				view.draw_circle(c + Vector2(-r + r * 2.0 * f4 / 0.55, 0), w * 1.5, Pal.red(1.0, 2.2))
			else:
				var k5 := (f4 - 0.55) / 0.45
				view.draw_arc(c + Vector2(r, 0) * 0.4, r * 0.9 * Pal.ease_out(k5), 0.0, TAU, 20, Pal.red(1.0 - k5, 2.2), w, false)
				for j in 6:
					var d6 := Vector2.from_angle(TAU * j / 6.0)
					view.draw_line(c + Vector2(r, 0) * 0.4 + d6 * r * 0.3, c + Vector2(r, 0) * 0.4 + d6 * r * (0.3 + 0.5 * k5), col, w)
		"magnet":
			# a horseshoe, with motes drawn in between its arms
			view.draw_arc(c + Vector2(0, r * 0.1), r * 0.6, 0.0, PI, 20, col, w, false)
			view.draw_line(c + Vector2(-r * 0.6, r * 0.1), c + Vector2(-r * 0.6, -r * 0.7), col, w)
			view.draw_line(c + Vector2(r * 0.6, r * 0.1), c + Vector2(r * 0.6, -r * 0.7), col, w)
			for k in 2:
				var f3 := fmod(t * 0.7 + k * 0.5, 1.0)
				view.draw_circle(c + Vector2((k - 0.5) * r * 0.5, lerpf(-r * 1.2, -r * 0.2, Pal.ease_in(f3))), w * 1.3, Pal.red(1.0, 2.2))
		_:
			view.draw_circle(c, r * 0.28, col)
			view.draw_arc(c, r * 0.85, 0.0, TAU, 40, Color(col.r, col.g, col.b, col.a * 0.35), 1.0, false)
			for k in 3:
				view.draw_circle(c + Vector2.from_angle(t * 2.6 + TAU * k / 3.0) * r * 0.85, w * 1.4, Pal.red(1.0, 2.2))


# Relic glyphs are built from the id: an outer polygon, an inner mark and a
# slow turn. Distinct at a glance, quiet enough for the HUD.
func _glyph(id: String, c: Vector2, r: float, col: Color, w: float = 1.6) -> void:
	var h := id.hash()
	var sides := 3 + absi(h) % 4
	var mark := (absi(h) / 7) % 4
	var turn: float = game.real_time * (0.25 if (absi(h) / 31) % 2 == 0 else -0.25)
	var pts := PackedVector2Array()
	for k in sides + 1:
		pts.append(c + Vector2.from_angle(turn + TAU * k / sides - PI / 2.0) * r)
	view.draw_polyline(pts, col, w, false)
	match mark:
		0:
			view.draw_circle(c, r * 0.22, col)
		1:
			view.draw_line(c - Vector2(r * 0.4, 0), c + Vector2(r * 0.4, 0), col, w)
			view.draw_line(c - Vector2(0, r * 0.4), c + Vector2(0, r * 0.4), col, w)
		2:
			view.draw_arc(c, r * 0.4, 0.0, TAU, 20, col, w, false)
		_:
			view.draw_line(c + Vector2.from_angle(-turn) * r * 0.5, c - Vector2.from_angle(-turn) * r * 0.5, col, w * 1.4)


func _item_glyph(c: Vector2, r: float, col: Color, w: float = 1.6) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0), c + Vector2(0, -r)])
	view.draw_polyline(pts, col, w, false)
	view.draw_circle(c, r * 0.18 * (1.0 + 0.3 * sin(game.real_time * 5.0)), col)


# Rarity is told by the frame alone: one line, two lines, or a heavy frame
# with corner ticks.
func _frame(r: Rect2, rarity: int, a: float, hov: float) -> void:
	view.draw_rect(r, Color(0.03, 0.03, 0.035, 0.96 * a))
	view.draw_rect(r, Pal.ink((0.55 + 0.4 * hov) * a, 1.0 + (0.3 if rarity == 2 else 0.0)), false, 1.5 if rarity < 2 else 2.5)
	if rarity >= 1:
		view.draw_rect(r.grow(-6), Pal.ink(0.45 * a), false, 1.0)
	else:
		view.draw_rect(r.grow(-8), Pal.ink(0.1 * a), false, 1.0)
	if rarity == 2:
		var l := 18.0
		for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx := 1.0 if p.x < r.get_center().x else -1.0
			var sy := 1.0 if p.y < r.get_center().y else -1.0
			view.draw_line(p + Vector2(-4 * sx, -4 * sy), p + Vector2(l * sx, -4 * sy), Pal.ink(0.9 * a, 1.3), 2.0)
			view.draw_line(p + Vector2(-4 * sx, -4 * sy), p + Vector2(-4 * sx, l * sy), Pal.ink(0.9 * a, 1.3), 2.0)
		# a slow glint runs round the frame
		var g := fmod(game.real_time * 0.35, 1.0)
		var per := 2.0 * (r.size.x + r.size.y)
		var d := g * per
		var gp := r.position
		if d < r.size.x:
			gp = r.position + Vector2(d, 0)
		elif d < r.size.x + r.size.y:
			gp = Vector2(r.end.x, r.position.y + d - r.size.x)
		elif d < 2.0 * r.size.x + r.size.y:
			gp = Vector2(r.end.x - (d - r.size.x - r.size.y), r.end.y)
		else:
			gp = Vector2(r.position.x, r.end.y - (d - 2.0 * r.size.x - r.size.y))
		view.draw_circle(gp, 3.0, Pal.ink(a, 2.4))


func _card_face(c: Dictionary, r: Rect2, a: float, hov: float, idx: int) -> void:
	var rarity := 0
	var kind := ""
	var title := ""
	var desc := ""
	match c.type:
		"school":
			kind = Txt.t("card_school") + " · " + (Txt.t("card_new") if c.level == 0 else "Lv %d" % (c.level + 1))
			title = Txt.t("sch_" + c.id)
			desc = Txt.t("up_%s_%d" % [c.id, c.level + 1])
		"relic":
			rarity = Cards.RELICS[c.id][0]
			kind = Txt.t("card_relic") + " · " + Txt.t(["rar_0", "rar_1", "rar_2"][rarity])
			title = Cards.relic_name(c.id)
			desc = Cards.relic_desc(c.id)
		_:
			kind = Txt.t("card_item")
			title = Cards.item_name(c.id)
			desc = Cards.item_desc(c.id)
	_frame(r, rarity, a, hov)
	_text_c(font_s, kind, Vector2(0, r.position.y + 34.0), 14, Pal.ink(0.55 * a))
	var ic := Pal.ink(a, 1.0 + 0.4 * hov)
	match c.type:
		"school":
			_icon(c.id, Vector2(0, -80), 40.0, game.real_time + idx, ic, 3.0)
			for j in 3:
				var on: bool = j < c.level
				var pc := Pal.ink(0.8 * a) if on else Pal.ink(0.15 * a)
				if j == c.level:
					pc = Pal.red(a * (0.6 + 0.4 * sin(game.real_time * 6.0)), 2.2)
				view.draw_rect(Rect2(Vector2(-40 + j * 30, 42), Vector2(20, 4)), pc)
		"relic":
			_glyph(c.id, Vector2(0, -80), 40.0, ic, 2.5)
		_:
			_item_glyph(Vector2(0, -80), 38.0, ic, 2.5)
	_text_c(font_xl, title, Vector2(0, 22), 28, Pal.ink(a))
	var y := 88.0
	for ln in _wrap(desc, 16, CARD.x - 56.0):
		_text_c(font_s, ln, Vector2(0, y), 16, Pal.ink(0.78 * a))
		y += 24.0
	if c.get("full", false) or (c.type == "relic" and game.relics.size() >= Cards.RELIC_SLOTS):
		_text_c(font_s, Txt.t("card_full"), Vector2(0, CARD.y / 2.0 - 50.0), 13, Pal.ink(0.5 * a))
	_text_c(font_b, str(idx + 1), Vector2(0, CARD.y / 2.0 - 22.0), 18, Pal.ink((0.35 + 0.4 * hov) * a))


# The chosen card's path: up and over, then down into its slot.
func _arc(from: Vector2, to: Vector2, t: float) -> Vector2:
	var ctrl := Vector2(lerpf(from.x, to.x, 0.35), minf(from.y, to.y) - 220.0)
	return from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t)


func _arc_rot(from: Vector2, to: Vector2, t: float) -> float:
	return sin(t * PI) * 0.4 * signf(to.x - from.x + 0.001)


func _arrive(c: Dictionary, at: Vector2) -> void:
	arrived = true
	if c.type == "school":
		school_pop[c.id] = 1.0
	elif c.type == "relic":
		relic_pop[c.id] = 1.0
	slot_rings.append([at, 0.0])
	game.sfx.play("tick", 1.5, -5.0)


# ---------------------------------------------------------------- what a slot means
# Point the reticle at a relic or school slot and a card rises with its name and
# what it does; the pause screen lists the whole build the same way.

var tip_key := ""
var tip_s := Motion.Spring.new(0.0, 380.0, 0.72)
var tip_at := Vector2.ZERO


func _tip_under(p: Vector2, vp: Vector2) -> String:
	for i in game.relics.size():
		if Rect2(_relic_slot_i(i, vp) - Vector2(SLOT, SLOT) / 2.0, Vector2(SLOT, SLOT)).grow(4.0).has_point(p):
			return "relic:" + game.relics[i]
	var held := _held_schools()
	for i in held.size():
		if Rect2(_school_slot_i(i, vp) - Vector2(26, 22), Vector2(52, 52)).has_point(p):
			return "school:" + held[i]
	return ""


func _step_tip(dt: float, vp: Vector2) -> void:
	var k := ""
	if cards_t < 0.0 and rep_t < 0.0 and not paused:
		k = _tip_under(reticle, vp)
	if k != "":
		if k != tip_key:
			tip_s.x = minf(tip_s.x, 0.4)
		tip_key = k
		tip_at = reticle
	tip_s.target = 1.0 if k != "" else 0.0
	tip_s.step(dt)


func _tip_lines(key: String) -> Array:
	# [title, kind line, description, rarity]
	var id := key.split(":")[1]
	if key.begins_with("relic:"):
		var rar: int = Cards.RELICS[id][0]
		return [Cards.relic_name(id), Txt.t("card_relic") + " · " + Txt.t(["rar_0", "rar_1", "rar_2"][rar]), Cards.relic_desc(id), rar]
	var lvl: int = game.lv.get(id, 0)
	var parts: PackedStringArray = []
	for n in range(1, maxi(1, lvl) + 1):
		parts.append(Txt.t("up_%s_%d" % [id, n]))
	return [Txt.t("sch_" + id) + "  Lv%d" % lvl, Txt.t("card_school"), ("；" if Txt.zh else "; ").join(parts), 0]


func _draw_tip(vp: Vector2) -> void:
	if tip_s.x <= 0.01 or tip_key == "":
		return
	var a := clampf(tip_s.x, 0.0, 1.0)
	var L := _tip_lines(tip_key)
	var w := 360.0
	var lines := _wrap(L[2], 15, w - 36.0)
	var h := 92.0 + lines.size() * 22.0
	var pos := Vector2(clampf(tip_at.x - w + 40.0, 20.0, vp.x - w - 20.0), tip_at.y - h - 34.0)
	var k := 0.94 + 0.06 * tip_s.x
	view.draw_set_transform(pos + Vector2(w, h), 0.0, Vector2(k, k))
	var r := Rect2(-Vector2(w, h), Vector2(w, h)).grow(0) 
	r.position.y += (1.0 - a) * 14.0
	view.draw_rect(r, Color(0.03, 0.03, 0.035, a))
	var rar: int = L[3]
	view.draw_rect(r, (Pal.red(a, 1.6) if rar == 2 else Pal.ink((0.3 + 0.2 * rar) * a)), false, 1.0 if rar < 2 else 2.0)
	view.draw_line(r.position + Vector2(0, 0), r.position + Vector2(18, 0), Pal.red(a, 2.0), 2.0)
	view.draw_line(r.position, r.position + Vector2(0, 18), Pal.red(a, 2.0), 2.0)
	view.draw_string(font_s, r.position + Vector2(18, 28), L[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * a))
	view.draw_string(font_xl, r.position + Vector2(18, 58), L[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(a))
	var y := r.position.y + 88.0
	for ln in lines:
		view.draw_string(font_s, Vector2(r.position.x + 18.0, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.8 * a))
		y += 22.0
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_build(vp: Vector2, a: float) -> void:
	# the pause screen's right column: every school and relic with what it does
	var x := vp.x - 470.0
	var y := vp.y * 0.2
	var i := 0
	view.draw_string(font_b, Vector2(x, y), Txt.t("build_title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.red(a, 1.6))
	y += 30.0
	var entries: Array = []
	for k in _held_schools():
		entries.append("school:" + k)
	for id in game.relics:
		entries.append("relic:" + id)
	if entries.is_empty():
		view.draw_string(font_s, Vector2(x, y), Txt.t("build_empty"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.45 * a))
		return
	for key in entries:
		var ki := Pal.ease_out(Motion.stagger(pause_t, i, 0.04, 0.35)) if paused else 1.0
		var ea := a * ki
		var L := _tip_lines(key)
		var dx := (1.0 - ki) * 30.0
		view.draw_string(font_xl, Vector2(x + dx, y), L[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, (Pal.red(ea, 1.6) if L[3] == 2 else Pal.ink(ea)))
		y += 22.0
		for ln in _wrap(L[2], 13, 430.0):
			view.draw_string(font_s, Vector2(x + dx, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.6 * ea))
			y += 19.0
		y += 10.0
		i += 1


func _draw_slots(vp: Vector2) -> void:
	for sr in slot_rings:
		var e := Pal.ease_out(sr[1] / 0.5)
		var ra := 1.0 - e
		var sp: Vector2 = sr[0]
		if sr.size() > 2:
			view.draw_arc(sp, lerpf(8.0, 40.0, e), 0.0, TAU, 32, Pal.red(0.9 * ra, 2.6), 2.0, false)
			view.draw_circle(sp, 14.0 * ra, Pal.red(0.25 * ra, 2.0))
			continue
		view.draw_arc(sp, lerpf(10.0, 46.0, e), 0.0, TAU, 32, Pal.ink(0.8 * ra, 1.8), 1.5, false)
		view.draw_arc(sp, lerpf(6.0, 28.0, Pal.ease_out(minf(1.0, sr[1] / 0.35))), 0.0, TAU, 24, Pal.red(0.7 * ra, 2.2), 1.0, false)
		var pts := PackedVector2Array()
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0 + 0.2)
			pts.append(sp + d * lerpf(14.0, 40.0, e))
			pts.append(sp + d * lerpf(18.0, 56.0, e))
		view.draw_multiline(pts, Pal.ink(0.6 * ra, 1.6), 1.0)
	var held := _held_schools()
	for i in Cards.SCHOOL_SLOTS:
		var sp := _school_slot_i(i, vp)
		if i < held.size():
			var k: String = held[i]
			var pop: float = _pop(school_pop.get(k, 0.0))
			_icon(k, sp, 12.0 * (1.0 + 0.4 * pop), game.real_time, Pal.ink(0.85, 1.0 + 0.8 * pop), 1.6)
			for j in 3:
				view.draw_rect(Rect2(sp + Vector2(-13 + j * 10, 22), Vector2(6, 3)), Pal.ink(0.8 if j < game.lv[k] else 0.15))
		else:
			view.draw_arc(sp, 4.0, 0.0, TAU, 12, Pal.ink(0.12), 1.0, false)
	for i in Cards.RELIC_SLOTS:
		var rp := _relic_slot_i(i, vp)
		var rr := Rect2(rp - Vector2(SLOT, SLOT) / 2.0, Vector2(SLOT, SLOT))
		if i < game.relics.size():
			var id: String = game.relics[i]
			var pop2: float = _pop(relic_pop.get(id, 0.0))
			var rar: int = Cards.RELICS[id][0]
			view.draw_rect(rr.grow(pop2 * 4.0), Pal.ink(0.5 + 0.3 * rar * 0.5, 1.0 + pop2), false, 1.0 + rar * 0.6)
			_glyph(id, rp, 11.0 * (1.0 + 0.3 * pop2), Pal.ink(0.85, 1.0 + 0.8 * pop2), 1.3)
		else:
			view.draw_rect(rr, Pal.ink(0.1), false, 1.0)
	# armed items wait beside the ammo
	var ax := vp.x / 2.0 - 150.0
	for k in ["overload", "firststrike", "stasis", "ward", "longhold", "slowfield", "tempo", "haste", "calm_mind"]:
		if game.armed.get(k, false):
			var pulse := 0.6 + 0.4 * sin(game.real_time * 5.0)
			_item_glyph(Vector2(ax, vp.y - 58.0), 10.0, Pal.ink(pulse, 1.3), 1.4)
			ax -= 30.0


# 1 -> 0 timer into a pop that swells, overshoots below rest and settles.
func _pop(t: float) -> float:
	if t <= 0.0:
		return 0.0
	var e := 1.0 - t
	return exp(-6.0 * e) * cos(e * 11.0) * minf(1.0, e * 12.0 + 0.4)


func _draw_cracks(vp: Vector2) -> void:
	_ensure_cracks()
	if Settings.assist:
		_text_c(font_s, Txt.t("a_hud") % [Settings.damage_reduction, maxi(0, Settings.retry_limit - game.assist_retries_used)], Vector2(vp.x / 2.0, vp.y - 100.0), 14, Pal.ink(0.65))
	for mr in mend_rings:
		if mr[1] < 0.0:
			continue
		var e := Pal.ease_in(minf(1.0, mr[1] / 0.4))
		view.draw_arc(mr[0], lerpf(34.0, 6.0, e), 0.0, TAU, 28, Pal.ink(0.7 * e, 1.8), 1.5, false)
	var base := Vector2(vp.x / 2.0 - 230.0, vp.y - 60.0)
	for i in game.max_cracks:
		var c := base + Vector2(i * 24.0, 0)
		var whole: bool = i < game.cracks
		var k: float = crack_anim[i]
		var s := 9.0
		if k > 0.0:
			# breaking: two halves drift apart and fade
			var e := 1.0 - k
			for side in [-1.0, 1.0]:
				var off := Vector2(side * 6.0 * Pal.ease_out(e), 4.0 * e * e)
				var half := PackedVector2Array([c + off + Vector2(0, -s), c + off + Vector2(side * s * 0.6, 0), c + off + Vector2(0, s), c + off + Vector2(0, -s)])
				view.draw_polyline(half, Pal.ink(k, 1.6), 1.6, false)
			continue
		var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.62, 0), c + Vector2(0, s), c + Vector2(-s * 0.62, 0)])
		if whole:
			var mend := -k
			view.draw_colored_polygon(pts, Pal.ink(0.85, 1.0 + 1.5 * mend))
		else:
			pts.append(pts[0])
			view.draw_polyline(pts, Pal.ink(0.18), 1.0, false)


func _draw_cards(vp: Vector2) -> void:
	if game.tutorial == null:
		_draw_slots(vp)
	_draw_cracks(vp)
	_draw_flashes(vp)
	_draw_intro(vp)
	_draw_replace(vp)
	_draw_over(vp)
	if cards_t < 0.0:
		return
	var t := cards_t
	var dim := Pal.ease_out(t / 0.4)
	if chosen >= 0:
		dim *= 1.0 - Pal.ease_in(clampf((chosen_t - 0.3) / 0.5, 0.0, 1.0))
	view.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.45 * dim))
	for i in cards.size():
		var c: Dictionary = cards[i]
		var cc := _card_center(i, vp) + Vector2(0, card_y[i].x if i < card_y.size() else 0.0)
		# springs up from below, opening from a sliver, staggered left to right
		# each card is released a beat after the one before it
		if i < card_y.size():
			card_y[i].target = 0.0 if t >= 0.06 * i else card_y[i].x
		var fin := Pal.back(clampf((t - 0.05 - i * 0.07) / 0.3, 0.0, 1.0), 1.4)
		var sx := fin
		var a := clampf(fin * 1.5, 0.0, 1.0)
		var lift: float = -hover_k[i] * 14.0
		var rot := (1.0 - fin) * 0.25 * (i - 1)
		var sc: float = 1.0 + hover_k[i] * 0.03
		if chosen >= 0:
			if i == chosen:
				# swell, then fly into its slot
				var ct := chosen_t
				var swell := 1.0 + 0.08 * sin(clampf(ct / 0.2, 0.0, 1.0) * PI)
				var fly := Pal.ease_io(clampf((ct - 0.18) / 0.5, 0.0, 1.0))
				var from := cc
				var to := _fly_target(c, vp)
				# trail: the frame's ghosts a few steps behind along the arc
				if fly > 0.0 and fly < 1.0:
					for g in range(5, 0, -1):
						var fg := Pal.ease_io(clampf((ct - 0.18 - g * 0.022) / 0.5, 0.0, 1.0))
						if fg <= 0.0:
							continue
						var gp := _arc(from, to, fg)
						var gs := lerpf(1.0, 0.08, fg)
						var gr := (1.0 - g / 6.0)
						view.draw_set_transform(gp, _arc_rot(from, to, fg), Vector2(gs, gs))
						view.draw_rect(Rect2(-CARD / 2.0, CARD), Pal.ink(0.14 * gr * (1.0 - fly), 1.4), false, 1.5 / maxf(gs, 0.15))
					view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				cc = _arc(from, to, fly)
				rot += _arc_rot(from, to, fly)
				sc = swell * lerpf(1.0, 0.08, fly)
				lift = 0.0
				a = 1.0 - Pal.ease_in(clampf((ct - 0.55) / 0.15, 0.0, 1.0))
				if fly >= 1.0 and not arrived:
					_arrive(c, to)
			else:
				# the cards you passed over have broken into their edges
				continue
		if sx <= 0.01 or a <= 0.01:
			continue
		var tl: Vector2 = card_tilt[i].x if i < card_tilt.size() else Vector2.ZERO
		var xf := Transform2D(rot + tl.x * 0.035, Vector2(sx * sc * (1.0 - absf(tl.x) * 0.04), sc * (1.0 - absf(tl.y) * 0.03)), -tl.x * 0.08, cc + Vector2(0, lift))
		view.draw_set_transform_matrix(xf)
		_card_face(c, Rect2(-CARD / 2.0, CARD), a, hover_k[i], i)
		# one pass of light across each card as it settles
		var st := (t - 0.32 - i * 0.07) / 0.5
		if st > 0.0 and st < 1.0 and chosen < 0:
			var sx3 := lerpf(-CARD.x / 2.0 + 44.0, CARD.x / 2.0 - 44.0, Pal.ease_io(st))
			_sheen(sx3, sin(st * PI))
		if hover_k[i] > 0.02 and chosen < 0:
			_edge_light(xf.affine_inverse() * reticle, Rect2(-CARD / 2.0, CARD), hover_k[i])
		if hover_k[i] > 0.02:
			# a soft sheen that follows the cursor across the face
			var sx2 := tl.x * CARD.x * 0.45
			_sheen(sx2, hover_k[i] * 0.6)
		view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# reroll
	if chosen < 0:
		var rr := _reroll_rect(vp)
		var ra := Pal.ease_out((t - 0.4) / 0.3) * (1.0 if game.rerolls > 0 else 0.35)
		view.draw_rect(rr, Pal.ink((0.25 + 0.5 * reroll_k) * ra), false, 1.0)
		_text_c(font_s, "T  %s  · %d" % [Txt.t("reroll"), game.rerolls], rr.get_center() + Vector2(0, 6), 15, Pal.ink((0.6 + 0.3 * reroll_k) * ra))


# A slanted streak of light across a card face: a soft wide wash, a narrower
# core and a hairline, so it reads as glass catching light, not a grey bar.
func _sheen(x: float, k: float) -> void:
	var a0 := Vector2(x - 30.0, -CARD.y / 2.0 + 3.0)
	var a1 := Vector2(x + 30.0, CARD.y / 2.0 - 3.0)
	view.draw_line(a0, a1, Pal.ink(0.018 * k), 34.0)
	view.draw_line(a0, a1, Pal.ink(0.03 * k), 12.0)
	view.draw_line(a0 + Vector2(4, 0), a1 + Vector2(4, 0), Pal.ink(0.35 * k, 1.5), 1.2)


# The frame catches the light nearest the cursor: a bright point on the edge
# that bleeds a short way along it.
func _edge_light(local: Vector2, r: Rect2, k: float) -> void:
	var q := local.clamp(r.position, r.end)
	var dl := q.x - r.position.x
	var dr := r.end.x - q.x
	var dt := q.y - r.position.y
	var db := r.end.y - q.y
	var m := minf(minf(dl, dr), minf(dt, db))
	var along := Vector2(0, 1)
	if m == dl:
		q.x = r.position.x
	elif m == dr:
		q.x = r.end.x
	elif m == dt:
		q.y = r.position.y
		along = Vector2(1, 0)
	else:
		q.y = r.end.y
		along = Vector2(1, 0)
	for j in 3:
		var l: float = [70.0, 36.0, 14.0][j]
		var a0 := q - along * l
		var a1 := q + along * l
		a0 = a0.clamp(r.position, r.end)
		a1 = a1.clamp(r.position, r.end)
		view.draw_line(a0, a1, Pal.ink([0.18, 0.4, 0.9][j] * k, 1.0 + j * 0.8), 2.0)


func _draw_replace(vp: Vector2) -> void:
	if rep_t < 0.0:
		return
	var a := Pal.ease_out(rep_t / 0.3)
	view.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6 * a))
	var is_school: bool = rep_card.type == "school"
	var new_name: String = Txt.t("sch_" + rep_card.id) if is_school else Cards.relic_name(rep_card.id)
	_text_c(font_xl, Txt.t("replace_q") % new_name, Vector2(vp.x / 2.0, vp.y * 0.5 - 140.0), 30, Pal.ink(a))
	var held := _held_schools()
	var n := _rep_count()
	for j in n:
		var c := _rep_center(j, n, vp)
		var k := Pal.back(clampf((rep_t - j * 0.05) / 0.3, 0.0, 1.0))
		var hov := 1.0 if rep_hover == j else 0.0
		var r := Rect2(c - Vector2(80, 90) * k - Vector2(0, hov * 8.0), Vector2(160, 180) * k)
		if k <= 0.02:
			continue
		var rar := 0
		var title := ""
		if is_school:
			title = Txt.t("sch_" + held[j]) + "  Lv%d" % game.lv[held[j]]
		else:
			rar = Cards.RELICS[game.relics[j]][0]
			title = Cards.relic_name(game.relics[j])
		_frame(r, rar, a, hov)
		if is_school:
			_icon(held[j], r.get_center() + Vector2(0, -24), 26.0 * k, game.real_time, Pal.ink(a), 2.0)
		else:
			_glyph(game.relics[j], r.get_center() + Vector2(0, -24), 26.0 * k, Pal.ink(a), 2.0)
		_text_c(font_s, title, r.get_center() + Vector2(0, 38), 15, Pal.ink(a))
		_text_c(font_b, str(j + 1), r.get_center() + Vector2(0, 70), 15, Pal.ink(0.5 * a))
	var keep := Rect2(vp.x / 2.0 - 120.0, vp.y * 0.5 + 150.0, 240.0, 40.0)
	view.draw_rect(keep, Pal.ink((0.25 + (0.5 if rep_hover == -1 else 0.0)) * a), false, 1.0)
	_text_c(font_s, "0  " + Txt.t("replace_keep"), keep.get_center() + Vector2(0, 6), 15, Pal.ink(0.7 * a))


func _draw_flashes(vp: Vector2) -> void:
	for fl in flashes:
		var t: float = fl[2]
		var a := clampf(t / 0.1, 0.0, 1.0) * (1.0 - Pal.ease_in(clampf((t - 0.9) / 0.5, 0.0, 1.0)))
		var k := lerpf(1.6, 1.0, Pal.back(clampf(t / 0.2, 0.0, 1.0)))
		var p := Vector2(vp.x / 2.0, vp.y * 0.34)
		if fl[1] != null:
			p = game.get_viewport().get_canvas_transform() * (fl[1] as Vector2) + Vector2(0, -40.0 - t * 30.0)
		view.draw_set_transform(p, 0.0, Vector2(k, k))
		_text_c(font_b, fl[0], Vector2(0, 8), 22, Pal.ink(a, 1.5))
		view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_intro(vp: Vector2) -> void:
	if intro_t < 0.0:
		return
	var t := intro_t
	var a := clampf(t / 0.3, 0.0, 1.0) * (1.0 - Pal.ease_in(clampf((t - 2.2) / 0.6, 0.0, 1.0)))
	var cy := vp.y * 0.4
	var w := 520.0 * Pal.ease_out(t / 0.7)
	view.draw_line(Vector2(vp.x / 2.0 - w / 2.0, cy + 34.0), Vector2(vp.x / 2.0 + w / 2.0, cy + 34.0), Pal.ink(0.5 * a), 1.0)
	_text_c(font_s, Txt.t("chapter_n") % (game.chapter + 1), Vector2(vp.x / 2.0, cy - 48.0), 16, Pal.ink(0.55 * a))
	var rise := (1.0 - Pal.ease_out(clampf((t - 0.15) / 0.6, 0.0, 1.0))) * 20.0
	_text_stagger(font_xl, Txt.t("chapter_%d" % (game.chapter + 1)), Vector2(vp.x / 2.0, cy + 10.0), 60, Pal.ink(1.0, 1.15), t - 0.15, t - 2.15, 0.05)
	_text_c(font_s, Txt.t("chapter_%d_sub" % (game.chapter + 1)), Vector2(vp.x / 2.0, cy + 70.0), 16, Pal.ink(0.6 * a * clampf((t - 0.5) / 0.4, 0.0, 1.0)))


func _draw_over(vp: Vector2) -> void:
	if over_t < 0.0:
		return
	var t := over_t - 1.2
	if t < 0.0:
		return
	var a := Pal.ease_out(t / 0.6)
	view.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.82 * a))
	var cx := vp.x / 2.0
	var y := vp.y * 0.3
	_text_stagger(font_xl, Txt.t("shattered"), Vector2(cx, y), 52, Pal.ink(1.0, 1.1), t - 0.1, -1.0, 0.07)
	view.draw_line(Vector2(cx - 240.0 * a, y + 28.0), Vector2(cx + 240.0 * a, y + 28.0), Pal.ink(0.4 * a), 1.0)
	var rk := Pal.ease_out(clampf((t - 0.45) / 0.9, 0.0, 1.0))
	var rows := [
		[Txt.t("reached"), Txt.t("chapter_n") % (game.chapter + 1) + "  ·  " + Txt.t("wave") % (game.wave_ctl.index + 1)],
		[Txt.t("time"), "%.1f s" % (game.run_time * rk)],
		[Txt.t("kills"), str(int(round(game.kills * rk)))],
	]
	for i in rows.size():
		var rt := clampf((t - 0.3 - i * 0.12) / 0.3, 0.0, 1.0)
		var ry := y + 90.0 + i * 44.0
		view.draw_string(font_s, Vector2(cx - 200.0, ry), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.55 * rt))
		view.draw_string(font_l, Vector2(cx - 20.0, ry), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.9 * rt))
	# what you built
	var bt := clampf((t - 0.8) / 0.4, 0.0, 1.0)
	var gx: float = cx - (game.relics.size() - 1) * 26.0
	for j in game.relics.size():
		_glyph(game.relics[j], Vector2(gx + j * 52.0, y + 250.0), 14.0, Pal.ink(0.8 * bt), 1.4)
	var pulse := 0.55 + 0.25 * sin(t * 3.0)
	_run_stats(cx, y + 300.0, bt)
	_text_c(font_b, Txt.t("restart"), Vector2(cx, y + 370.0), 20, Pal.ink(pulse * bt))


func _wrap(txt: String, size: int, width: float) -> Array:
	var out: Array = []
	var cur := ""
	for ch in txt:
		var test := cur + ch
		if font_s.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and cur != "":
			out.append(cur)
			cur = ch.strip_edges(true, false)
		else:
			cur = test
	if cur != "":
		out.append(cur)
	return out


func _draw_boss_bar(vp: Vector2, cx: float, y: float, appear: float) -> void:
	var b = game.boss
	if b.state == Boss.OFF or b.state == Boss.DEAD:
		return
	var a := appear * (Pal.ease_out(b.t / 0.5) if b.state == Boss.ENTER else 1.0)
	var open := Pal.ease_io(clampf(b.t / 0.9, 0.0, 1.0)) if b.state == Boss.ENTER else 1.0
	var w := 560.0 * open
	var by := y + 46.0
	var x0 := cx - w / 2.0
	view.draw_rect(Rect2(x0, by, w, 4.0), Pal.ink(0.12 * a))
	view.draw_rect(Rect2(x0, by, w * boss_hp_chip, 4.0), Pal.ink(0.35 * a))
	view.draw_rect(Rect2(x0, by, w * boss_hp_shown, 4.0), Pal.ink(0.9 * a, 1.0 + 1.5 * boss_flash))
	for q in [0.25, 0.5, 0.75]:
		view.draw_line(Vector2(x0 + w * q, by - 3.0), Vector2(x0 + w * q, by + 7.0), Pal.ink(0.5 * a), 1.0)
	view.draw_string(font_s, Vector2(x0, by - 8.0), Txt.t(game.boss.name_key()), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.55 * a))
	if b.core_open > 0.5:
		var pulse := 0.5 + 0.5 * sin(game.real_time * 10.0)
		view.draw_string(font_b, Vector2(x0 + w - 60.0, by - 8.0), "CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink((0.5 + 0.4 * pulse) * a, 1.3))
	if boss_flash > 0.0:
		var e := 1.0 - boss_flash
		view.draw_rect(Rect2(x0 - 6.0 * e, by - 6.0 * e, w + 12.0 * e, 4.0 + 12.0 * e), Pal.ink(0.6 * boss_flash), false, 1.0)


func _draw_dev(_vp: Vector2) -> void:
	if dev_s.x <= 0.01:
		return
	var x := 28.0 - (1.0 - dev_s.x) * 380.0
	var y := 110.0
	var lines: Array = []
	var onoff := func(v: bool) -> String: return "ON" if v else "off"
	lines.append(["DEV", true])
	lines.append(["FPS %d   ×%.2f   bullets %d   enemies %d" % [Engine.get_frames_per_second(), Engine.time_scale, game.bullets.list.size(), game.enemies.remaining()], false])
	lines.append(["%s %d   boss hp %d / phase %d" % [Txt.t("dev_wave"), game.wave_ctl.index + 1, int(game.boss.hp), game.boss.phase], false])
	var lvs: Array = []
	for k in Cards.SCHOOLS:
		lvs.append(str(game.lv.get(k, 0)))
	lines.append(["%s  %s   · %s %d" % [Txt.t("dev_lv"), " ".join(lvs), Txt.t("dev_ch"), game.chapter + 1], false])
	lines.append(["", false])
	lines.append(["PgUp / PgDn   " + Txt.t("dev_jump"), false])
	lines.append(["B   " + Txt.t("dev_boss"), false])
	lines.append(["N   " + Txt.t("dev_next_ch"), false])
	lines.append(["Ctrl+1…8   " + Txt.t("dev_up"), false])
	lines.append(["Ctrl+R   " + Txt.t("dev_relic"), false])
	lines.append(["H   " + Txt.t("dev_heal"), false])
	lines.append(["G   %s   %s" % [Txt.t("dev_god"), onoff.call(game.dev_god)], false])
	lines.append(["I   %s   %s" % [Txt.t("dev_ammo"), onoff.call(game.dev_ammo)], false])
	lines.append(["K   " + Txt.t("dev_kill"), false])
	lines.append(["[ ]   " + Txt.t("dev_speed"), false])
	lines.append(["Z / X / C   " + Txt.t("dev_spawn"), false])
	lines.append(["`   " + Txt.t("dev_off"), false])
	var h := lines.size() * 20.0 + 18.0
	view.draw_rect(Rect2(x - 12.0, y - 22.0, 360.0, h), Color(0, 0, 0, 0.72))
	view.draw_rect(Rect2(x - 12.0, y - 22.0, 360.0, h), Pal.ink(0.25), false, 1.0)
	for ln in lines:
		if ln[1]:
			view.draw_string(font_b, Vector2(x, y), ln[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.red(1.0, 1.6))
		elif ln[0] != "":
			view.draw_string(font_s, Vector2(x, y), ln[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.8))
		y += 20.0


# ---------------------------------------------------------------- motion layer
# Pause menu over a blurred frame, the slit that opens and closes a run, and
# the shards of the cards you passed over.

const PAUSE_ROWS := ["resume", "assist", "restart", "title", "quit"]

var blur: ColorRect
var pause_t := 0.0
var pause_sel := 0
var pause_hl := Motion.Spring2.new(Vector2.ZERO, 420.0, 0.78)
var pause_k: Array = []
var open_t := 0.0
var close_t := -1.0
var close_cb: Callable
var ammo_s := Motion.Spring.new(0.0, 520.0, 0.42)
var combo_s := Motion.Spring.new(0.0, 520.0, 0.42)
var boss_s := Motion.Spring.new(1.0, 260.0, 0.5)
var card_y: Array = []
var card_tilt: Array = []
var ui_shards: Array = []      # [pos, a, b, vel, rot, spin, t]
var dev_s := Motion.Spring.new(0.0, 300.0, 0.78)
var ret_gap := Motion.Spring.new(8.0, 700.0, 0.42)
var ret_rot := Motion.Spring.new(0.0, 260.0, 0.55)
var ret_len := Motion.Spring.new(7.0, 420.0, 0.6)
var ret_dot := Motion.Spring.new(1.0, 500.0, 0.4)
var ret_shake := Motion.Spring2.new(Vector2.ZERO, 900.0, 0.22)
var dry_k := 0.0
var dry_sign := 1.0
var hitm := 0.0
var hitm_kind := 0
var hitm_k := Motion.Spring.new(1.0, 520.0, 0.45)
var ring_hold := 0.0
var ring_a := 0.0
var ring_s := Motion.Spring.new(1.0, 300.0, 0.7)
var timer_odo := Motion.Odo.new(0.2, 0.5, 1)
var timer_last := 0.0
var ammo_odo := Motion.Odo.new(0.16)
var ammo_last := 0
var combo_odo := Motion.Odo.new(0.13)
var arrived := true
var unpause_t := 0.0
var stamp_landed := true
var drops: Array = []          # ink from the grade stamp: [pos, vel, t, r]
var mend_rings: Array = []     # [pos, t]
var slot_rings: Array = []     # [pos, t]


func _motion_ready() -> void:
	blur = ColorRect.new()
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/blur.gdshader")
	blur.material = m
	blur.visible = false
	add_child(blur)
	move_child(blur, 1)
	for i in PAUSE_ROWS.size():
		pause_k.append(Motion.Spring.new(0.0, 320.0, 0.7))
	for i in 3:
		card_y.append(Motion.Spring.new(0.0, 210.0, 0.62))
		card_tilt.append(Motion.Spring2.new(Vector2.ZERO, 260.0, 0.7))


func _pause_rect(i: int, vp: Vector2) -> Rect2:
	return Rect2(vp.x / 2.0 - 220.0, vp.y * 0.44 + i * 60.0, 440.0, 48.0)


func pause_open() -> void:
	pause_t = 0.0
	pause_sel = 0
	pause_hl.snap(_pause_rect(0, view.get_viewport_rect().size).get_center() + Vector2(80, 0))


func pause_move(d: int) -> void:
	pause_sel = posmod(pause_sel + d, PAUSE_ROWS.size())
	game.sfx.play("tick", 1.0 + 0.04 * pause_sel, -7.0)


func pause_hover() -> int:
	var vp := view.get_viewport_rect().size
	for i in PAUSE_ROWS.size():
		if _pause_rect(i, vp).has_point(reticle):
			return i
	return -1


func pause_choice() -> String:
	return PAUSE_ROWS[pause_sel]


# Close the slit, then run `cb` (scene change).
func close_to(cb: Callable) -> void:
	if close_t >= 0.0:
		return
	close_t = 0.0
	close_cb = cb
	game.sfx.play("release", 0.8, -4.0)


func _step_motion(dt: float) -> void:
	open_t += dt
	if close_t >= 0.0:
		close_t += dt
		if close_t > 0.55 and close_cb.is_valid():
			var cb := close_cb
			close_cb = Callable()
			cb.call()
	ammo_s.step(dt)
	combo_s.step(dt)
	_step_reticle(dt)
	timer_odo.step(dt)
	ammo_odo.step(dt)
	combo_odo.step(dt)
	if stamp_t >= 0.16 and not stamp_landed:
		stamp_landed = true
		var sc := Vector2(vp0().x / 2.0, vp0().y * 0.3)
		for k in 18:
			var d := Vector2.from_angle(randf() * TAU)
			drops.append([sc + d * randf_range(50.0, 80.0), d * randf_range(180.0, 620.0), 0.0, randf_range(1.5, 4.5)])
		game.cam.add_trauma(0.14 if stamp_g == "S" else 0.08)
	var q := 0
	while q < drops.size():
		var dp: Array = drops[q]
		dp[2] += dt
		dp[0] += dp[1] * dt
		dp[1] *= exp(-7.0 * dt)
		if dp[2] > 0.7:
			drops.remove_at(q)
		else:
			q += 1
	var m := 0
	while m < mend_rings.size():
		mend_rings[m][1] += dt
		if mend_rings[m][1] > 0.4:
			mend_rings.remove_at(m)
		else:
			m += 1
	var r := 0
	while r < slot_rings.size():
		slot_rings[r][1] += dt
		if slot_rings[r][1] > 0.5:
			slot_rings.remove_at(r)
		else:
			r += 1
	boss_s.target = clampf(game.boss.hp / game.boss.max_hp(), 0.0, 1.0)
	boss_s.step(dt)
	boss_hp_shown = clampf(boss_s.x, 0.0, 1.05)
	dev_s.target = 1.0 if game.dev and not is_instance_valid(game.dev_panel) else 0.0
	dev_s.step(dt)
	if paused:
		unpause_t = 0.0
	else:
		unpause_t += dt
	if paused:
		pause_t += dt
		var hv := pause_hover()
		if hv >= 0:
			pause_sel = hv
	for i in pause_k.size():
		pause_k[i].target = 1.0 if (paused and i == pause_sel) else 0.0
		pause_k[i].step(dt)
	var vp := view.get_viewport_rect().size
	pause_hl.target = _pause_rect(pause_sel, vp).get_center()
	pause_hl.step(dt)
	blur.visible = pause_a > 0.01
	(blur.material as ShaderMaterial).set_shader_parameter("amount", pause_a)
	for i in card_y.size():
		card_y[i].step(dt)
		var tgt := Vector2.ZERO
		if cards_t >= 0.0 and chosen < 0 and i == hover and i < cards.size():
			tgt = ((reticle - _card_center(i, vp)) / (CARD / 2.0)).clamp(Vector2(-1, -1), Vector2(1, 1))
		card_tilt[i].target = tgt
		card_tilt[i].step(dt)
	var j := 0
	while j < ui_shards.size():
		var s: Array = ui_shards[j]
		s[6] += dt
		s[0] += s[3] * dt
		s[3] = s[3] * exp(-2.5 * dt) + Vector2(0, 900.0) * dt
		s[4] += s[5] * dt
		if s[6] > 0.9:
			ui_shards.remove_at(j)
		else:
			j += 1


func _step_reticle(dt: float) -> void:
	var foc: bool = game.focusing
	ret_gap.target = 6.0 if foc else 8.0
	ret_gap.step(dt)
	ret_rot.target = PI / 4.0 if foc else 0.0
	ret_rot.step(dt)
	ret_len.target = 10.0 if foc else 7.0
	ret_len.step(dt)
	ret_dot.target = 1.5 if foc else 1.0
	ret_dot.step(dt)
	ret_shake.step(dt)
	hitm_k.step(dt)
	dry_k = maxf(0.0, dry_k - dt / 0.35)
	hitm = maxf(0.0, hitm - dt / (0.3 if hitm_kind >= 2 else 0.17))
	ring_hold -= dt
	ring_a = Pal.damp(ring_a, 1.0 if ring_hold > 0.0 or game.ammo == 0 else 0.0, 8.0 if ring_hold > 0.0 else 3.0, dt)
	ring_s.target = clampf(float(game.ammo) / maxf(1.0, float(game.mag)), 0.0, 1.0)
	ring_s.step(dt)


func _draw_reticle(f: float) -> void:
	var rc := Pal.ink(0.9).lerp(Pal.red(1.0, 2.2), Pal.ease_out(f))
	rc = rc.lerp(Pal.ink(0.3), dry_k)
	var g: float = maxf(2.5, ret_gap.x)
	var ln: float = maxf(3.0, ret_len.x)
	var c: Vector2 = reticle + ret_shake.x
	view.draw_set_transform(c, ret_rot.x, Vector2.ONE)
	var pts := PackedVector2Array()
	for k in 4:
		var d := Vector2.from_angle(TAU * k / 4.0)
		pts.append(d * g)
		pts.append(d * (g + ln))
	view.draw_multiline(pts, rc, 2.0)
	view.draw_circle(Vector2.ZERO, 1.6 * clampf(ret_dot.x, 0.4, 2.6), rc)
	view.draw_set_transform(c, 0.0, Vector2.ONE)
	if hitm > 0.0:
		var e := 1.0 - hitm
		var big := hitm_kind >= 2
		var r0 := g + 4.0 + (10.0 if big else 6.0) * Pal.ease_out(e)
		var l := (9.0 if hitm_kind == 3 else (7.0 if big else 5.0)) * clampf(hitm_k.x, 0.5, 2.0)
		var hc := Pal.ink(hitm, 1.7)
		if hitm_kind == 1:
			hc = Pal.red(hitm * 0.9, 2.2)
		elif big:
			hc = Pal.red(hitm, 2.8)
		var hp := PackedVector2Array()
		for k in 4:
			var d := Vector2.from_angle(PI / 4.0 + TAU * k / 4.0)
			hp.append(d * r0)
			hp.append(d * (r0 + l))
		view.draw_multiline(hp, hc, 2.0 if big else 1.6)
	if ring_a > 0.01:
		var rr := g + ln + 8.0
		view.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Pal.ink(0.06 * ring_a), 1.0, false)
		var fr: float = clampf(ring_s.x, 0.0, 1.0)
		if fr > 0.001:
			var low := 1.0 if game.ammo <= maxi(1, game.mag / 4) else 0.0
			view.draw_arc(Vector2.ZERO, rr, -PI / 2.0, -PI / 2.0 + TAU * fr, maxi(4, int(40 * fr)), Pal.ink(0.32 * ring_a, 1.0).lerp(Pal.red(0.6 * ring_a, 2.0), low), 1.5, false)
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shatter_card(i: int) -> void:
	var vp := view.get_viewport_rect().size
	var c := _card_center(i, vp) + Vector2(0, card_y[i].x)
	var h := CARD / 2.0
	var corners := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		for k in 5:
			var p0 := a.lerp(b, k / 5.0)
			var p1 := a.lerp(b, (k + 1) / 5.0)
			var mid := (p0 + p1) * 0.5
			ui_shards.append([c + mid, p0 - mid, p1 - mid, mid.normalized() * randf_range(160, 420) + Vector2(0, -200), 0.0, randf_range(-8, 8), 0.0])


func vp0() -> Vector2:
	return view.get_viewport_rect().size


func _draw_motion(vp: Vector2) -> void:
	for dp in drops:
		var k: float = 1.0 - dp[2] / 0.7
		view.draw_circle(dp[0], dp[3] * (0.4 + 0.6 * k), Pal.ink(0.85 * k, 1.5 if stamp_g == "S" else 1.0))
	for s in ui_shards:
		var k: float = 1.0 - s[6] / 0.9
		var tr := Transform2D(s[4], s[0])
		var red: bool = s.size() > 7 and s[7]
		view.draw_line(tr * (s[1] as Vector2), tr * (s[2] as Vector2), Pal.red(0.95 * k * k, 2.4) if red else Pal.ink(0.8 * k * k, 1.3), 1.5)
	_draw_pause(vp)
	# the slit: the run opens out of a red line and closes back into one
	var gap := -1.0
	if open_t < 0.75:
		gap = Pal.ease_io(open_t / 0.75)
	if close_t >= 0.0:
		gap = 1.0 - Pal.ease_in(clampf(close_t / 0.45, 0.0, 1.0))
	if gap >= 0.0 and gap < 1.0:
		var hy := vp.y * 0.5 * gap
		view.draw_rect(Rect2(0, 0, vp.x, vp.y / 2.0 - hy), Color(0, 0, 0, 1))
		view.draw_rect(Rect2(0, vp.y / 2.0 + hy, vp.x, vp.y / 2.0 - hy + 2.0), Color(0, 0, 0, 1))
		var la := 1.0 - gap
		view.draw_line(Vector2(0, vp.y / 2.0 - hy), Vector2(vp.x, vp.y / 2.0 - hy), Pal.red(la, 2.6), 2.0)
		view.draw_line(Vector2(0, vp.y / 2.0 + hy), Vector2(vp.x, vp.y / 2.0 + hy), Pal.red(la, 2.6), 2.0)


func _draw_pause(vp: Vector2) -> void:
	if pause_a <= 0.01:
		return
	var a := pause_a
	view.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.35 * a))
	var drop := (1.0 - Pal.ease_out(clampf(pause_t / 0.4, 0.0, 1.0))) * -30.0 if paused else 0.0
	var pt := Txt.t("paused")
	_text_c(font_l, pt, Vector2(vp.x / 2.0, vp.y * 0.34 + drop), 56, Pal.ink(a))
	var hc: Vector2 = pause_hl.x
	Pal.band(view, Rect2(hc - Vector2(220, 24), Vector2(440, 48)), 0.022 * a)
	var stretch := clampf(absf(pause_hl.v.y) / 1200.0, 0.0, 0.5)
	view.draw_line(Vector2(hc.x - 220.0 * (1.0 - stretch * 0.6), hc.y + 24.0), Vector2(hc.x + 220.0 * (1.0 - stretch * 0.6), hc.y + 24.0), Pal.red(0.85 * a, 2.0), 2.0)
	view.draw_line(Vector2(hc.x - 230.0, hc.y - 16.0), Vector2(hc.x - 230.0, hc.y + 16.0), Pal.red(a, 2.2), 2.0)
	for i in PAUSE_ROWS.size():
		var ki := Pal.ease_out(Motion.stagger(pause_t, i, 0.05, 0.35)) if paused else 1.0 - Pal.ease_in(Motion.stagger(unpause_t, PAUSE_ROWS.size() - 1 - i, 0.025, 0.16))
		var r := _pause_rect(i, vp)
		var lift: float = pause_k[i].x
		var c := Pal.ink((0.55 + 0.4 * lift) * a * ki)
		view.draw_set_transform(r.get_center() + Vector2((1.0 - ki) * 50.0 + lift * 10.0, 0), 0.0, Vector2.ONE * (1.0 + 0.03 * lift))
		_text_c(font_xl, Txt.t("p_" + PAUSE_ROWS[i]), Vector2(0, 9), 24, c)
		view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text_c(font_s, Txt.t("pause_keys"), Vector2(vp.x / 2.0, vp.y * 0.44 + 350.0), 14, Pal.ink(0.4 * a))
	_draw_build(vp, a)


# 训练场: which key makes you what, and what the current shell's three moves are.
func _draw_yard(vp: Vector2) -> void:
	var x := 40.0
	var y := 150.0
	view.draw_string(font_b, Vector2(x, y), Txt.t("yard_title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Possess.cyan(0.95, 1.6))
	y += 34.0
	var cur := -1
	if game.possess.hosting():
		cur = game.possess.shell.kind
	for i in Game.YARD_KEYS.size():
		var k: int = Game.YARD_KEYS[i]
		var on := k == cur
		var line := "%d   %s" % [i + 1, Txt.t("yard_k%d" % k)]
		view.draw_string(font_s, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Possess.cyan(1.0, 2.0) if on else Pal.ink(0.6))
		y += 24.0
		if on:
			for row in Txt.t("yard_m%d" % k).split("\n"):
				view.draw_string(font_s, Vector2(x + 26.0, y), row, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Possess.cyan(0.75, 1.3))
				y += 21.0
	y += 12.0
	for key in ["yard_e", "yard_r", "yard_t", "yard_v", "yard_esc"]:
		view.draw_string(font_s, Vector2(x, y), Txt.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.45))
		y += 20.0
