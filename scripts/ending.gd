class_name Ending
extends Node2D
# The true ending (chapter 12, after the Chairman). The hall goes quiet. Eleven
# lights wake in the walls, one for every chapter behind you, and a line runs
# from each to the core where the body fell: hold the recall and they light
# like your own rounds; let go and they all come home — into the core. Each,
# flying, shows a line of what it carried, and the seal lights a segment for
# each one home. The core opens; the cards, two of them drawn: the face that
# was on every screen for two hundred years, wiped away; the maintenance
# worker at the door, and R-0 going out through it. A click moves a card on.

enum { OFF, QUIET, READY, FLY, OPEN, CARDS, DONE }

const QUIET_TIME := 2.2
const FLY_TIME := 1.3
const FLY_GAP := 0.22
const CARD_TIME := 3.6
# a card is its line; "face" and "door" cards draw a scene above the line
const CARD_KEYS := ["end_1", "face", "end_3", "door", "end_5"]
const SCENE_LINE := {"face": "end_2", "door": "end_4"}
const SCENE_TIME := 5.2
const STORIES := 11

var game
var state := OFF
var t := 0.0
var core := Vector2(960, 540)
var lights: Array = []          # {at, text, t0}
var held := 0.0
var card := 0
var card_t := 0.0
var fire_prev := true
var lit := 0.0
var home_n := 0


func _init() -> void:
	z_index = 30
	z_as_relative = false


func running() -> bool:
	return state != OFF and state != DONE


func finished() -> bool:
	return state == DONE


func start(at: Vector2) -> void:
	state = QUIET
	t = 0.0
	core = Vector2(960, 540)     # the seal at the hall's centre, where every order came from
	lights.clear()
	home_n = 0
	held = 0.0
	lit = 0.0
	card = 0
	card_t = 0.0
	# one light for each chapter, spaced round the walls, each carrying the
	# first remnant that chapter left
	var r := Arena.ROOM.grow(-6.0)
	var per := 2.0 * (r.size.x + r.size.y)
	for s in STORIES:
		var d := per * (s + 0.5) / STORIES + per * 0.06
		var at2 := _perimeter(r, fmod(d, per))
		var w: Array = Lore.walls(s + 1)
		var text := ""
		if not w.is_empty():
			text = w[0][4] if Txt.zh else w[0][5]
		lights.append({"at": at2, "text": text, "t0": -1.0})
	game.sfx.drop()
	game.bullets.clear_foe()


func _perimeter(r: Rect2, d: float) -> Vector2:
	if d < r.size.x:
		return Vector2(r.position.x + d, r.position.y)
	d -= r.size.x
	if d < r.size.y:
		return Vector2(r.end.x, r.position.y + d)
	d -= r.size.y
	if d < r.size.x:
		return Vector2(r.end.x - d, r.end.y)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)


func step(dt: float) -> void:
	if state == OFF or state == DONE:
		return
	t += dt
	var fire: bool = game._in_fire()
	var click := fire and not fire_prev
	fire_prev = fire
	var focus: bool = game._in_focus()
	match state:
		QUIET:
			if t >= QUIET_TIME:
				state = READY
				t = 0.0
				game.sfx.play("lit", 0.8, -6.0)
		READY:
			if focus:
				held += dt
				if held < 0.05:
					game.sfx.play("focus", 0.8, -3.0)
			lit = Pal.damp(lit, 1.0 if focus else 0.0, 8.0, dt)
			# let go after holding: home they come (a bot lets go by itself)
			var go := (not focus and held > 0.25) or (game.bot != null and t > 1.5)
			if go:
				state = FLY
				t = 0.0
				for i in lights.size():
					lights[i].t0 = i * FLY_GAP
				game.sfx.play("release", 0.7, 0.0)
				game.cam.add_trauma(0.25)
		FLY:
			for l in lights:
				var k: float = (t - l.t0) / FLY_TIME
				if k >= 1.0 and not l.has("in"):
					l["in"] = true
					home_n += 1
					game.fx.flash(core, 40.0, 0.15, Pal.ink(0.8, 2.2))
					game.fx.ring(core, 6.0, 50.0, 0.25, Pal.red(0.8, 2.4), 2.0)
					game.sfx.play("home", 0.8 + lights.find(l) * 0.04, -6.0)
			if t >= FLY_GAP * lights.size() + FLY_TIME + 0.6:
				state = OPEN
				t = 0.0
				game.fx.flash(core, 900.0, 1.0, Pal.ink(0.9, 2.0))
				game.fx.ring(core, 20.0, 1600.0, 1.6, Pal.ink(0.9, 1.8), 4.0)
				game.cam.add_trauma(0.6)
				game.sfx.play("boss_die", 1.2, 0.0)
		OPEN:
			if t >= 2.0:
				state = CARDS
				t = 0.0
				card = 0
				card_t = 0.0
		CARDS:
			card_t += dt
			var hold := _hold()
			if card_t >= hold or (click and card_t > 0.8):
				card += 1
				card_t = 0.0
				if card > CARD_KEYS.size():
					state = DONE
	queue_redraw()


func _hold() -> float:
	if card >= CARD_KEYS.size():
		return CARD_TIME * 1.8
	if CARD_KEYS[card] == "face":
		return SCENE_TIME + 1.6
	return SCENE_TIME if SCENE_LINE.has(CARD_KEYS[card]) else CARD_TIME


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if state == OFF or state == DONE:
		return
	var font := Fonts.get_font("SemiBold")
	var light_f := Fonts.get_font("Light")
	var vr := Arena.ROOM.grow(1200.0)
	if state == QUIET or state == READY or state == FLY:
		# the hall dimmed round the lights
		var q := clampf(t / 1.2, 0.0, 1.0) if state == QUIET else 1.0
		draw_rect(vr, Color(0, 0, 0, 0.74 * q))
		# the core where the body fell: a socket, open a crack
		draw_arc(core, 30.0, 0.0, TAU, 40, Pal.ink(0.6 * q, 1.4), 2.0)
		draw_arc(core, 44.0, t * 0.5, t * 0.5 + PI * 1.5, 40, Pal.ink(0.3 * q), 1.0)
		# the seal round it: eleven segments, one lit for each light come home
		for i in STORIES:
			var a0 := -PI * 0.5 + TAU * i / STORIES + 0.04
			var a1 := a0 + TAU / STORIES - 0.08
			var on := i < home_n
			draw_arc(core, 250.0, a0, a1, 16, Pal.red(0.95 * q, 2.2) if on else Pal.ink(0.18 * q), 4.0 if on else 1.5)
		var cl := Txt.t("end_core")
		var cw := font.get_string_size(cl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, core + Vector2(-cw * 0.5, 72.0), cl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.5 * q))
		for i in lights.size():
			var l: Dictionary = lights[i]
			var wake := clampf((t - 0.4 - i * 0.12) / 0.4, 0.0, 1.0) if state == QUIET else 1.0
			var at: Vector2 = l.at
			if state == FLY and l.t0 >= 0.0:
				var k := clampf((t - l.t0) / FLY_TIME, 0.0, 1.0)
				if k >= 1.0:
					continue
				var e := Pal.ease_in(k)
				var p := at.lerp(core, e)
				# its tail and the line it carried, rising off its path
				draw_line(at.lerp(core, maxf(0.0, e - 0.12)), p, Pal.red(0.9, 2.4), 3.0)
				draw_circle(p, 5.0, Pal.red(1.0, 3.0))
				if k > 0.05:
					var ta := clampf(k * 3.0, 0.0, 1.0) * (1.0 - clampf((k - 0.75) / 0.25, 0.0, 1.0))
					var tw := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
					var tp := p + Vector2(-tw * 0.5, -22.0)
					tp.x = clampf(tp.x, Arena.ROOM.position.x + 10.0, Arena.ROOM.end.x - tw - 10.0)
					draw_rect(Rect2(tp + Vector2(-8, -19), Vector2(tw + 16.0, 26.0)), Color(0, 0, 0, 0.7 * ta))
					draw_string(font, tp, l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Pal.ink(0.95 * ta, 1.4))
				continue
			# waiting in the wall, its line to the core lit while you hold
			draw_line(at, core, Pal.red((0.06 + 0.5 * lit) * wake, 1.0 + 0.8 * lit), 1.0 + 1.5 * lit)
			draw_circle(at, 4.0 + 2.0 * lit, Pal.red(0.9 * wake, 1.8 + lit))
			draw_arc(at, 10.0, 0.0, TAU, 16, Pal.red(0.4 * wake), 1.0)
		if state == READY:
			var hint := Txt.t("end_hold") % Settings.key_name("recall")
			var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var pa := 0.55 + 0.45 * sin(t * 3.0)
			draw_string(font, Vector2(960.0 - hw * 0.5, 1000.0 - 40.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(pa, 1.3))
		return
	# white, then black: the cards
	var wk := 0.0
	if state == OPEN:
		wk = 1.0 - clampf(t / 2.0, 0.0, 1.0)
		draw_rect(vr, Color(0, 0, 0, clampf(t / 1.2, 0.0, 1.0)))
		draw_rect(vr, Color(1, 1, 1, 0.8 * wk * wk))
		return
	draw_rect(vr, Color(0, 0, 0, 1.0))
	var a := clampf(card_t / 0.6, 0.0, 1.0)
	var hold := _hold()
	a *= 1.0 - clampf((card_t - (hold - 0.6)) / 0.6, 0.0, 1.0)
	if card < CARD_KEYS.size() and SCENE_LINE.has(CARD_KEYS[card]):
		if CARD_KEYS[card] == "face":
			_draw_face(a)
		else:
			_draw_door(a)
		var st := Txt.t(SCENE_LINE[CARD_KEYS[card]])
		var sw := light_f.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		# the face's line only once the face is gone
		var after := 4.3 if CARD_KEYS[card] == "face" else 0.8
		var sa := a * clampf((card_t - after) / 0.6, 0.0, 1.0)
		draw_string(light_f, Vector2(960.0 - sw * 0.5, 840.0), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.ink(0.92 * sa, 1.2))
	elif card < CARD_KEYS.size():
		var txt := Txt.t(CARD_KEYS[card])
		var fs := 30
		var w := light_f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(light_f, Vector2(960.0 - w * 0.5, 548.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.92 * a, 1.2))
		# a thin rule that draws itself under it
		var rl := w * Pal.ease_out(clampf(card_t / 1.4, 0.0, 1.0))
		draw_line(Vector2(960.0 - rl * 0.5, 576.0), Vector2(960.0 + rl * 0.5, 576.0), Pal.ink(0.3 * a), 1.0)
	else:
		var title := Txt.t("end_title")
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
		draw_string(font, Vector2(960.0 - tw * 0.5, 500.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Pal.you(a, 1.6))
		var th := Txt.t("end_thanks")
		var hw := light_f.get_string_size(th, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(light_f, Vector2(960.0 - hw * 0.5, 580.0), th, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.ink(0.75 * a))
		var rr := Txt.t("end_run")
		var rw := font.get_string_size(rr, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		# a cursor after it, still blinking: still running
		var blink := 1.0 if int(card_t * 2.0) % 2 == 0 else 0.0
		draw_string(font, Vector2(960.0 - rw * 0.5, 670.0), rr, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.ink(0.7 * a, 1.3))
		draw_rect(Rect2(Vector2(960.0 + rw * 0.5 + 8.0, 650.0), Vector2(12, 24)), Pal.you(0.9 * a * blink, 1.6))


# The face that was on every screen: a broadcast frame, scanlines, two eyes and
# a smile that never moved in two hundred years. A white ring goes out from the
# middle and wipes it, line by line, and leaves the frame empty.
func _draw_face(a: float) -> void:
	var c := Vector2(960, 470)
	var fr := Rect2(c - Vector2(250, 190), Vector2(500, 380))
	var wipe := Pal.ease_io(clampf((card_t - 2.4) / 1.8, 0.0, 1.0))
	var rr := wipe * 420.0
	draw_rect(fr, Color(0.05, 0.05, 0.055, a))
	draw_rect(fr, Pal.ink(0.55 * a), false, 2.0)
	# the channel's tag in the corner, and its live dot
	var sf := Fonts.get_font("SemiBold")
	draw_string(sf, fr.position + Vector2(16, 28), Txt.t("face_tag"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.6 * a))
	if int(card_t * 2.0) % 2 == 0 and wipe < 1.0:
		draw_circle(fr.position + Vector2(fr.size.x - 24.0, 22.0), 5.0, Pal.red(0.9 * a, 2.0))
	# the face, gone where the ring has passed
	var fa := a
	var head := 150.0
	var pts := PackedVector2Array()
	for k in 49:
		var q := c + Vector2.from_angle(TAU * k / 48.0) * Vector2(head * 0.82, head)
		pts.append(q)
	_wiped_poly(pts, c, rr, Pal.ink(0.85 * fa, 1.3), 3.0)
	for ex: float in [-52.0, 52.0]:
		var e := c + Vector2(ex, -30.0)
		if e.distance_to(c) > rr:
			draw_circle(e, 9.0, Pal.ink(0.9 * fa, 1.4))
	var smile := PackedVector2Array()
	for k in 25:
		var u := -1.0 + 2.0 * k / 24.0
		smile.append(c + Vector2(u * 70.0, 50.0 + (1.0 - u * u) * 34.0))
	_wiped_poly(smile, c, rr, Pal.ink(0.9 * fa, 1.4), 4.0)
	# scanlines over the screen
	var y := fr.position.y + 4.0
	while y < fr.end.y:
		draw_line(Vector2(fr.position.x + 2.0, y), Vector2(fr.end.x - 2.0, y), Color(0, 0, 0, 0.35 * a), 1.0)
		y += 4.0
	if wipe > 0.0 and wipe < 1.0:
		draw_arc(c, rr, 0.0, TAU, 96, Pal.ink(0.9 * a, 2.4), 6.0 * (1.0 - wipe) + 1.0)
	if wipe >= 1.0:
		# no signal
		var ns := "—"
		draw_string(Fonts.get_font("SemiBold"), c + Vector2(-8, 8), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.ink(0.4 * a))


func _wiped_poly(pts: PackedVector2Array, c: Vector2, rr: float, col: Color, w: float) -> void:
	for k in pts.size() - 1:
		if pts[k].distance_to(c) > rr and pts[k + 1].distance_to(c) > rr:
			draw_line(pts[k], pts[k + 1], col, w)


# The door out of 13th Street, standing open on the light: the worker beside
# it, the cable still in his hand; R-0 crossing the floor to it and through,
# and the light narrowing as the door swings to.
func _draw_door(a: float) -> void:
	var floor_y := 690.0
	var door := Rect2(1080, 400, 150, 290)
	var walk := Pal.ease_io(clampf((card_t - 0.6) / 3.4, 0.0, 1.0))
	var close := clampf((card_t - 4.0) / 0.8, 0.0, 1.0)
	draw_line(Vector2(560, floor_y), Vector2(1360, floor_y), Pal.ink(0.35 * a), 1.5)
	# the light through the door, spilling across the floor
	var open_w := door.size.x * (1.0 - close * 0.85)
	var lr := Rect2(door.position, Vector2(open_w, door.size.y))
	# the light: a soft bloom round the opening
	var glow := Fx.make_glow_texture()
	draw_texture_rect(glow, lr.grow(150.0), false, Color(1, 1, 1, 0.22 * a * (1.0 - close * 0.8)))
	draw_rect(lr, Color(1, 1, 1, 0.75 * a))
	draw_colored_polygon(PackedVector2Array([Vector2(lr.position.x, floor_y), Vector2(lr.end.x, floor_y), Vector2(lr.end.x - 260.0, floor_y + 70.0), Vector2(lr.position.x - 330.0, floor_y + 70.0)]), Color(1, 1, 1, 0.12 * a * (1.0 - close)))
	draw_rect(door.grow(6.0), Pal.ink(0.7 * a), false, 3.0)
	# the worker: a figure in a cap, by the door, the cable hanging from a hand
	var wk := Vector2(1290, floor_y)
	draw_circle(wk + Vector2(0, -150), 15.0, Pal.ink(0.85 * a, 1.2))
	draw_line(wk + Vector2(-17, -164), wk + Vector2(21, -160), Pal.ink(0.85 * a, 1.2), 4.0)
	draw_line(wk + Vector2(0, -134), wk + Vector2(0, -62), Pal.ink(0.85 * a, 1.2), 5.0)
	draw_line(wk + Vector2(0, -62), wk + Vector2(-14, 0), Pal.ink(0.85 * a, 1.2), 5.0)
	draw_line(wk + Vector2(0, -62), wk + Vector2(14, 0), Pal.ink(0.85 * a, 1.2), 5.0)
	draw_line(wk + Vector2(0, -120), wk + Vector2(-26, -84), Pal.ink(0.85 * a, 1.2), 4.0)
	draw_polyline(PackedVector2Array([wk + Vector2(-26, -84), wk + Vector2(-34, -40), wk + Vector2(-20, -6), wk + Vector2(-48, 0)]), Pal.ink(0.6 * a), 2.0)
	# R-0: your ring and its notch, crossing to the light and gone into it
	if walk < 1.0 or close < 0.2:
		var rp := Vector2(lerpf(640.0, door.get_center().x, walk), floor_y - 26.0)
		var fade := 1.0 - clampf((rp.x - door.position.x) / (door.size.x * 0.6), 0.0, 1.0)
		var ra := a * fade
		draw_arc(rp, 24.0, 0.0, TAU, 40, Pal.you(ra, 1.8), 3.0)
		var notch := PackedVector2Array([rp + Vector2.from_angle(-0.32) * 24.0, rp + Vector2(7, 0), rp + Vector2.from_angle(0.32) * 24.0])
		draw_colored_polygon(notch, Pal.you(ra, 1.8))
		draw_line(rp + Vector2(-30, 24), rp + Vector2(-60 - 40.0 * walk, 24), Pal.you(0.25 * ra), 1.0)
