class_name GridMaster
extends Node2D
# 配电总闸 THE GRID MASTER (chapter 6): the bureau's main transformer. Three
# cables run from it to the cabinets on the walls, each feeding a district
# by its shareholders' contribution. While any cable is live its housing is
# shielded and turns rounds away; a round or an arc crossing a live cable
# cuts into it, and once all three are cut the transformer is open. Each
# third of its health lost, it re-energises every cable.
# Its attack: it sends power to a district of the floor (marked first) and
# discharges it — whatever stands there is struck, enemies too.

enum { OFF, ENTER, RUN, DYING, DEAD }
enum { IDLE, WARN, FIRE }

const HP := 1400.0
const HOME := Vector2(960, 440)
const HALF := 118.0                   # the housing's half-size
const CABLE_HP := 170.0
const CABINETS := [Vector2(80, 420), Vector2(1840, 420), Vector2(1500, 1010)]
const CABLE_KEYS := ["grid_central", "grid_industry", "grid_13th"]
const CABLE_SHARE := ["100%", "80%", "0.5%"]
const ZONES := [Rect2(80, 70, 587, 470), Rect2(1253, 70, 587, 470), Rect2(80, 600, 587, 410), Rect2(667, 600, 586, 410), Rect2(1253, 600, 587, 410)]
const ZONE_EVERY := [4.2, 3.4, 2.8]
const WARN_TIME := 1.15
const FIRE_TIME := 0.4

var game
var state := OFF
var t := 0.0
var hp := HP
var phase := 0
var pos := HOME
var core_open := 0.0
var flash := 0.0
var red := 0.0
var guard_t := 0.0
var dying_t := 0.0
var enter_t := 0.0
var cable_hp := [CABLE_HP, CABLE_HP, CABLE_HP]
var cable_flash := [0.0, 0.0, 0.0]
var live_k := [0.0, 0.0, 0.0]          # 0..1 energising animation
var mode := IDLE
var mode_t := 0.0
var zone_cd := 3.0
var zones: Array = []                  # indices of the districts being fed
var bolts: Array = []                  # [from, to, t]
var rings: Array = []                  # [t, struck]: surges off the open transformer
var ring_cd := 1.0
const RING_TIME := 1.4
const RING_R := 760.0


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_grid"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


func begin_track() -> void:
	state = OFF
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	_fresh()
	game.sfx.play("horn", 0.55, -2.0)
	game.cam.add_trauma(0.3)
	game.hud.radio(Txt.t("radio_grid"))


func reset() -> void:
	state = OFF
	t = 0.0
	enter_t = 0.0
	_fresh()


func _fresh() -> void:
	hp = HP
	phase = 0
	pos = HOME
	core_open = 0.0
	guard_t = 0.0
	flash = 0.0
	red = 0.0
	mode = IDLE
	zone_cd = 3.0
	zones.clear()
	bolts.clear()
	rings.clear()
	ring_cd = 1.0
	for k in 3:
		cable_hp[k] = CABLE_HP
		live_k[k] = 0.0
		cable_flash[k] = 0.0


func dev_strike() -> void:
	if state != RUN:
		return
	for k in 3:
		cable_hp[k] = 0.0
	guard_t = 0.0
	damage(HP, false, pos, Vector2.UP)


func core_pos() -> Vector2:
	return pos


func core_vel() -> Vector2:
	return Vector2.ZERO


func shielded() -> bool:
	for k in 3:
		if cable_hp[k] > 0.0:
			return true
	return false


func cable_from(k: int) -> Vector2:
	var to: Vector2 = CABINETS[k]
	var d := (to - pos)
	# leave the housing from the face it points at
	var s := HALF / maxf(absf(d.x), absf(d.y))
	return pos + d * s


func cable_to(k: int) -> Vector2:
	var to: Vector2 = CABINETS[k]
	var n := Vector2(1, 0) if to.x < 100.0 else (Vector2(-1, 0) if to.x > 1800.0 else Vector2(0, -1))
	return to + n * 34.0


func _housing() -> Rect2:
	return Rect2(pos - Vector2(HALF, HALF), Vector2(HALF, HALF) * 2.0)


# ---------------------------------------------------------------- bullets

# The nearest of: a live cable crossed (it is cut into, the round flies on),
# or the housing (armour while shielded, the open transformer when not).
func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	var best := {}
	var bt := 2.0
	var len := a.distance_to(b)
	if len < 0.001:
		return {}
	for k in 3:
		if cable_hp[k] <= 0.0 or live_k[k] < 1.0:
			continue
		var x = Geometry2D.segment_intersects_segment(a, b, cable_from(k), cable_to(k))
		if x == null:
			continue
		var tt: float = a.distance_to(x) / len
		if tt < bt:
			bt = tt
			best = {"point": x, "normal": (b - a).normalized().orthogonal(), "core": true, "mult": 1.0, "frame": 10 + k}
	var h := _rect_hit(a, b, _housing())
	if not h.is_empty() and h.t < bt:
		if shielded():
			return {"point": h.point, "normal": h.normal, "core": false, "car": 0}
		return {"point": h.point, "normal": h.normal, "core": true, "mult": 1.0, "frame": -1}
	return best


func _rect_hit(a: Vector2, b: Vector2, r: Rect2) -> Dictionary:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var n := Vector2.ZERO
	for axis in 2:
		var p: float = a[axis]
		var dd: float = d[axis]
		var lo: float = r.position[axis]
		var hi: float = r.end[axis]
		if absf(dd) < 1e-9:
			if p < lo or p > hi:
				return {}
		else:
			var ta := (lo - p) / dd
			var tb := (hi - p) / dd
			var nn := -1.0
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
				nn = 1.0
			if ta > t0:
				t0 = ta
				n = Vector2.ZERO
				n[axis] = nn
			t1 = minf(t1, tb)
			if t0 > t1:
				return {}
	if n == Vector2.ZERO:
		return {}
	return {"point": a + d * t0, "normal": n, "t": t0}


# An arc of the floor's current across a live cable cuts into it.
func arc_cross(a: Vector2, b: Vector2, dmg: float) -> bool:
	var hit := false
	for k in 3:
		if cable_hp[k] <= 0.0 or live_k[k] < 1.0:
			continue
		var x = Geometry2D.segment_intersects_segment(a, b, cable_from(k), cable_to(k))
		if x != null:
			_hurt_cable(k, dmg / Loadout.boss_hp(), x)
			hit = true
	return hit


func on_armor(_k: int, at_p: Vector2, normal: Vector2) -> void:
	game.fx.sparks(at_p, normal, 6, Pal.foe(1.0, 2.0), 460.0, 0.2, 0.9)
	game.fx.flash(at_p, 18.0, 0.1, Pal.foe(0.5, 1.6))
	game.sfx.play("shield", randf_range(0.9, 1.1), -8.0)


func damage(dmg: float, ret: bool, at_p: Vector2, d: Vector2, frame_k: int = -1) -> void:
	if state != RUN:
		return
	dmg /= Loadout.boss_hp()
	if frame_k >= 10:
		_hurt_cable(frame_k - 10, dmg * (1.0 if ret else 0.6), at_p)
		game.fx.number(at_p, dmg, ret)
		game.on_target_hit(ret)
		return
	if shielded():
		return
	var floor_hp := HP * (1.0 - (phase + 1) / 3.0) if phase < 2 else 0.0
	if guard_t > 0.0:
		floor_hp = maxf(floor_hp, hp)
	hp = maxf(floor_hp - (0.001 if guard_t <= 0.0 else 0.0), hp - dmg)
	flash = 1.0
	if ret:
		red = 1.0
	game.fx.number(at_p, dmg, ret)
	var c := Pal.red(1.0, 3.2) if ret else Pal.foe(1.0, 1.8)
	game.fx.sparks(at_p, d, 8 if ret else 5, c, 560.0, 0.28, 0.8)
	game.on_target_hit(ret)
	var want := clampi(int((1.0 - hp / HP) * 3.0), 0, 2)
	while phase < want:
		phase += 1
		_phase_break()
	if hp <= 0.0:
		state = DYING
		dying_t = 0.0
		zones.clear()
		mode = IDLE
		game.on_boss_dying()


func _hurt_cable(k: int, dmg: float, at_p: Vector2) -> void:
	if cable_hp[k] <= 0.0:
		return
	cable_hp[k] = maxf(0.0, cable_hp[k] - dmg)
	cable_flash[k] = 1.0
	game.fx.sparks(at_p, Vector2.from_angle(randf() * TAU), 4, Pal.foe(1.0, 2.4), 300.0, 0.2, PI)
	if cable_hp[k] <= 0.0:
		# cut: it whips, sparks run back to the cabinet, the district goes dark
		game.sfx.play("cross", 0.6, -2.0)
		game.cam.add_trauma(0.3)
		game.add_hitstop(0.05)
		for j in 6:
			var p: Vector2 = cable_from(k).lerp(cable_to(k), j / 5.0)
			game.fx.sparks(p, Vector2.from_angle(randf() * TAU), 3, Pal.foe(1.0, 2.2), 320.0, 0.3, PI)
		if not shielded():
			# the housing opens
			game.sfx.play("release", 0.5, 0.0)
			game.fx.ring(pos, HALF, HALF * 3.0, 0.5, Pal.foe(0.9, 1.8), 3.0)
			game.cam.add_trauma(0.4)


func _phase_break() -> void:
	guard_t = 1.4
	game.fx.ring(pos, HALF, 360.0, 0.6, Pal.foe(0.9, 1.5), 3.0)
	game.sfx.play("armor", 0.8, 0.0)
	game.add_hitstop(0.09)
	game.cam.add_trauma(0.6)
	game.cam.punch(0.04)
	game.hud.boss_phase()
	# every cable re-energised, one after another
	for k in 3:
		cable_hp[k] = CABLE_HP
		live_k[k] = -0.4 * k
	game.hud.radio(Txt.t("radio_grid_restore"))


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	if state == OFF or state == DEAD:
		return
	t += dt
	flash = maxf(0.0, flash - dt / 0.12)
	red = maxf(0.0, red - dt / 0.8)
	guard_t = maxf(0.0, guard_t - dt)
	for k in 3:
		cable_flash[k] = maxf(0.0, cable_flash[k] - dt / 0.15)
		live_k[k] = minf(1.0, live_k[k] + dt / 0.6)
	match state:
		ENTER:
			if t >= 1.2:
				state = RUN
				t = 0.0
				game.cam.add_trauma(0.4)
				game.sfx.play("slam", 0.6, -2.0)
		RUN:
			_run(dt)
		DYING:
			_dying(dt)
	core_open = 0.0 if shielded() else 1.0
	var i := 0
	while i < bolts.size():
		bolts[i][2] += dt
		if bolts[i][2] > 0.25:
			bolts.remove_at(i)
		else:
			i += 1
	if state == RUN or state == ENTER:
		_shove()
	queue_redraw()


func _shove() -> void:
	var r := _housing()
	var p: Vector2 = game.player.pos
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	var d := p - q
	var l := d.length()
	if l < Player.R:
		var n := d / l if l > 0.01 else Vector2.DOWN
		game.player.pos = q + n * Player.R


func _run(dt: float) -> void:
	mode_t += dt
	# open, the transformer surges: a ring rolls out over the floor; dash it
	if not shielded():
		ring_cd -= dt
		if ring_cd <= 0.0:
			ring_cd = 2.4 - 0.3 * phase
			rings.append([0.0, false])
			game.sfx.play("slam", 0.8, -6.0)
	var p: Vector2 = game.player.pos
	var ri := 0
	while ri < rings.size():
		rings[ri][0] += dt
		var rr: float = RING_R * Pal.ease_out(rings[ri][0] / RING_TIME)
		if not rings[ri][1] and absf(p.distance_to(pos) - rr) < 16.0 and rr > HALF and game.player.dash_t <= 0.0:
			rings[ri][1] = true
			game.on_player_hit((p - pos).normalized(), null)
		if rings[ri][0] >= RING_TIME:
			rings.remove_at(ri)
		else:
			ri += 1
	match mode:
		IDLE:
			zone_cd -= dt
			if zone_cd <= 0.0:
				mode = WARN
				mode_t = 0.0
				zones.clear()
				var n := 1 + phase
				var pick: Array = range(ZONES.size())
				pick.shuffle()
				# the district you stand in is always among the first fed
				var mine := _zone_of(game.player.pos)
				if mine >= 0:
					pick.erase(mine)
					pick.push_front(mine)
				for j in n:
					zones.append(pick[j])
				game.sfx.play("windup", 0.7, -4.0)
		WARN:
			if mode_t >= WARN_TIME:
				mode = FIRE
				mode_t = 0.0
				_discharge()
		FIRE:
			if mode_t >= FIRE_TIME:
				mode = IDLE
				zone_cd = ZONE_EVERY[phase]
				zones.clear()


func _zone_of(p: Vector2) -> int:
	for j in ZONES.size():
		if (ZONES[j] as Rect2).has_point(p):
			return j
	return -1


func _discharge() -> void:
	game.sfx.play("cross", 0.8, 0.0)
	game.cam.add_trauma(0.35)
	for z in zones:
		var r: Rect2 = ZONES[z]
		for j in 5:
			var to := r.position + Vector2(randf_range(40, r.size.x - 40), randf_range(40, r.size.y - 40))
			bolts.append([pos, to, 0.0])
			game.fx.flash(to, 60.0, 0.15, Pal.foe(0.5, 2.0))
		var p: Vector2 = game.player.pos
		if r.has_point(p) and game.player.dash_t <= 0.0:
			game.on_player_hit((p - pos).normalized(), null)
		for e in game.enemies.list:
			if e.state == Enemies.ALIVE and r.has_point(e.pos):
				game.enemies.blast_hit(e, (e.pos - pos).normalized(), 20.0)


func _dying(dt: float) -> void:
	dying_t += dt
	pos = HOME + Vector2(sin(dying_t * 70.0), cos(dying_t * 63.0)) * 3.0 * dying_t
	if dying_t > 0.2 and int(dying_t * 10.0) != int((dying_t - dt) * 10.0):
		var at := pos + Vector2(randf_range(-HALF, HALF), randf_range(-HALF, HALF))
		game.fx.sparks(at, Vector2.from_angle(randf() * TAU), 6, Pal.foe(1.0, 1.8), 420.0, 0.3, 1.0)
		game.sfx.play("cross", randf_range(0.7, 1.3), -6.0)
	if dying_t >= 1.5:
		state = DEAD
		for k in 36:
			var p0 := pos + Vector2(randf_range(-HALF, HALF), randf_range(-HALF, HALF))
			game.fx.shard(p0, Vector2(-9, -4), Vector2(9, 4), (p0 - HOME).normalized() * randf_range(300, 700), randf_range(-12, 12), 1.4, Pal.foe(1.0, 1.7), 2.0)
		game.on_boss_dead(pos)
		queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if state == OFF or state == DEAD:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	var appear := Pal.ease_out(clampf(t / 1.2, 0.0, 1.0)) if state == ENTER else 1.0
	_draw_zones(dim)
	for k in 3:
		_draw_cable(k, dim)
	# the housing: a transformer seen from above — cooling fins on two sides,
	# a coil drum in the middle, insulators at the cable ports
	var r := _housing()
	r = Rect2(r.get_center() - r.size * 0.5 * appear, r.size * appear)
	var col := Pal.foe(dim, 1.0 + 0.8 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	draw_rect(r, Color(0.045, 0.045, 0.05, appear))
	draw_rect(r, col, false, 2.5)
	var fins := PackedVector2Array()
	for j in 9:
		var y := r.position.y + 14.0 + j * (r.size.y - 28.0) / 8.0
		fins.append(Vector2(r.position.x - 22.0 * appear, y))
		fins.append(Vector2(r.position.x, y))
		fins.append(Vector2(r.end.x, y))
		fins.append(Vector2(r.end.x + 22.0 * appear, y))
	draw_multiline(fins, Pal.foe(0.5 * dim), 2.0)
	var open := not shielded()
	var cr := HALF * 0.55 * appear
	draw_circle(pos, cr, Color(0.03, 0.035, 0.04))
	for ring in 3:
		draw_arc(pos, cr * (1.0 - ring * 0.12), 0.0, TAU, 48, Pal.foe((0.35 - ring * 0.08) * dim), 1.5)
	# bushings at the corners and bolts along the lid
	for cx: float in [-1.0, 1.0]:
		for cy: float in [-1.0, 1.0]:
			var bc := pos + Vector2(cx, cy) * (HALF - 20.0) * appear
			draw_circle(bc, 9.0, Color(0.06, 0.06, 0.07))
			draw_arc(bc, 9.0, 0.0, TAU, 14, Pal.foe(0.5 * dim), 1.5)
			draw_arc(bc, 4.0, 0.0, TAU, 10, Pal.foe(0.4 * dim), 1.0)
	var coil := PackedVector2Array()
	for j in 14:
		var a := TAU * j / 14.0 + t * (2.0 if open else 0.6)
		coil.append(pos + Vector2.from_angle(a) * cr * 0.55)
		coil.append(pos + Vector2.from_angle(a) * cr * 0.95)
	draw_multiline(coil, Pal.foe((0.5 if open else 0.3) * dim, 1.4), 2.0)
	draw_circle(pos, cr * 0.4, Pal.foe((0.9 if open else 0.45) * dim, 2.2 if open else 1.2).lerp(Pal.red(dim, 2.2), red * 0.8))
	if not open:
		# the shield: a lit frame round the housing, humming
		var sh := r.grow(10.0 + 2.0 * sin(t * 9.0))
		draw_rect(sh, Pal.foe((0.45 + 0.2 * sin(t * 9.0)) * dim, 1.8), false, 2.0)
	# the screen on its top face: whom it serves first
	var font := Fonts.get_font("SemiBold")
	var sr := Rect2(r.position.x - 20.0, r.position.y - 70.0, r.size.x + 40.0, 54.0)
	draw_rect(sr, Color(0.02, 0.025, 0.03, appear))
	draw_rect(sr, Pal.foe(0.5 * dim * appear), false, 1.5)
	var head := Txt.t("grid_screen")
	var hw := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(sr.get_center().x - hw / 2.0, sr.position.y + 21.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.foe(0.9 * dim * appear, 1.4))
	var sub := Txt.t("grid_open") if open else Txt.t("grid_shield")
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var blink := 1.0 if not open or fmod(t * 3.0, 1.0) < 0.7 else 0.55
	draw_string(font, Vector2(sr.get_center().x - sw / 2.0, sr.position.y + 45.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, (Pal.red(blink * dim, 2.0) if open else Pal.foe(0.6 * dim)))
	for b in bolts:
		var k2: float = 1.0 - b[2] / 0.25
		_bolt(b[0], b[1], k2, dim)
	for rg in rings:
		var kr: float = rg[0] / RING_TIME
		var rr: float = RING_R * Pal.ease_out(kr)
		draw_arc(pos, rr, 0.0, TAU, 96, Pal.foe((1.0 - kr) * dim, 2.4), 4.0)
		draw_arc(pos, rr - 10.0, 0.0, TAU, 96, Pal.foe(0.25 * (1.0 - kr) * dim, 1.4), 10.0)


func _draw_cable(k: int, dim: float) -> void:
	var a := cable_from(k)
	var b := cable_to(k)
	var d := (b - a).normalized()
	var n := d.orthogonal()
	var live: bool = cable_hp[k] > 0.0
	var lk: float = clampf(live_k[k], 0.0, 1.0)
	if not live:
		# cut: two dead ends with a gap where it parted
		var mid := a.lerp(b, 0.5)
		draw_line(a, mid - d * 26.0, Color(0.1, 0.1, 0.11), 9.0)
		draw_line(mid + d * 26.0, b, Color(0.1, 0.1, 0.11), 9.0)
		draw_line(a, mid - d * 26.0, Pal.ink(0.3 * dim), 1.5)
		draw_line(mid + d * 26.0, b, Pal.ink(0.3 * dim), 1.5)
		return
	var energ := a.lerp(b, lk)
	draw_line(a, b, Color(0.08, 0.08, 0.09), 11.0)
	draw_line(a, b, Pal.ink(0.35 * dim), 1.5)
	if lk > 0.0:
		var c := Pal.foe(0.75 * dim, 1.1 + 1.6 * cable_flash[k])
		draw_line(a, energ, Pal.foe(0.05 * dim, 1.2), 10.0)
		draw_line(a, energ, c, 2.0)
		# pulses run from the cabinet into the transformer
		var span := a.distance_to(energ)
		var pl := PackedVector2Array()
		var s := fmod(t * 260.0, 70.0)
		while s < span:
			var q := energ - d * s
			pl.append(q)
			pl.append(q - d * 16.0)
			s += 70.0
		if pl.size() > 0:
			draw_multiline(pl, Pal.foe(0.6 * dim, 2.0), 3.0)
	# its health: a thin bar along its side, the length of the cable's first stretch
	var span2 := minf(220.0, a.distance_to(b) * 0.45)
	var hk: float = clampf(cable_hp[k] / CABLE_HP, 0.0, 1.0)
	var sd := n * (22.0 if n.y <= 0.0 else -22.0)
	draw_line(a + d * 20.0 + sd, a + d * (20.0 + span2) + sd, Pal.foe(0.18 * dim), 3.0)
	draw_line(a + d * 20.0 + sd, a + d * (20.0 + span2 * hk) + sd, Pal.foe(0.55 * dim, 1.2), 3.0)


func _draw_zones(dim: float) -> void:
	if zones.is_empty():
		return
	var font := Fonts.get_font("SemiBold")
	for z in zones:
		var r: Rect2 = ZONES[z]
		if mode == WARN:
			var k := mode_t / WARN_TIME
			var fl := 0.5 + 0.5 * sin(t * (16.0 + 20.0 * k))
			draw_rect(r.grow(-6.0), Pal.red((0.3 + 0.5 * k) * fl * dim, 1.6), false, 2.0 + 2.0 * k)
			var hatch := PackedVector2Array()
			var x := r.position.x + 10.0
			while x < r.end.x - 10.0:
				hatch.append(Vector2(x, r.end.y - 10.0))
				hatch.append(Vector2(minf(x + 30.0, r.end.x - 10.0), r.end.y - 40.0))
				x += 34.0
			draw_multiline(hatch, Pal.red(0.35 * k * dim, 1.4), 2.0)
			var lab := Txt.t("grid_zone")
			var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			var lr := Rect2(Vector2(r.get_center().x - lw / 2.0 - 12.0, r.end.y - 80.0), Vector2(lw + 24.0, 38.0))
			draw_rect(lr, Color(0.05, 0.0, 0.0, 0.85))
			draw_string(font, Vector2(lr.position.x + 12.0, lr.position.y + 29.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.red((0.6 + 0.4 * k) * dim, 2.0))
		else:
			var k2 := 1.0 - mode_t / FIRE_TIME
			draw_rect(r.grow(-6.0), Pal.foe(0.025 * k2, 1.4))
			draw_rect(r.grow(-6.0), Pal.foe(k2 * dim, 2.4), false, 3.0)


func _bolt(a: Vector2, b: Vector2, k: float, dim: float) -> void:
	var d := b - a
	var n := d.orthogonal().normalized()
	var pts := PackedVector2Array([a])
	for j in range(1, 8):
		var u := j / 8.0
		pts.append(a + d * u + n * sin(j * 2.7 + t * 40.0) * 22.0 * (1.0 - absf(u - 0.5)))
	pts.append(b)
	draw_polyline(pts, Pal.foe(0.3 * k * dim, 1.6), 8.0)
	draw_polyline(pts, Pal.foe(k * dim, 3.0), 2.0)
