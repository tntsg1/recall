class_name Peace
extends Node2D
# 在建战舰 · 和平号 THE PEACE, UNDER CONSTRUCTION (chapter 10): a warship being
# built in the middle of the dock. Its hull is eight sections; a section with
# its plate welded on is armour, a bare one is open frame, and a round through
# open frame hurts the ship. Assembly arms on the gantry above weld a plate
# onto the nearest bare section, one after another, raining sparks under them
# while they work; rounds knock plates loose again. Strip it faster than it
# is built. Built far enough, plated sections carry turrets (from the second
# phase) and the bow gun is tested (in the last) — the more it is finished,
# the more it fires.

enum { OFF, ENTER, RUN, DYING, DEAD }
enum { GO, WELD, BACK }

const HP := 2600.0
const N := 8
const X0 := 650.0
const SEC_W := 77.5
const Y0 := 262.0
const H := 140.0
const PLATE_HP := 34.0
const ARMS_N := [2, 2, 3]
const WELD_TIME := [2.8, 2.5, 2.3]
const ARM_Y := 172.0                    # the gantry the arms run on
const SPARK_LEN := 150.0
const SPARK_HALF := 0.33
const TURRETS := [1, 6, 3, 4]           # the sections that carry turrets, in the order they arm
const TURRET_N := [0, 2, 4]
const SHOT_EVERY := [9.0, 3.4, 2.8]
const SHOT_WARN := 0.6
const SHELL_SPEED := 460.0
const GUN_EVERY := 6.5
const GUN_WARN := 1.1
const GUN_FIRE := 0.35
const BOW := Vector2(1360, 332)
const STAGE_KEYS := ["peace_stage_0", "peace_stage_1", "peace_stage_2"]

var game
var state := OFF
var t := 0.0
var hp := HP
var phase := 0
var core_open := 0.0
var flash := 0.0
var red := 0.0
var guard_t := 0.0
var dying_t := 0.0
var enter_t := 0.0
var plate := []                         # per section: plate hp (0 = bare)
var plate_flash := []
var arms: Array = []                    # {x, target, mode, t}
var turret_cd := []
var turret_aim := []                    # per turret: -1 idle, else warning time
var shells: Array = []                  # [pos, vel, life]
var gun_cd := 0.0
var gun_t := -1.0                       # -1 idle; 0..GUN_WARN aiming; then firing
var gun_a := PI
var shown_pct := 0.0


func _ready() -> void:
	z_index = 3
	z_as_relative = false


func max_hp() -> float:
	return HP


func name_key() -> String:
	return "boss_peace"


func alive() -> bool:
	return state == ENTER or state == RUN or state == DYING


func begin_track() -> void:
	state = OFF
	enter_t = 0.0001


func start() -> void:
	state = ENTER
	t = 0.0
	_fresh()
	game.sfx.play("horn", 0.5, -2.0)
	game.cam.add_trauma(0.3)
	game.hud.radio(Txt.t("radio_peace"))


func reset() -> void:
	state = OFF
	t = 0.0
	enter_t = 0.0
	_fresh()


func _fresh() -> void:
	hp = HP
	phase = 0
	core_open = 0.0
	guard_t = 0.0
	flash = 0.0
	red = 0.0
	plate = []
	plate_flash = []
	for k in N:
		plate.append(PLATE_HP if k % 2 == 0 else 0.0)
		plate_flash.append(0.0)
	arms.clear()
	for k in 3:
		arms.append({"x": X0 + SEC_W * (1.5 + 2.5 * k), "target": -1, "mode": GO, "t": 0.0})
	turret_cd = [1.5, 2.3, 1.9, 2.7]
	turret_aim = [-1.0, -1.0, -1.0, -1.0]
	shells.clear()
	gun_cd = 3.0
	gun_t = -1.0
	shown_pct = 0.0
	if game != null:
		game.arena.soft.clear()


func dev_strike() -> void:
	if state != RUN:
		return
	guard_t = 0.0
	for k in N:
		plate[k] = 0.0
	damage(HP, false, sec_rect(0).get_center(), Vector2.UP)


func sec_rect(k: int) -> Rect2:
	return Rect2(X0 + SEC_W * k, Y0, SEC_W, H)


func hull() -> Rect2:
	return Rect2(X0 - 70.0, Y0, SEC_W * N + 70.0 + 90.0, H)


func bare(k: int) -> bool:
	return plate[k] <= 0.0


func turret_on(j: int) -> bool:
	return j < TURRET_N[phase] and not bare(TURRETS[j])


func turret_pos(j: int) -> Vector2:
	var r := sec_rect(TURRETS[j])
	return Vector2(r.get_center().x, r.end.y - 22.0)


# How far along it is: a third a stage, and the plates on this stage's hull.
func progress() -> float:
	var n := 0
	for k in N:
		if not bare(k):
			n += 1
	return clampf((phase + float(n) / N) / 3.0, 0.0, 0.99)


func core_pos() -> Vector2:
	# the open frame nearest the middle
	var best := sec_rect(N / 2).get_center()
	var bd := INF
	for k in N:
		if bare(k):
			var c := sec_rect(k).get_center()
			var d := absf(c.x - 960.0)
			if d < bd:
				bd = d
				best = c
	return best


func core_vel() -> Vector2:
	return Vector2.ZERO


# ---------------------------------------------------------------- bullets

func hit_test(a: Vector2, b: Vector2) -> Dictionary:
	if not (state == RUN or state == ENTER):
		return {}
	var best := {}
	var bt := 2.0
	# the bow and the engine block are armour always
	for r: Rect2 in [Rect2(X0 - 70.0, Y0 + 10.0, 70.0, H - 20.0), Rect2(X0 + SEC_W * N, Y0 + 14.0, 90.0, H - 28.0)]:
		var h0 := _rect_hit(a, b, r)
		if not h0.is_empty() and h0.t < bt:
			bt = h0.t
			best = {"point": h0.point, "normal": h0.normal, "core": false, "car": -1}
	for k in N:
		var h := _rect_hit(a, b, sec_rect(k))
		if h.is_empty() or h.t >= bt:
			continue
		bt = h.t
		if bare(k):
			# one wound a pass, however many open sections the round crosses
			best = {"point": h.point, "normal": h.normal, "core": true, "mult": 1.0, "frame": 20, "car": k}
		else:
			best = {"point": h.point, "normal": h.normal, "core": false, "car": k}
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


# A round on a plate knocks at it; enough knocks and it comes away.
func on_armor(k: int, at_p: Vector2, normal: Vector2) -> void:
	game.fx.sparks(at_p, normal, 6, Pal.foe(1.0, 2.0), 460.0, 0.2, 0.9)
	game.fx.flash(at_p, 18.0, 0.1, Pal.foe(0.5, 1.6))
	game.sfx.play("shield", randf_range(0.85, 1.0), -8.0)
	if k < 0 or state != RUN or bare(k):
		return
	plate[k] = maxf(0.0, plate[k] - 14.0)
	plate_flash[k] = 1.0
	if bare(k):
		# the plate tears away, spinning off
		var r := sec_rect(k)
		game.sfx.play("cross", 0.7, -3.0)
		game.cam.add_trauma(0.2)
		game.fx.shard(r.get_center(), Vector2(-SEC_W * 0.45, -10), Vector2(SEC_W * 0.45, 10), normal * randf_range(260, 420) + Vector2(randf_range(-80, 80), 0), randf_range(-6, 6), 1.2, Pal.foe(0.9, 1.5), 2.0)
		for j in turret_aim.size():
			if TURRETS[j] == k:
				turret_aim[j] = -1.0


func damage(dmg: float, ret: bool, at_p: Vector2, d: Vector2, _frame_k: int = -1) -> void:
	if state != RUN:
		return
	dmg /= Loadout.boss_hp()
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
		game.on_boss_dying()


func _phase_break() -> void:
	guard_t = 1.4
	game.fx.ring(hull().get_center(), 120.0, 520.0, 0.6, Pal.foe(0.9, 1.5), 3.0)
	game.sfx.play("armor", 0.7, 0.0)
	game.add_hitstop(0.09)
	game.cam.add_trauma(0.6)
	game.cam.punch(0.04)
	game.hud.boss_phase()
	# the stage is done: the next stage's hull starts half plated again
	for k in N:
		if k % 2 == 0 and bare(k):
			plate[k] = PLATE_HP
	game.hud.radio(Txt.t("radio_peace_1" if phase == 1 else "radio_peace_2"))


# ---------------------------------------------------------------- update

func step(dt: float) -> void:
	if state == OFF or state == DEAD:
		return
	t += dt
	flash = maxf(0.0, flash - dt / 0.12)
	red = maxf(0.0, red - dt / 0.8)
	guard_t = maxf(0.0, guard_t - dt)
	for k in N:
		plate_flash[k] = maxf(0.0, plate_flash[k] - dt / 0.15)
	match state:
		ENTER:
			if t >= 1.2:
				state = RUN
				t = 0.0
		RUN:
			_run(dt)
		DYING:
			_dying(dt)
	var open := false
	for k in N:
		if bare(k):
			open = true
	core_open = 1.0 if state == RUN and open else 0.0
	shown_pct = lerpf(shown_pct, progress(), 1.0 - exp(-4.0 * dt))
	_step_shells(dt)
	if state == RUN or state == ENTER:
		var soft: Array[Rect2] = [hull()]
		game.arena.soft = soft
	queue_redraw()


func _run(dt: float) -> void:
	var p: Vector2 = game.player.pos
	# the arms: to the nearest bare section nobody is on, weld, back
	for ai in ARMS_N[phase]:
		var arm: Dictionary = arms[ai]
		arm.t += dt
		match arm.mode:
			GO:
				if arm.target < 0 or not bare(arm.target):
					arm.target = _pick(ai, arm.x)
				if arm.target >= 0:
					var tx := sec_rect(arm.target).get_center().x
					arm.x = move_toward(arm.x, tx, 260.0 * dt)
					if absf(arm.x - tx) < 1.0:
						arm.mode = WELD
						arm.t = 0.0
						game.sfx.play("windup", 1.4, -12.0)
			WELD:
				if not bare(arm.target):
					arm.mode = GO
				elif arm.t >= WELD_TIME[phase]:
					plate[arm.target] = PLATE_HP
					plate_flash[arm.target] = 1.0
					game.sfx.play("slam", 1.5, -8.0)
					game.fx.sparks(sec_rect(arm.target).get_center() + Vector2(0, H * 0.5), Vector2.DOWN, 10, Pal.ink(1.0, 2.0), 300.0, 0.3, 0.9)
					arm.mode = GO
					arm.target = -1
				else:
					_spark_hit(arm, p)
	# turrets on plated sections, from the second stage
	for j in TURRETS.size():
		if not turret_on(j):
			continue
		if turret_aim[j] < 0.0:
			turret_cd[j] -= dt
			if turret_cd[j] <= 0.0:
				turret_aim[j] = 0.0
		else:
			turret_aim[j] += dt
			if turret_aim[j] >= SHOT_WARN:
				turret_aim[j] = -1.0
				turret_cd[j] = SHOT_EVERY[phase] + randf_range(-0.3, 0.3)
				var tp := turret_pos(j)
				var dir := (p - tp).normalized()
				var burst := 2 if phase == 1 else 3
				for s in burst:
					shells.append([tp + dir * 20.0, dir.rotated((s - (burst - 1) * 0.5) * 0.14) * SHELL_SPEED, 2.4])
				game.sfx.play("shot", 0.6, -6.0)
	# the bow gun, tested in the last stage
	if phase == 2:
		if gun_t < 0.0:
			gun_cd -= dt
			if gun_cd <= 0.0:
				gun_t = 0.0
				gun_a = (p - BOW).angle()
				game.sfx.play("windup", 0.4, -2.0)
		else:
			gun_t += dt
			if gun_t < GUN_WARN - 0.3:
				gun_a = lerp_angle(gun_a, (p - BOW).angle(), 1.0 - exp(-3.0 * dt))
			if gun_t >= GUN_WARN and gun_t - dt < GUN_WARN:
				game.sfx.play("cross", 0.5, 2.0)
				game.cam.add_trauma(0.5)
			if gun_t >= GUN_WARN and gun_t < GUN_WARN + GUN_FIRE:
				var q := Geometry2D.get_closest_point_to_segment(p, BOW, BOW + Vector2.from_angle(gun_a) * 2400.0)
				if q.distance_to(p) < 26.0 and game.player.dash_t <= 0.0:
					game.on_player_hit(Vector2.from_angle(gun_a).orthogonal(), null)
					gun_t = GUN_WARN + GUN_FIRE
			if gun_t >= GUN_WARN + GUN_FIRE:
				gun_t = -1.0
				gun_cd = GUN_EVERY


func _pick(ai: int, x: float) -> int:
	var best := -1
	var bd := INF
	for k in N:
		if not bare(k):
			continue
		var taken := false
		for aj in ARMS_N[phase]:
			if aj != ai and arms[aj].target == k:
				taken = true
		if taken:
			continue
		var d := absf(sec_rect(k).get_center().x - x)
		if d < bd:
			bd = d
			best = k
	return best


# Welding rains sparks in a cone under the section: stand clear.
func _spark_hit(arm: Dictionary, p: Vector2) -> void:
	if arm.t < 0.5:
		return
	var o := Vector2(arm.x, Y0 + H)
	var v := p - o
	if v.length() < SPARK_LEN and absf(wrapf(v.angle() - PI * 0.5, -PI, PI)) < SPARK_HALF and game.player.dash_t <= 0.0:
		if game.on_player_hit(v.normalized(), null):
			pass


func _step_shells(dt: float) -> void:
	var p: Vector2 = game.player.pos
	var i := 0
	while i < shells.size():
		var s: Array = shells[i]
		var a: Vector2 = s[0]
		var b: Vector2 = a + (s[1] as Vector2) * dt
		s[2] = float(s[2]) - dt
		var gone := float(s[2]) <= 0.0
		var h: Dictionary = game.arena.raycast(a, b)
		if h:
			gone = true
			game.fx.sparks(h.point, h.normal, 3, Pal.red(0.8, 2.0), 200.0, 0.15, 0.8)
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if not gone and q.distance_to(p) < Player.R + 5.0 and game.player.dash_t <= 0.0:
			game.on_player_hit((s[1] as Vector2).normalized(), null)
			gone = true
		if gone or state == DEAD:
			shells.remove_at(i)
		else:
			s[0] = b
			i += 1


func _dying(dt: float) -> void:
	dying_t += dt
	var c := hull().get_center()
	if dying_t > 0.2 and int(dying_t * 10.0) != int((dying_t - dt) * 10.0):
		var at := c + Vector2(randf_range(-330, 330), randf_range(-60, 60))
		game.fx.sparks(at, Vector2.from_angle(randf() * TAU), 6, Pal.foe(1.0, 1.8), 420.0, 0.3, 1.0)
		game.sfx.play("cross", randf_range(0.6, 1.0), -6.0)
	if dying_t >= 1.5:
		state = DEAD
		shells.clear()
		game.arena.soft.clear()
		for k in 44:
			var p0 := c + Vector2(randf_range(-340, 340), randf_range(-70, 70))
			game.fx.shard(p0, Vector2(-16, -5), Vector2(16, 5), (p0 - c).normalized() * randf_range(300, 700), randf_range(-12, 12), 1.4, Pal.foe(1.0, 1.7) if k % 3 else Pal.ink(0.9, 1.4), 2.0)
		game.on_boss_dead(c)
		queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if state == OFF or state == DEAD:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	var appear := Pal.ease_out(clampf(t / 1.2, 0.0, 1.0)) if state == ENTER else 1.0
	_draw_hull(dim * appear)
	_draw_gantry(dim * appear)
	_draw_weapons(dim)
	_draw_board(dim * appear)


# The ship from above: the engine block astern (left), the bow forward
# (right), eight sections between. Plated, a section is armour with rivets
# and its seams; bare, it is open frame — ribs over the glowing core.
func _draw_hull(dim: float) -> void:
	var font := Fonts.get_font("SemiBold")
	var col := Pal.foe(dim, 1.0 + 0.8 * flash).lerp(Pal.red(dim, 2.4), red * 0.8)
	var hr := hull()
	draw_rect(hr.grow(8.0), Color(0, 0, 0, 0.45))
	# engine block and nozzles
	var eng := Rect2(X0 - 70.0, Y0 + 10.0, 70.0, H - 20.0)
	draw_rect(eng, Color(0.05, 0.05, 0.055))
	draw_rect(eng, col, false, 2.0)
	for j in 3:
		var nz := Vector2(eng.position.x - 10.0, eng.position.y + 20.0 + j * (eng.size.y - 40.0) / 2.0)
		draw_rect(Rect2(nz - Vector2(0, 10), Vector2(12, 20)), Pal.foe(0.6 * dim), false, 1.5)
	# bow
	var bx := X0 + SEC_W * N
	var bow := PackedVector2Array([Vector2(bx, Y0 + 14.0), Vector2(bx + 60.0, Y0 + 26.0), Vector2(bx + 110.0, Y0 + H * 0.5), Vector2(bx + 60.0, Y0 + H - 26.0), Vector2(bx, Y0 + H - 14.0)])
	draw_colored_polygon(bow, Color(0.05, 0.05, 0.055))
	draw_polyline(bow, col, 2.0)
	# the sections
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	for k in N:
		var r := sec_rect(k)
		if bare(k):
			draw_rect(r, Color(0.02, 0.02, 0.025))
			# ribs, and the core glowing through
			var cg := Rect2(r.position + Vector2(10, 22), r.size - Vector2(20, 44))
			draw_rect(cg, Pal.foe((0.05 + 0.04 * pulse) * dim, 1.2))
			var ribs := PackedVector2Array()
			for j in 4:
				var x := r.position.x + 8.0 + j * (r.size.x - 16.0) / 3.0
				ribs.append(Vector2(x, r.position.y + 4.0))
				ribs.append(Vector2(x, r.end.y - 4.0))
			draw_multiline(ribs, Pal.foe(0.55 * dim), 2.0)
			draw_line(Vector2(r.position.x + 4.0, r.get_center().y), Vector2(r.end.x - 4.0, r.get_center().y), Pal.foe((0.5 + 0.3 * pulse) * dim, 1.5), 3.0)
			# the core showing through: a bright pulse ring, the place to hit
			draw_circle(r.get_center(), 8.0, Pal.foe((0.6 + 0.3 * pulse) * dim, 1.5))
			draw_arc(r.get_center(), 16.0 + 6.0 * pulse, 0.0, TAU, 24, Pal.foe((0.8 - 0.4 * pulse) * dim, 1.4), 2.5)
			draw_rect(r, Pal.foe(0.5 * dim), false, 1.0)
		else:
			var pk: float = plate[k] / PLATE_HP
			draw_rect(r, Color(0.07, 0.07, 0.075))
			draw_rect(r.grow(-3.0), Pal.foe((0.55 + 0.4 * plate_flash[k]) * dim, 1.0 + plate_flash[k]), false, 2.0)
			for j in 5:
				draw_circle(Vector2(r.position.x + 9.0 + j * (r.size.x - 18.0) / 4.0, r.position.y + 9.0), 1.6, Pal.foe(0.45 * dim))
				draw_circle(Vector2(r.position.x + 9.0 + j * (r.size.x - 18.0) / 4.0, r.end.y - 9.0), 1.6, Pal.foe(0.45 * dim))
			# dents and cracks as it is knocked
			if pk < 0.7:
				draw_line(r.position + Vector2(14, 30), r.position + Vector2(30, 52), Pal.ink(0.4 * dim), 1.5)
			if pk < 0.4:
				draw_line(r.end - Vector2(14, 30), r.end - Vector2(34, 58), Pal.ink(0.45 * dim), 1.5)
				draw_line(r.get_center() + Vector2(-10, 6), r.get_center() + Vector2(12, -8), Pal.ink(0.4 * dim), 1.5)
	draw_rect(hr, col, false, 2.5)
	# its name along the hull
	var nm := Txt.t("peace_name")
	var fs := 26
	var nw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var na := Vector2(X0 + SEC_W * 2.0 - nw * 0.5, Y0 + H * 0.5 + fs * 0.36)
	draw_rect(Rect2(na + Vector2(-10, -fs), Vector2(nw + 20, fs + 10)), Color(0.04, 0.04, 0.045, 0.85))
	draw_string(font, na, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.92 * dim, 1.3))


# The gantry over the ship and its arms: each a carriage, a jointed arm down
# to the section it works on, the torch white-hot and sparks raining.
func _draw_gantry(dim: float) -> void:
	var y := ARM_Y
	draw_line(Vector2(X0 - 90.0, y - 6.0), Vector2(X0 + SEC_W * N + 120.0, y - 6.0), Pal.foe(0.5 * dim), 2.0)
	draw_line(Vector2(X0 - 90.0, y + 6.0), Vector2(X0 + SEC_W * N + 120.0, y + 6.0), Pal.foe(0.5 * dim), 2.0)
	for sx: float in [X0 - 80.0, X0 + SEC_W * N + 110.0]:
		draw_line(Vector2(sx, y), Vector2(sx, Y0 + H * 0.5), Pal.foe(0.35 * dim), 3.0)
	for ai in ARMS_N[phase]:
		var arm: Dictionary = arms[ai]
		var x: float = arm.x
		var car := Rect2(Vector2(x - 20.0, y - 12.0), Vector2(40, 24))
		draw_rect(car, Color(0.06, 0.06, 0.065))
		draw_rect(car, Pal.foe(0.8 * dim), false, 1.5)
		var welding: bool = arm.mode == WELD
		var reach := Y0 + H - 12.0 if welding else Y0 + 30.0
		var elbow := Vector2(x + 26.0, lerpf(y, reach, 0.5))
		var tip := Vector2(x, reach)
		draw_polyline(PackedVector2Array([Vector2(x, y + 12.0), elbow, tip]), Pal.foe(0.7 * dim), 3.0)
		draw_circle(elbow, 4.0, Pal.foe(0.7 * dim))
		if welding:
			var wk: float = clampf(arm.t / WELD_TIME[phase], 0.0, 1.0)
			draw_circle(tip, 4.0 + 1.5 * sin(t * 40.0), Pal.ink(0.85 * dim, 1.8))
			# the plate going on, its edge closing
			var r := sec_rect(arm.target)
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * wk)), Pal.foe(0.12 * dim, 1.2))
			draw_line(Vector2(r.position.x, r.position.y + r.size.y * wk), Vector2(r.end.x, r.position.y + r.size.y * wk), Pal.ink(0.8 * dim, 1.8), 2.0)
			# the sparks raining under it: the cone to keep out of
			if arm.t >= 0.5:
				var o := Vector2(x, Y0 + H)
				var cone := PackedVector2Array([o, o + Vector2.from_angle(PI * 0.5 - SPARK_HALF) * SPARK_LEN, o + Vector2.from_angle(PI * 0.5 + SPARK_HALF) * SPARK_LEN])
				draw_colored_polygon(cone, Pal.red(0.03 * dim, 1.2))
				draw_polyline(PackedVector2Array([cone[1], o, cone[2]]), Pal.red(0.55 * dim, 1.5), 1.5)
				var sp := PackedVector2Array()
				for j in 10:
					var u := fmod(t * 2.6 + j * 0.37, 1.0)
					var aa := PI * 0.5 + sin(j * 2.7) * SPARK_HALF
					var q := o + Vector2.from_angle(aa) * SPARK_LEN * u
					sp.append(q)
					sp.append(q + Vector2.from_angle(aa) * 8.0)
				draw_multiline(sp, Pal.ink(0.8 * dim, 2.0), 1.5)
			elif arm.t < 0.5:
				var o2 := Vector2(x, Y0 + H)
				draw_arc(o2, SPARK_LEN * arm.t / 0.5, PI * 0.5 - SPARK_HALF, PI * 0.5 + SPARK_HALF, 10, Pal.red(0.6 * dim, 1.4), 1.5)


# Turrets, their aim, the shells; the bow gun's test.
func _draw_weapons(dim: float) -> void:
	for j in TURRETS.size():
		if not turret_on(j):
			continue
		var tp := turret_pos(j)
		var aim: Vector2 = (game.player.pos - tp).normalized()
		draw_circle(tp, 24.0, Color(0.05, 0.05, 0.055))
		draw_arc(tp, 24.0, 0.0, TAU, 28, Pal.foe(0.9 * dim, 1.3), 2.5)
		draw_arc(tp, 15.0, 0.0, TAU, 20, Pal.foe(0.5 * dim), 1.5)
		draw_line(tp + aim.orthogonal() * 5.0, tp + aim.orthogonal() * 5.0 + aim * 40.0, Pal.foe(0.95 * dim, 1.5), 5.0)
		draw_line(tp - aim.orthogonal() * 5.0, tp - aim.orthogonal() * 5.0 + aim * 40.0, Pal.foe(0.95 * dim, 1.5), 5.0)
		if turret_aim[j] >= 0.0:
			var k: float = turret_aim[j] / SHOT_WARN
			var fl := 0.6 + 0.4 * sin(t * 30.0)
			var bn := 2 if phase == 1 else 3
			for s in bn:
				var d: Vector2 = aim.rotated((s - (bn - 1) * 0.5) * 0.14)
				draw_line(tp + d * 26.0, tp + d * (120.0 + 380.0 * k), Pal.red((0.25 + 0.5 * k) * fl * dim, 1.4), 1.5)
	for s in shells:
		var a: Vector2 = s[0]
		var v: Vector2 = s[1]
		draw_line(a, a - v.normalized() * 22.0, Pal.red(0.5 * dim, 1.8), 3.0)
		draw_circle(a, 5.0, Pal.red(dim, 2.4))
	if gun_t >= 0.0:
		var d2 := Vector2.from_angle(gun_a)
		var far := BOW + d2 * 2400.0
		if gun_t < GUN_WARN:
			var k2 := gun_t / GUN_WARN
			var fl2 := 0.55 + 0.45 * sin(t * (18.0 + 24.0 * k2))
			# the footprint it will burn, filling in
			draw_line(BOW, far, Pal.red(0.05 * k2 * dim, 1.0), 52.0)
			draw_line(BOW, far, Pal.red((0.2 + 0.6 * k2) * fl2 * dim, 1.6), 1.5 + 2.5 * k2)
			draw_line(BOW + d2.orthogonal() * 26.0, far + d2.orthogonal() * 26.0, Pal.red((0.25 + 0.4 * k2) * dim, 1.3), 2.0)
			draw_line(BOW - d2.orthogonal() * 26.0, far - d2.orthogonal() * 26.0, Pal.red((0.25 + 0.4 * k2) * dim, 1.3), 2.0)
			draw_circle(BOW, 10.0 + 14.0 * k2, Pal.red(0.5 * k2 * fl2 * dim, 1.8))
		else:
			var k3 := 1.0 - (gun_t - GUN_WARN) / GUN_FIRE
			draw_line(BOW, far, Color(0, 0, 0, 0.5 * k3), 90.0)
			draw_line(BOW, far, Pal.red(0.3 * k3 * dim, 1.4), 64.0)
			draw_line(BOW, far, Pal.red(k3 * dim, 2.6), 26.0)
			draw_line(BOW, far, Pal.ink(k3 * dim, 2.6), 6.0)
			draw_circle(BOW, 40.0 * k3, Pal.ink(0.8 * k3 * dim, 2.4))


# The progress board on the gantry: the stage, the percentage, a bar.
func _draw_board(dim: float) -> void:
	var font := Fonts.get_font("SemiBold")
	var r := Rect2(X0 + SEC_W * N + 150.0, ARM_Y - 30.0, 240.0, 62.0)
	draw_rect(r, Color(0.03, 0.03, 0.035, 0.95))
	draw_rect(r, Pal.foe(0.55 * dim), false, 1.5)
	draw_string(font, r.position + Vector2(12, 22), Txt.t(STAGE_KEYS[phase]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.7 * dim))
	var pct := Txt.t("peace_progress") % int(round(shown_pct * 100.0))
	draw_string(font, r.position + Vector2(12, 46), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.foe(0.95 * dim, 1.5))
	var bar := Rect2(r.position + Vector2(12, 52), Vector2(r.size.x - 24.0, 4.0))
	draw_rect(bar, Pal.ink(0.12 * dim))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * shown_pct, bar.size.y)), Pal.foe(0.9 * dim, 1.6))
