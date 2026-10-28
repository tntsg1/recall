class_name Bullets
extends Node2D
# Every bullet keeps the polyline it really flew. Embedded rounds wait in the
# walls; a recall runs that exact polyline backwards to the spot it was fired
# from, then a short arc carries the round home into the magazine.

enum { FLY, EMBED, PULL, RETURN, HOME, FADE, ORBIT, CAPTURED }

const SPEED := 1500.0
const RETURN_SPEED := 4500.0
const LIFE := 12.0
const WARN := 3.0
const MAX := 600
const CHILD_MAX := 260   # past this, splits fold into damage; originals always get a slot
const OUT_DMG := 10.0
const RET_DMG := 20.0
const LIGHT_SPEED := 2600.0   # px per real second the "light up" ripple spreads
const CHILD_DMG := 6.0
const ORBIT_DMG := 10.0
const ORBIT_SPIN := 7.5

class B:
	var state := 0
	var pos := Vector2.ZERO
	var dir := Vector2.RIGHT
	var path := PackedVector2Array()   # origin, bounce points..., head / embed point
	var cum := PackedFloat32Array()    # cumulative length at each path point
	var s := 0.0                       # distance along the path
	var bounces := 0
	var life := 0.0
	var t := 0.0
	var delay := 0.0
	var light := 0.0
	var light_delay := -1.0
	var preview := 0.0
	var hit := {}
	var home_from := Vector2.ZERO
	var home_side := 1.0
	var home_dur := 0.3
	var hist := PackedVector2Array()
	var seed := 0.0
	var dmg := OUT_DMG
	var settled := false
	var child := false        # a split-off round: it never refills the magazine
	var gen := 0
	var orbit_left := 0.0
	var orbit_a := 0.0
	var orbit_r := 46.0
	var orbit_from := Vector2.ZERO
	var hit_clear := 0.0
	var orbited := false
	var crit := false
	var bends := 0
	var refracted := false
	var just_bent := false
	var holder = null           # who is carrying a captured round
	var hold_a := 0.0
	var hold_t := 0.0
	var charge := 0             # blast school: pierces stored on the way back
	var piercer := false        # charge lv3: a long-held round ignores shields on the way back
	var foe := false            # one of Zero's rounds
	var zero_pass := false      # Zero is recalling it: it cuts you on the way back
	var zlight := 0.0
	var home_zero := false      # you recalled Zero's round: it flies on into Zero
	var shadow := false
	var first_bonus := false
	var last_hit := Vector2.ZERO
	var via_done := false       # bent once through a seized leech's well on the way home

	func total() -> float:
		return cum[cum.size() - 1]

	func set_head(p: Vector2) -> void:
		var n := path.size()
		path[n - 1] = p
		cum[n - 1] = cum[n - 2] + path[n - 2].distance_to(p)

	func sample(at: float) -> Vector2:
		var n := path.size()
		at = clampf(at, 0.0, cum[n - 1])
		for i in range(1, n):
			if at <= cum[i]:
				var seg := cum[i] - cum[i - 1]
				var f := 0.0 if seg <= 0.0 else (at - cum[i - 1]) / seg
				return path[i - 1].lerp(path[i], f)
		return path[n - 1]

	# Points of the path between distances a and b (either order), vertices included.
	func sub(a: float, b: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		out.append(sample(a))
		var n := path.size()
		if a < b:
			for i in n:
				if cum[i] > a and cum[i] < b:
					out.append(path[i])
		else:
			for i in range(n - 1, -1, -1):
				if cum[i] < a and cum[i] > b:
					out.append(path[i])
		out.append(sample(b))
		return out

var list: Array[B] = []
var game
var mm: MultiMesh
var mm_node: MultiMeshInstance2D
var paths: Node2D
var faint: Node2D
var faint_dirty := true
var glow: Node2D
var glow_tex: Texture2D
var ring_tex: Texture2D
var scars: Array = []   # [pos, normal, age]
var lit_ticks := 0
var life_max := LIFE


func _ready() -> void:
	z_index = 1
	z_as_relative = false
	paths = Node2D.new()
	paths.z_index = -5
	paths.z_as_relative = false
	paths.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paths.draw.connect(_draw_paths)
	add_child(paths)
	faint = Node2D.new()
	faint.z_index = -6
	faint.z_as_relative = false
	faint.draw.connect(_draw_faint)
	add_child(faint)
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	mm_node = MultiMeshInstance2D.new()
	mm_node.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/bullet.gdshader")
	mm_node.material = mat
	add_child(mm_node)
	glow = Node2D.new()
	glow.z_index = 6
	glow.z_as_relative = false
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	glow.draw.connect(_draw_glow)
	add_child(glow)
	glow_tex = Fx.make_glow_texture()
	ring_tex = Fx.make_ring_texture()


func count_state(st: int) -> int:
	var n := 0
	for b in list:
		if b.state == st:
			n += 1
	return n


func in_flight_home() -> int:
	var n := 0
	for b in list:
		if b.state != HOME:
			n += 1
	return n


# Twin: a free split round beside every shot.
func twin(origin: Vector2, dir: Vector2) -> void:
	if list.size() >= CHILD_MAX:
		return
	var c := B.new()
	c.child = true
	c.gen = 1
	c.pos = origin
	c.dir = dir.normalized()
	c.path = PackedVector2Array([origin, origin])
	c.cum = PackedFloat32Array([0.0, 0.0])
	c.seed = randf() * 100.0
	c.dmg = CHILD_DMG
	c.bounces = game.lv.bounce
	list.append(c)


# Spare Rounds: the oldest embedded originals fly straight home.
func quick_home(n: int) -> void:
	var c: Array[B] = []
	for b in list:
		if b.state == EMBED and not b.child:
			c.append(b)
	c.sort_custom(func(x: B, y: B) -> bool: return x.life > y.life)
	for i in mini(n, c.size()):
		var b := c[i]
		if b.settled:
			b.settled = false
			faint_dirty = true
		_go_home(b)
		game.fx.flash(b.pos, 22.0, 0.15, Pal.red(0.6, 2.0))


# A leech or the devourer takes an embedded round. It stays one of yours.
func capture(b: B, holder) -> void:
	if b.settled:
		b.settled = false
		faint_dirty = true
	b.state = CAPTURED
	b.holder = holder
	b.hold_a = randf() * TAU
	b.hold_t = 0.0
	b.light = 0.0
	b.t = 0.0
	b.hist = PackedVector2Array([b.pos])


func held_by(holder) -> Array[B]:
	var out: Array[B] = []
	for b in list:
		if b.state == CAPTURED and b.holder == holder:
			out.append(b)
	return out


# Let go of a captured round: fling it out (it flies and embeds as usual).
func fling(b: B, dir: Vector2) -> void:
	b.holder = null
	b.state = FLY
	b.t = 0.0
	b.dir = dir.normalized()
	b.path = PackedVector2Array([b.pos, b.pos])
	b.cum = PackedFloat32Array([0.0, 0.0])
	b.hit.clear()
	b.dmg = game.out_dmg() if not b.child else CHILD_DMG
	b.bounces = 0
	b.bends = 0
	b.refracted = false


# A leech dies: what it carried settles where it fell, ready to recall.
func drop(b: B) -> void:
	b.holder = null
	b.state = EMBED
	b.t = 0.0
	b.life = 0.0
	b.light = 0.0
	b.hit.clear()
	b.path = PackedVector2Array([b.pos - b.dir * 2.0, b.pos])
	b.cum = PackedFloat32Array([0.0, 2.0])
	b.bounces = 0
	game.fx.flash(b.pos, 16.0, 0.12, Pal.you(0.6, 1.5))


# Straight home (Recall Order, Leech Ward).
func send_home(b: B) -> void:
	b.holder = null
	_go_home(b)


# ---- Zero's rounds
func fire_foe(origin: Vector2, dir: Vector2) -> void:
	var b := B.new()
	b.foe = true
	b.child = true
	b.pos = origin
	b.dir = dir.normalized()
	b.path = PackedVector2Array([origin, origin])
	b.cum = PackedFloat32Array([0.0, 0.0])
	b.seed = randf() * 100.0
	b.dmg = 0.0
	list.append(b)


func zero_light() -> void:
	for b in list:
		if b.foe and b.state == EMBED:
			b.zlight = 0.001


func zero_recall() -> int:
	var n := 0
	for b in list:
		if b.foe and b.state == EMBED:
			b.state = PULL
			b.t = 0.0
			b.delay = randf_range(0.0, 0.12)
			b.zero_pass = true
			b.hit.clear()
			if b.settled:
				b.settled = false
				faint_dirty = true
			n += 1
	return n


func clear_foe() -> void:
	for b in list:
		if b.foe and b.state != FADE:
			b.state = FADE
			b.t = 0.0


func originals_alive() -> int:
	var n := 0
	for b in list:
		if not b.child and b.state != FADE:
			n += 1
	return n


func orbit_count() -> int:
	var n := 0
	for b in list:
		if b.state == ORBIT:
			n += 1
	return n


# Chapter change: every original round comes home at once (returns how many);
# split rounds simply go.
func clear_for_chapter() -> int:
	var n := 0
	for b in list:
		if not b.child and b.state != FADE:
			n += 1
	list.clear()
	scars.clear()
	faint_dirty = true
	return n


func recall_active() -> bool:
	for b in list:
		if b.state == PULL or b.state == RETURN:
			return true
	return false


func fire(origin: Vector2, dir: Vector2) -> void:
	var b := B.new()
	b.pos = origin
	b.dir = dir.normalized()
	b.path = PackedVector2Array([origin, origin])
	b.cum = PackedFloat32Array([0.0, 0.0])
	b.seed = randf() * 100.0
	b.bounces = game.lv.bounce
	b.dmg = game.out_dmg()
	list.append(b)


# Lv3 orbit: the orbiting round nearest the aim leaves the ring toward it.
func fire_from_orbit(aim_at: Vector2) -> bool:
	var best: B = null
	var bd := INF
	for b in list:
		if b.state == ORBIT:
			var d: float = (b.pos - game.player.pos).normalized().distance_to((aim_at - game.player.pos).normalized())
			if d < bd:
				bd = d
				best = b
	if best == null:
		return false
	var dir := (aim_at - best.pos).normalized()
	best.state = FLY
	best.t = 0.0
	best.dir = dir
	best.path = PackedVector2Array([best.pos, best.pos])
	best.cum = PackedFloat32Array([0.0, 0.0])
	best.hit.clear()
	best.dmg = CHILD_DMG if best.child else game.out_dmg()
	best.bounces = game.lv.bounce
	best.light = 0.0
	best.orbited = false
	return true


# A split: children carry the route so far, so a recall still runs them
# all the way back to where the parent was fired.
func split(b: B, at: Vector2, dir: Vector2, s_at: float) -> void:
	var lvl: int = game.lv.split
	if lvl <= 0 or b.gen >= 2:
		return
	var n := 3 if lvl >= 3 else 2
	var base := b.sub(0.0, s_at)
	for k in n:
		var spread := 0.0 if n == 1 else lerpf(-0.42, 0.42, float(k) / (n - 1))
		if list.size() >= CHILD_MAX:
			# over the cap the extra rounds fold into the parent's damage
			b.dmg += CHILD_DMG
			continue
		var c := B.new()
		c.child = true
		c.gen = b.gen + 1
		c.pos = at
		c.dir = dir.rotated(spread + randf_range(-0.05, 0.05))
		c.path = base.duplicate()
		c.path.append(at)
		c.cum = PackedFloat32Array()
		var acc := 0.0
		for i in c.path.size():
			if i > 0:
				acc += c.path[i].distance_to(c.path[i - 1])
			c.cum.append(acc)
		c.seed = randf() * 100.0
		c.hit = b.hit.duplicate()
		c.dmg = CHILD_DMG
		c.bounces = game.lv.bounce if game.lv.bounce >= 3 else 0
		list.append(c)
	# a crowded screen keeps the split mark small
	if list.size() < 250:
		game.fx.sparks(at, dir, 4, Pal.you(1.0, 1.8), 300.0, 0.15, 0.6)
	else:
		game.fx.flash(at, 12.0, 0.08, Pal.you(0.5, 1.4))
	game.sfx.play("split", randf_range(0.95, 1.15), -10.0)


func on_enemy_hit(b: B, at: Vector2, dir: Vector2, ret: bool) -> void:
	if not ret and b.state == FLY and game.has("refract") and not b.refracted:
		b.refracted = true
		b.just_bent = true
		_bend(b, at, dir.rotated(0.52 if randf() < 0.5 else -0.52))
	if ret:
		if game.lv.split >= 2:
			split(b, at, dir, b.s)
	else:
		split(b, at, dir, b.total())


# Light every embedded round outward from the player, then let the paths draw in.
func light_up(from: Vector2) -> void:
	lit_ticks = 0
	for b in list:
		if b.state == EMBED:
			b.light_delay = b.pos.distance_to(from) / LIGHT_SPEED
			b.preview = 0.0


func recall(from: Vector2) -> int:
	var c: Array[B] = []
	for b in list:
		if b.state == EMBED:
			c.append(b)
	c.sort_custom(func(x: B, y: B) -> bool: return x.pos.distance_squared_to(from) < y.pos.distance_squared_to(from))
	var n := c.size()
	var gap := minf(0.014, 0.22 / maxf(1.0, n))
	var on_beat: bool = game.possess.pulse_beat()
	if on_beat:
		gap = 0.0          # a seized pulse on the beat: every round leaves at once
	for i in n:
		var b := c[i]
		b.state = PULL
		b.t = 0.0
		if b.settled:
			b.settled = false
			faint_dirty = true
		b.delay = i * gap
		b.light = 1.0
		b.hit.clear()
		b.via_done = false
		b.dmg = RET_DMG * (0.6 if b.child and not b.foe else 1.0)
		b.home_zero = b.foe
		b.zero_pass = false
		b.first_bonus = game.has("zero_point")
		b.dmg *= game.gun_dmg()
		if on_beat:
			b.dmg *= 1.5
		if life_max - b.life <= 3.0 and not b.child:
			game.crit_recalls += 1
			if Meta.count("crit") >= 20:
				game.ach("crit20")
		b.charge = 0
		var cl: int = game.lv.charge
		if cl > 0:
			# Charge school: the longer it waited, the harder it comes back
			b.dmg *= 1.0 + 0.1 * minf(b.life, 10.0 if cl == 1 else 20.0)
		b.piercer = cl >= 3 and b.life >= 8.0
		if game.has("edge"):
			b.dmg *= pow(1.25, b.bends)
		b.orbited = false
		# Critical Hold: a round about to go out comes back twice as hard
		b.crit = game.has("critical") and life_max - b.life <= 3.0
		if b.crit:
			b.dmg *= 2.0
			game.fx.flash(b.pos, 30.0, 0.25, Pal.you(0.8, 2.2))
			game.sfx.play("crit", randf_range(0.95, 1.1), -6.0)
	_shadows(c, gap)
	return n


# Shadow school (and Encore): ghost copies follow the recall a beat later.
func _shadows(c: Array[B], gap: float) -> void:
	var lvl: int = game.lv.get("shadow", 0)
	var encore: bool = game.take_encore()
	if lvl <= 0 and not encore:
		return
	var count := c.size() if (lvl >= 3 or encore) else (4 if lvl == 1 else 8)
	var k := 0
	for b in c:
		if b.child or k >= count or list.size() >= CHILD_MAX:
			continue
		k += 1
		var s := B.new()
		s.child = true
		s.shadow = true
		s.path = b.path.duplicate()
		s.cum = b.cum.duplicate()
		s.pos = b.pos
		s.dir = b.dir
		s.state = PULL
		s.t = 0.0
		s.delay = b.delay + 0.3
		s.light = 1.0
		s.dmg = b.dmg * (0.6 if encore else 0.5)
		s.seed = randf() * 100.0
		list.append(s)


func step(dt: float, real_dt: float) -> void:
	life_max = game.embed_life()
	var i := 0
	while i < list.size():
		var b := list[i]
		b.t += dt
		match b.state:
			FLY:
				_fly(b, dt)
			EMBED:
				b.life += dt
				var st := b.t >= 0.5 and life_max - b.life > 1.0 and b.light <= 0.0
				if st != b.settled:
					b.settled = st
					faint_dirty = true
				if game.focusing and b.light_delay >= 0.0:
					b.light_delay -= real_dt
					if b.light_delay <= 0.0:
						b.light_delay = -1.0
						b.light = 0.001
						game.fx.flash(b.pos - b.dir * 6.0, 26.0, 0.32, Pal.red(1.0, 2.6))
						if lit_ticks < 14:
							game.sfx.play("lit", 0.9 + lit_ticks * 0.035, -14.0 + lit_ticks * 0.2)
						lit_ticks += 1
				if b.light > 0.0:
					b.light = minf(1.0, b.light + real_dt / 0.14)
					b.preview = minf(1.0, b.preview + real_dt * maxf(2.2, 2400.0 / maxf(1.0, b.total())))
				if b.life >= life_max:
					b.settled = false
					b.state = FADE
					b.t = 0.0
					game.fx.ring(b.pos, 4.0, 18.0, 0.4, Pal.you(0.35), 1.0)
					if not b.child:
						game.sfx.play("expire", 1.0, -12.0)
						game.queue_regen()
			ORBIT:
				_orbit(b, dt)
			CAPTURED:
				b.hold_t += dt
				if b.holder == null or not is_instance_valid(b.holder) or not b.holder.holds():
					fling(b, Vector2.from_angle(randf() * TAU))
				else:
					b.hold_a += dt * 3.0
					var rr: float = b.holder.hold_radius()
					var want: Vector2 = b.holder.hold_center() + Vector2.from_angle(b.hold_a) * rr
					var p := b.pos.lerp(want, 1.0 - exp(-10.0 * dt))
					b.dir = (p - b.pos).normalized() if p.distance_squared_to(b.pos) > 0.01 else b.dir
					b.pos = p
			PULL:
				if b.t >= b.delay + 0.075:
					b.state = RETURN
					b.s = b.total()
					b.t = 0.0
					game.fx.sparks(b.pos, -b.dir, 3, Pal.red(1.0, 3.0), 260.0, 0.18)
			RETURN:
				_return(b, dt)
			HOME:
				var f := b.t / b.home_dur
				var to: Vector2 = game.boss.core_pos() if b.home_zero else game.player.pos
				var ctrl := b.home_from.lerp(to, 0.5) + (to - b.home_from).orthogonal().normalized() * b.home_from.distance_to(to) * 0.32 * b.home_side
				var via = game.possess.home_through() if not b.home_zero else null
				if via != null:
					# a seized leech's well: the way home bends through the knot and cuts it
					ctrl = via * 2.0 - (b.home_from + to) * 0.5
					if not b.via_done:
						b.via_done = true
						b.hit.clear()
						b.dmg *= 1.5
				var e := Pal.ease_io(f)
				var p := b.home_from.lerp(ctrl, e).lerp(ctrl.lerp(to, e), e)
				if via != null:
					game.enemies.sweep(b.pos, p, b, true)
				elif game.has("mirror") and not b.child:
					# Mirror Arc: the way home cuts too
					b.dmg = RET_DMG
					game.enemies.sweep(b.pos, p, b, true)
				b.dir = (p - b.pos).normalized() if p.distance_squared_to(b.pos) > 0.01 else b.dir
				b.pos = p
				b.hist.append(p)
				if b.hist.size() > 10:
					b.hist.remove_at(0)
				if f >= 1.0 and b.home_zero:
					if game.boss is Zero:
						game.boss.stolen_hit(b.pos)
					list.remove_at(i)
					continue
				if f >= 1.0:
					if game.orbit_take(b):
						_enter_orbit(b)
					else:
						list.remove_at(i)
						game.on_ammo_home(b)
						continue
			FADE:
				if b.t >= 0.35:
					list.remove_at(i)
					continue
		i += 1
	var j := 0
	while j < scars.size():
		scars[j][2] += dt
		if scars[j][2] > 9.0:
			scars.remove_at(j)
		else:
			j += 1
	_update_mesh()
	queue_redraw()
	paths.queue_redraw()
	glow.queue_redraw()
	if faint_dirty:
		faint_dirty = false
		faint.queue_redraw()
	faint.modulate.a = 1.0 - 0.6 * game.focus


func _fly(b: B, dt: float) -> void:
	var a := b.pos
	var to := a + b.dir * SPEED * (1.3 if game.has("long_barrel") and not b.foe else 1.0) * (2.0 if Loadout.gun == "rail" and not b.foe else 1.0) * dt
	if b.foe:
		var hw: Dictionary = game.arena.raycast(a, to)
		if hw:
			b.pos = hw.point
			b.set_head(hw.point)
			b.state = EMBED
			b.t = 0.0
			b.life = 0.0
			b.zlight = 0.0
			game.fx.sparks(hw.point, hw.normal, 3, Pal.you(0.6, 1.2), 240.0, 0.15, 0.8)
		else:
			b.pos = to
			b.set_head(to)
		return
	var burn: Dictionary = game.lasers.cut(a, to)
	if burn:
		to = burn.point
	var h: Dictionary = game.arena.raycast(a, to)
	var end: Vector2 = h.point if h else to
	var sh: Dictionary = {} if Loadout.gun == "rail" else game.enemies.shield_hit(a, end)
	if sh:
		# a guard's shield turns the round away; the bend joins its path
		game.enemies.sweep(a, sh.point, b, false)
		b.set_head(sh.point)
		b.dir = b.dir.bounce(sh.normal)
		b.pos = sh.point + sh.normal * 0.5
		b.path.append(b.pos)
		b.cum.append(b.cum[b.cum.size() - 1])
		b.set_head(b.pos)
		game.enemies.on_shield(sh.e, sh.point, b.dir, false)
		return
	var mg: Dictionary = game.maglev.cross(a, end, b)
	if mg:
		# a powered guide rail grips the round and turns it along the rail
		game.enemies.sweep(a, mg.point, b, false)
		_bend(b, mg.point, mg.dir)
		game.maglev.on_bend(mg.point, mg.dir, b)
		return
	var ph: Dictionary = game.enemies.prism_hit(a, end, b)
	if ph:
		# a prism bends the round by a fixed angle; the bend joins its path
		game.enemies.sweep(a, ph.point, b, false)
		_bend(b, ph.point, b.dir.rotated(ph.turn))
		game.enemies.on_prism(ph.e, ph.point)
		return
	var bh: Dictionary = game.boss.hit_test(a, end)
	if bh:
		if bh.core:
			var key := "boss%d" % bh.get("frame", -1)
			if not b.hit.has(key):
				b.hit[key] = true
				game.boss.damage(b.dmg * bh.mult * (0.3 if b.child else 1.0), false, bh.point, b.dir, bh.get("frame", -1))
		else:
			# armour turns the round away like a guard's shield
			game.enemies.sweep(a, bh.point, b, false)
			b.set_head(bh.point)
			b.dir = b.dir.bounce(bh.normal)
			b.pos = bh.point + bh.normal * 1.0
			b.path.append(b.pos)
			b.cum.append(b.cum[b.cum.size() - 1])
			b.set_head(b.pos)
			game.boss.on_armor(bh.car, bh.point, bh.normal)
			return
	game.enemies.sweep(a, end, b, false)
	if b.just_bent:
		b.just_bent = false
		return
	if burn and not h:
		_burn(b, end)
		return
	if h and h.mirror and b.path.size() < 12:
		# mirror panels turn rounds away without using up a ricochet
		_bend(b, h.point, b.dir.bounce(h.normal), h.normal)
		game.fx.sparks(h.point, h.normal, 3, Pal.you(1.0, 2.0), 320.0, 0.14, 0.7)
		game.fx.flash(h.point, 18.0, 0.1, Pal.you(0.6, 1.8))
		game.sfx.play("shield", randf_range(1.4, 1.6), -12.0)
		return
	if h:
		if b.bounces > 0:
			b.bounces -= 1
			b.bends += 1
			if game.has("edge"):
				b.dmg *= 1.25
			b.set_head(h.point)
			b.dir = b.dir.bounce(h.normal)
			b.pos = h.point + h.normal * 0.5
			b.path.append(b.pos)
			b.cum.append(b.cum[b.cum.size() - 1])
			b.set_head(b.pos)
			game.fx.sparks(h.point, h.normal, 4, Pal.you(1.0, 1.7), 300.0, 0.16, 0.8)
			game.fx.flash(h.point, 16.0, 0.08, Pal.you(0.5, 1.4))
			game.sfx.play("embed", randf_range(1.3, 1.5), -14.0)
			if game.lv.bounce >= 3 and game.lv.split >= 1:
				split(b, b.pos, b.dir, b.total())
		else:
			b.pos = h.point
			b.set_head(h.point)
			b.state = EMBED
			b.t = 0.0
			b.life = 0.0
			b.hit.clear()
			game.on_embed(b, h.normal)
			scars.append([h.point, h.normal, 0.0])
			if scars.size() > 160:
				scars.remove_at(0)
	else:
		b.pos = to
		b.set_head(to)


# A lit laser fence burns the round where it crosses: a flare there, and the
# round is back in the magazine (a split-off one is simply gone).
func _burn(b: B, at: Vector2) -> void:
	b.pos = at
	b.set_head(at)
	b.state = FADE
	b.t = 0.0
	b.settled = false
	game.fx.sparks(at, -b.dir, 6, Pal.red(1.0, 3.2), 300.0, 0.2, 0.9)
	game.fx.flash(at, 20.0, 0.1, Pal.red(0.7, 2.6))
	game.sfx.play("expire", randf_range(1.5, 1.7), -11.0)
	if not b.child:
		game.on_ammo_home(b)


func _bend(b: B, at: Vector2, new_dir: Vector2, nudge: Vector2 = Vector2.ZERO) -> void:
	b.bends += 1
	if b.bends >= 8:
		game.ach("mirror8")
	if game.has("edge"):
		b.dmg *= 1.25
	b.set_head(at)
	b.dir = new_dir.normalized()
	b.pos = at + (nudge * 0.5 if nudge != Vector2.ZERO else b.dir * 0.5)
	b.path.append(b.pos)
	b.cum.append(b.cum[b.cum.size() - 1])
	b.set_head(b.pos)


func _return(b: B, dt: float) -> void:
	var s0 := b.s
	var s1 := maxf(0.0, s0 - RETURN_SPEED * (1.3 if game.has("quick_recall") else 1.0) * dt)
	var pts := b.sub(s0, s1)
	if b.zero_pass:
		for k0 in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(game.player.pos, pts[k0], pts[k0 + 1])
			if q.distance_to(game.player.pos) < Player.R + 4.0:
				game.on_player_hit((pts[k0 + 1] - pts[k0]).normalized(), null)
		b.s = s1
		b.pos = pts[pts.size() - 1]
		if s1 <= 0.0:
			b.state = FADE
			b.t = 0.0
		return
	for k in pts.size() - 1:
		var sh: Dictionary = {} if b.piercer else game.enemies.shield_hit(pts[k], pts[k + 1])
		if sh:
			# blocked on the way back: the round still comes home, from here
			game.enemies.sweep(pts[k], sh.point, b, true)
			game.enemies.on_shield(sh.e, sh.point, b.dir, true)
			b.pos = sh.point
			_go_home(b)
			return
		var bh: Dictionary = game.boss.hit_test(pts[k], pts[k + 1])
		if bh:
			if bh.core:
				var key := "boss%d" % bh.get("frame", -1)
				if not b.hit.has(key):
					b.hit[key] = true
					game.boss.damage(b.dmg * bh.mult * (0.3 if b.child else 1.0), true, bh.point, b.dir, bh.get("frame", -1))
			elif b.piercer:
				var key2 := "boss_armor"
				if not b.hit.has(key2):
					b.hit[key2] = true
					game.boss.damage(b.dmg * 0.5, true, bh.point, b.dir)
			else:
				game.enemies.sweep(pts[k], bh.point, b, true)
				game.boss.on_armor(bh.car, bh.point, bh.normal)
				b.pos = bh.point
				_go_home(b)
				return
		var lc: Dictionary = game.lasers.cut(pts[k], pts[k + 1])
		if lc:
			game.enemies.sweep(pts[k], lc.point, b, true)
			b.charge = 0
			_burn(b, lc.point)
			return
		game.enemies.sweep(pts[k], pts[k + 1], b, true)
	b.s = s1
	var np := pts[pts.size() - 1]
	if np.distance_squared_to(b.pos) > 0.01:
		b.dir = (np - b.pos).normalized()
	b.pos = np
	if s1 <= 0.0:
		game.on_return_arrive(b)
		if game.lv.blast > 0 and b.charge > 0:
			game.blast(b.last_hit, b.charge)
		b.charge = 0
		if b.foe and b.home_zero:
			# its own round, recalled by you: on into Zero
			_go_home(b)
			return
		if b.child:
			# split rounds end where their family was fired, unless the ring takes them
			if game.lv.split >= 3 and game.lv.orbit >= 1:
				_enter_orbit(b)
			else:
				b.state = FADE
				b.t = 0.0
				game.fx.sparks(b.pos, b.dir, 3, Pal.red(1.0, 2.4), 200.0, 0.2, 1.4)
			return
		_go_home(b)


func _go_home(b: B) -> void:
	b.state = HOME
	b.t = 0.0
	b.home_from = b.pos
	b.home_side = 1.0 if fmod(b.seed, 2.0) < 1.0 else -1.0
	b.home_dur = clampf(b.pos.distance_to(game.player.pos) / 2200.0, 0.16, 0.42)
	b.hist = PackedVector2Array([b.pos])


func _enter_orbit(b: B) -> void:
	b.orbited = true
	if orbit_count() >= 19:
		game.ach("orbit20")
	b.state = ORBIT
	b.t = 0.0
	b.orbit_left = game.orbit_time()
	b.orbit_from = b.pos
	b.orbit_a = (b.pos - game.player.pos).angle()
	b.orbit_r = (42.0 + float(orbit_count() % 3) * 11.0) * (1.4 if game.has("wide_ring") else 1.0)
	b.hit.clear()
	b.hist = PackedVector2Array([b.pos])
	game.sfx.play("lit", 1.4, -16.0)


func _orbit(b: B, dt: float) -> void:
	var pl: Vector2 = game.player.pos
	b.orbit_a += ORBIT_SPIN * dt
	var want := pl + Vector2.from_angle(b.orbit_a) * b.orbit_r
	var k := Pal.ease_out(b.t / 0.18)
	var p := b.orbit_from.lerp(want, k)
	var prev := b.pos
	b.dir = (p - prev).normalized() if p.distance_squared_to(prev) > 0.01 else b.dir
	b.pos = p
	b.hist.append(p)
	if b.hist.size() > 7:
		b.hist.remove_at(0)
	b.hit_clear -= dt
	if b.hit_clear <= 0.0:
		b.hit_clear = 0.25
		b.hit.clear()
	b.dmg = ORBIT_DMG * (1.5 if game.has("wide_ring") else 1.0)
	game.enemies.sweep(prev, p, b, false)
	b.orbit_left -= dt
	if b.orbit_left <= 0.0:
		if b.child:
			b.state = FADE
			b.t = 0.0
		else:
			_go_home(b)
			b.home_dur = 0.12


# ---------------------------------------------------------------- drawing

func _head(b: B) -> Array:
	# [center, dir, length, width, color]
	var t: float = game.real_time
	match b.state:
		FLY:
			return [b.pos - b.dir * 8.0, b.dir, 22.0, 3.6, Pal.you(1.0, 1.9)]
		EMBED when b.foe:
			var zl := 0.5 + 0.5 * sin(game.real_time * 20.0) if b.zlight > 0.0 else 0.0
			return [b.pos - b.dir * 6.0, b.dir, 16.0, 3.0, Pal.foe(0.45 + 0.55 * zl, 1.0 + 1.2 * zl).lerp(Pal.red(1.0, 2.8), b.light)]
		RETURN when b.zero_pass:
			return [b.pos - b.dir * 10.0, b.dir, 30.0, 4.4, Pal.you(1.0, 3.0)]
		EMBED:
			var settle := Pal.back(b.t / 0.22, 2.6)
			var sink := lerpf(-8.0, 3.0, settle)
			var wob := sin(b.t * 70.0) * exp(-b.t * 14.0) * 2.4
			var breath := 0.5 + 0.5 * sin(t * 2.4 + b.seed)
			var c := Pal.you(1.0, 1.0 + 0.3 * breath)
			if b.light > 0.0:
				c = c.lerp(Pal.red(1.0, 2.8 + 0.6 * breath), Pal.ease_out(b.light))
			var rem := life_max - b.life
			if rem < WARN:
				var blink := 0.5 + 0.5 * cos((WARN - rem) * (6.0 + (WARN - rem) * 6.0))
				c.a = lerpf(1.0, 0.35, blink * (1.0 - rem / WARN))
			var ctr := b.pos - b.dir * (8.0 - sink) + b.dir.orthogonal() * wob
			return [ctr, b.dir, 18.0, 3.2, c]
		PULL:
			var k := Pal.ease_in(clampf((b.t - b.delay) / 0.075, 0.0, 1.0))
			return [b.pos - b.dir * (5.0 - 6.0 * k), b.dir, 18.0 + 6.0 * k, 3.4 + k, Pal.red(1.0, 3.0 + 2.0 * k)]
		RETURN:
			return [b.pos - b.dir * 10.0, b.dir, 36.0 if b.crit else 30.0, 5.4 if b.crit else 4.4, Pal.red(1.0, 6.0 if b.crit else 4.5)]
		CAPTURED:
			return [b.pos, b.dir, 12.0, 2.6, Pal.you(0.75, 1.2)]
		ORBIT:
			var fade := clampf(b.orbit_left / 0.3, 0.0, 1.0)
			return [b.pos - b.dir * 6.0, b.dir, 16.0, 3.0, Pal.red(0.6 + 0.4 * fade, 2.6)]
		HOME:
			var f := clampf(b.t / b.home_dur, 0.0, 1.0)
			return [b.pos, b.dir, lerpf(16.0, 8.0, f), lerpf(3.0, 2.2, f), Pal.red(1.0, 3.0).lerp(Pal.you(1.0, 2.0), f)]
		_:
			var f2 := clampf(b.t / 0.35, 0.0, 1.0)
			return [b.pos - b.dir * 8.0, b.dir, 18.0 * (1.0 - f2 * 0.6), 3.0 * (1.0 - f2), Pal.you(1.0 - f2)]


var _buf := PackedFloat32Array()


func _update_mesh() -> void:
	var n := mini(list.size(), MAX)
	if _buf.size() != MAX * 12:
		_buf.resize(MAX * 12)
	for i in n:
		var h := _head(list[i])
		var d: Vector2 = h[1]
		var sc := 0.7 if list[i].child else 1.0
		var x: Vector2 = d * h[2] * sc
		var y: Vector2 = d.orthogonal() * h[3] * sc
		var o: Vector2 = h[0]
		var c: Color = h[4]
		var k := i * 12
		_buf[k] = x.x
		_buf[k + 1] = y.x
		_buf[k + 2] = 0.0
		_buf[k + 3] = o.x
		_buf[k + 4] = x.y
		_buf[k + 5] = y.y
		_buf[k + 6] = 0.0
		_buf[k + 7] = o.y
		_buf[k + 8] = c.r
		_buf[k + 9] = c.g
		_buf[k + 10] = c.b
		_buf[k + 11] = c.a
	mm.buffer = _buf
	mm.visible_instance_count = n


var _ts := [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
var _tc := [PackedColorArray(), PackedColorArray(), PackedColorArray()]


# Trails, under the heads, batched by width.
func _draw() -> void:
	for g in 3:
		_ts[g] = PackedVector2Array()
		_tc[g] = PackedColorArray()
	for b in list:
		match b.state:
			FLY:
				var tl := 90.0 if b.child else 150.0
				var n := b.path.size()
				# straight leg (the usual case): no path walk needed
				if b.pos.distance_to(b.path[n - 2]) >= tl:
					_trail(0, PackedVector2Array([b.pos, b.pos - b.dir * tl]), Pal.you(0.55, 1.4))
				else:
					var s := b.total()
					_trail(0, b.sub(s, maxf(0.0, s - tl)), Pal.you(0.55, 1.4))
			RETURN:
				var s2 := b.s
				# the head carries the light; the tail behind it stays a quiet line,
				# so a flock coming home never buries you or what it is cutting
				var tc := Pal.you(0.9, 2.4) if b.zero_pass else (Pal.you(0.35, 1.2) if b.shadow else Pal.red(0.55, 1.7))
				_trail(1, b.sub(s2, minf(b.total(), s2 + 160.0)), tc)
			HOME, ORBIT:
				if b.hist.size() > 1:
					var pts := b.hist.duplicate()
					pts.reverse()
					_trail(2, pts, Pal.red(0.55, 2.0))
	var widths := [2.0, 3.0, 1.6]
	for g in 3:
		if _ts[g].size() > 0:
			draw_multiline_colors(_ts[g], _tc[g], widths[g])


# Fade a trail from its head; one segment colour each, appended to a batch.
func _trail(g: int, pts: PackedVector2Array, c: Color) -> void:
	var n := pts.size()
	if n < 2:
		return
	var total := 0.0
	for i in range(1, n):
		total += pts[i].distance_to(pts[i - 1])
	if total <= 0.5:
		return
	var segs: PackedVector2Array = _ts[g]
	var cols: PackedColorArray = _tc[g]
	# split long legs so the fade stays smooth
	var acc := 0.0
	for i in range(1, n):
		var a := pts[i - 1]
		var b := pts[i]
		var l := a.distance_to(b)
		var parts := clampi(int(l / 40.0), 1, 4)
		for k in parts:
			var p0 := a.lerp(b, float(k) / parts)
			var p1 := a.lerp(b, float(k + 1) / parts)
			var mid := (acc + l * (k + 0.5) / parts) / total
			var f := 1.0 - mid
			segs.append(p0)
			segs.append(p1)
			cols.append(Color(c.r, c.g, c.b, c.a * f * f))
		acc += l
	_ts[g] = segs
	_tc[g] = cols


# Settled rounds (fully drawn in, not lit, not about to expire) live in the
# cached faint layer; it only re-records when that set changes.
func _draw_faint() -> void:
	var segs := PackedVector2Array()
	var seen := {}
	for b in list:
		if b.state != EMBED or not b.settled:
			continue
		for i in b.path.size() - 1:
			segs.append(b.path[i])
			segs.append(b.path[i + 1])
		var key := Vector2i(roundi(b.path[0].x / 3.0), roundi(b.path[0].y / 3.0))
		if not seen.has(key):
			seen[key] = true
			segs.append_array(_circle_segs(b.path[0], 3.0, 10))
	if segs.size() > 0:
		faint.draw_multiline(segs, Pal.you(0.085), -1.0)


func _circle_segs(o: Vector2, r: float, n: int, a0: float = 0.0, a1: float = TAU) -> PackedVector2Array:
	var segs := PackedVector2Array()
	var prev := o + Vector2.from_angle(a0) * r
	for i in range(1, n + 1):
		var p := o + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r
		segs.append(prev)
		segs.append(p)
		prev = p
	return segs


var _sw := PackedVector2Array()
var _cw := PackedColorArray()
var _sr := PackedVector2Array()
var _cr := PackedColorArray()
var _sd := PackedVector2Array()
var _so := PackedVector2Array()


func _poly_w(pts: PackedVector2Array, c: Color) -> void:
	for i in pts.size() - 1:
		_sw.append(pts[i])
		_sw.append(pts[i + 1])
		_cw.append(c)


func _poly_r(pts: PackedVector2Array, c: Color) -> void:
	for i in pts.size() - 1:
		_sr.append(pts[i])
		_sr.append(pts[i + 1])
		_cr.append(c)


func _draw_paths() -> void:
	_sw.clear()
	_cw.clear()
	_sr.clear()
	_cr.clear()
	_sd.clear()
	_so.clear()
	var origins := {}
	for sc in scars:
		var a: float = 1.0 - sc[2] / 9.0
		var p: Vector2 = sc[0]
		var tg: Vector2 = sc[1].orthogonal()
		_sw.append(p - tg * 4.0)
		_sw.append(p + tg * 4.0)
		_cw.append(Pal.you(0.2 * a))
	for b in list:
		if b.state == EMBED and b.foe and b.zlight > 0.0:
			# Zero is about to call it: its whole way back flickers
			_poly_w(b.path, Pal.you(0.5 + 0.4 * sin(game.real_time * 24.0), 1.6))
		if b.state == EMBED:
			var rem := life_max - b.life
			if b.light > 0.0:
				var tot := b.total()
				var pv := Pal.ease_io(b.preview)
				_poly_r(b.path if pv >= 1.0 else b.sub(tot, tot * (1.0 - pv)), Pal.red(0.55 * b.light, 1.8))
				# a pulse runs the route toward the firing point while you hold
				var pulse := fmod(game.real_time * 1.6 + b.seed, 1.0)
				if pv > pulse:
					var pp := b.sample(tot * (1.0 - pulse))
					var dd := b.sample(tot * (1.0 - pulse) + 4.0)
					_sd.append(pp)
					_sd.append(dd)
				if pv >= 1.0:
					var key := Vector2i(roundi(b.path[0].x / 3.0), roundi(b.path[0].y / 3.0))
					var pop := Pal.back(clampf(b.preview * 3.0 - 2.0, 0.0, 1.0))
					origins[key] = maxf(origins.get(key, 0.0), pop)
					_so.append(b.path[0])
			elif not b.settled:
				var appear := Pal.ease_out(b.t / 0.5)
				var fade := clampf(rem, 0.0, 1.0)
				_poly_w(b.path, Pal.you(0.085 * appear * fade))
				_circle_w(b.path[0], 3.0, 10, Pal.you(0.16 * appear * fade))
			if b.light <= 0.0 and rem < WARN:
				var k := 1.0 - rem / WARN
				_circle_w(b.pos - b.dir * 8.0, 11.0, 14, Pal.you(0.45), -PI / 2.0, -PI / 2.0 + TAU * (1.0 - k))
		elif b.state == PULL or b.state == RETURN:
			var upto := b.s if b.state == RETURN else b.total()
			if upto > 0.0:
				_poly_r(b.sub(upto, 0.0), Pal.red(0.18, 1.2))
			var key2 := Vector2i(roundi(b.path[0].x / 3.0), roundi(b.path[0].y / 3.0))
			origins[key2] = 1.0
			_so.append(b.path[0])
	# one red ring per distinct firing spot
	var done := {}
	for o in _so:
		var key3 := Vector2i(roundi(o.x / 3.0), roundi(o.y / 3.0))
		if done.has(key3):
			continue
		done[key3] = true
		var r: float = 8.0 * origins.get(key3, 1.0)
		if r > 0.5:
			paths.draw_texture_rect(ring_tex, Rect2(o - Vector2(r, r), Vector2(r, r) * 2.0), false, Pal.red(0.9, 2.2))
	if _sw.size() > 0:
		paths.draw_multiline_colors(_sw, _cw, -1.0)
	if _sr.size() > 0:
		paths.draw_multiline_colors(_sr, _cr, 1.6)
	if _sd.size() > 0:
		paths.draw_multiline(_sd, Pal.red(0.95, 3.0), 4.0)


func _circle_w(o: Vector2, r: float, n: int, c: Color, a0: float = 0.0, a1: float = TAU) -> void:
	var cs := _circle_segs(o, r, n, a0, a1)
	_sw.append_array(cs)
	for i in cs.size() / 2:
		_cw.append(c)


func _draw_glow() -> void:
	# a flock coming home stacks its light: thin each halo as the flock grows,
	# so one round glows as before and twenty do not wash the arena out
	var homing := 0
	for b in list:
		if b.state == RETURN:
			homing += 1
	var share := clampf(sqrt(4.0 / maxf(1.0, homing)), 0.4, 1.0)
	for b in list:
		if b.state == RETURN:
			glow.draw_texture_rect(glow_tex, Rect2(b.pos - Vector2(22, 22), Vector2(44, 44)), false, Pal.red(0.55 * share, 1.6))
		elif b.state == EMBED and b.light > 0.0:
			var p := b.pos - b.dir * 9.0
			var r := 18.0 + 4.0 * sin(game.real_time * 6.0 + b.seed)
			glow.draw_texture_rect(glow_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Pal.red(0.45 * b.light, 1.4))
		elif b.state == EMBED:
			var p2 := b.pos - b.dir * 9.0
			var k2 := Pal.ease_out(b.t / 0.3) * clampf((life_max - b.life) / 1.0, 0.0, 1.0)
			glow.draw_texture_rect(glow_tex, Rect2(p2 - Vector2(13, 13), Vector2(26, 26)), false, Pal.you(0.16 * k2))
		elif b.state == FLY:
			glow.draw_texture_rect(glow_tex, Rect2(b.pos - Vector2(14, 14), Vector2(28, 28)), false, Pal.you(0.18))
