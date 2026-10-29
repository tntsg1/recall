class_name Shelves
extends Node2D
# The deep archive's floor (chapter 8): two banks of mobile shelving, four
# shelves each, on floor rails. Pressed together a bank leaves one aisle;
# every few seconds a bank cranks a different aisle open (the floor marks it
# first), and the aisle that closes crushes whatever is still in it. A round
# that embeds in a shelf rides with it — its line home swings as the shelf
# moves, so you can let a bank carry your rounds round to where you want them.

const W := 50.0
const H := 300.0
const TOP := 520.0
const SMALL := 12.0
const BIG := 250.0
const N := 4
const STARTS := [190.0, 1222.0]   # each bank's track, from its left end
const PERIOD := 7.0
const WARN := 1.1
const MOVE := 1.3
const CRUSH := Player.R * 2.0 + 6.0
const CRUSH_DMG := 40.0
const VOLUMES := ["001–054", "055–108", "109–161", "162–214"]

var on := false
var game
var t := 0.0
var aisle := [1, 3]            # each bank's open gap (0..4)
var from_aisle := [1, 3]
var clock := [0.0, PERIOD * 0.5]
var move_t := [-1.0, -1.0]     # -1 idle; 0..WARN warning; WARN.. moving
var xs: Array = []             # the shelves' left edges, bank-major
var wheel := [0.0, 0.0]
var crushed_t := 0.0


func _init() -> void:
	z_index = 2
	z_as_relative = false


# The shelves' rects for a room (only the archive has them).
static func initial(room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if room != 7:
		return out
	for bank in 2:
		var x0 := _xs_for(bank, [1, 3][bank])
		for j in N:
			out.append(Rect2(x0[j], TOP, W, H))
	return out


static func _xs_for(bank: int, gap: int) -> Array:
	var out := []
	var x: float = STARTS[bank]
	for j in N:
		x += BIG if j == gap else SMALL
		out.append(x)
		x += W
	return out


func setup(story: int) -> void:
	on = story == 8
	visible = on
	t = 0.0
	aisle = [1, 3]
	from_aisle = [1, 3]
	clock = [0.0, PERIOD * 0.5]
	move_t = [-1.0, -1.0]
	xs.clear()
	for bank in 2:
		xs.append_array(_xs_for(bank, aisle[bank]))
	queue_redraw()


func active() -> bool:
	return on


# The shelf a rect index of the arena belongs to, or -1.
func shelf_of(rect_i: int) -> int:
	if not on or rect_i < 0:
		return -1
	var k: int = rect_i - game.arena.mover_from
	return k if k >= 0 and k < N * 2 else -1


func rect(k: int) -> Rect2:
	return Rect2(xs[k], TOP, W, H)


# 0..1 how far along a bank's move is (0 while it waits or warns)
func _move_k(bank: int) -> float:
	if move_t[bank] < WARN:
		return 0.0
	return Pal.ease_io(clampf((move_t[bank] - WARN) / MOVE, 0.0, 1.0))


func moving(bank: int) -> bool:
	return move_t[bank] >= 0.0


# The gap that is about to close (or is closing) in a bank, -1 if none.
func closing(bank: int) -> int:
	if move_t[bank] < 0.0 or from_aisle[bank] == aisle[bank]:
		return -1
	return from_aisle[bank]


func step(dt: float) -> void:
	if not on:
		return
	t += dt
	crushed_t = maxf(0.0, crushed_t - dt)
	for bank in 2:
		clock[bank] += dt
		if move_t[bank] < 0.0 and clock[bank] >= PERIOD:
			clock[bank] = 0.0
			from_aisle[bank] = aisle[bank]
			var pick: Array = range(N + 1)
			pick.erase(aisle[bank])
			aisle[bank] = pick[randi() % pick.size()]
			move_t[bank] = 0.0
			game.sfx.play("windup", 0.5, -10.0)
		elif move_t[bank] >= 0.0:
			var was: float = move_t[bank]
			move_t[bank] += dt
			if was < WARN and move_t[bank] >= WARN:
				game.sfx.play("slam", 0.45, -12.0)
			var a := _xs_for(bank, from_aisle[bank])
			var b := _xs_for(bank, aisle[bank])
			var k := _move_k(bank)
			for j in N:
				var i: int = bank * N + j
				var nx: float = lerpf(a[j], b[j], k)
				var dx: float = nx - xs[i]
				if absf(dx) > 0.0001:
					xs[i] = nx
					game.arena.set_mover(i, rect(i))
					_carry(i, dx)
					wheel[bank] += dx * 0.05
			if move_t[bank] >= WARN + MOVE:
				move_t[bank] = -1.0
				game.sfx.play("slam", 0.6, -8.0)
				game.cam.add_trauma(0.12)
			_crush(bank)
	queue_redraw()


# Rounds embedded in a moving shelf ride along with it.
func _carry(i: int, dx: float) -> void:
	for b in game.bullets.list:
		if b.shelf == i and b.state == Bullets.EMBED:
			b.pos.x += dx
			b.set_head(b.pos)
			game.bullets.faint_dirty = true


# Whatever is caught between two shelves as their gap closes is crushed and
# squeezed out of the aisle's nearer end.
func _crush(bank: int) -> void:
	if _move_k(bank) <= 0.0:
		return
	for j in N - 1:
		var i: int = bank * N + j
		var lo: float = xs[i] + W
		var hi: float = xs[i + 1]
		if hi - lo >= CRUSH:
			continue
		var p: Vector2 = game.player.pos
		if p.x > lo - 2.0 and p.x < hi + 2.0 and p.y > TOP - 2.0 and p.y < TOP + H + 2.0:
			var up := p.y < TOP + H * 0.5
			game.player.pos = Vector2((lo + hi) * 0.5, TOP - Player.R - 8.0 if up else TOP + H + Player.R + 8.0)
			if game.player.dash_t <= 0.0:
				game.on_player_hit(Vector2.UP if up else Vector2.DOWN, null)
				crushed_t = 0.6
				game.cam.add_trauma(0.4)
		for e in game.enemies.list:
			if e.state != Enemies.ALIVE:
				continue
			if e.pos.x > lo - 2.0 and e.pos.x < hi + 2.0 and e.pos.y > TOP - 2.0 and e.pos.y < TOP + H + 2.0:
				var eu: bool = e.pos.y < TOP + H * 0.5
				e.pos = Vector2((lo + hi) * 0.5, TOP - e.r - 8.0 if eu else TOP + H + e.r + 8.0)
				game.enemies.blast_hit(e, Vector2.UP if eu else Vector2.DOWN, CRUSH_DMG)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not on:
		return
	var f: float = game.focus
	var dim := 1.0 - 0.45 * f
	if game.hud.intro_t >= 0.0:
		dim *= clampf((game.hud.intro_t - 2.2) / 0.6, 0.25, 1.0)
	for bank in 2:
		_draw_rails(bank, dim)
		_draw_warning(bank, dim)
	for i in N * 2:
		_draw_shelf(i, dim)


# Two rails in the floor under each bank, with stops at the track's ends.
func _draw_rails(bank: int, dim: float) -> void:
	var x0: float = STARTS[bank]
	var x1: float = x0 + N * W + N * SMALL + BIG
	for y: float in [TOP + 46.0, TOP + H - 46.0]:
		draw_line(Vector2(x0 - 6.0, y - 3.0), Vector2(x1 + 6.0, y - 3.0), Pal.ink(0.16 * dim), 1.5)
		draw_line(Vector2(x0 - 6.0, y + 3.0), Vector2(x1 + 6.0, y + 3.0), Pal.ink(0.16 * dim), 1.5)
		for x: float in [x0 - 6.0, x1 + 6.0]:
			draw_rect(Rect2(x - 4.0, y - 8.0, 8.0, 16.0), Pal.ink(0.3 * dim), false, 1.5)
	# the aisle's floor: worn where people walk
	var a := _xs_for(bank, aisle[bank])
	var gap: int = aisle[bank]
	if gap > 0 and gap < N and not moving(bank):
		var lo: float = a[gap - 1] + W
		var hi: float = a[gap]
		var y := TOP + 20.0
		while y < TOP + H - 20.0:
			draw_line(Vector2(lo + 30.0, y), Vector2(hi - 30.0, y), Pal.ink(0.035 * dim), 1.0)
			y += 24.0


# The gap about to close: red hatching on its floor and a red edge on both
# faces; the one about to open, a faint outline where it will be.
func _draw_warning(bank: int, dim: float) -> void:
	var g := closing(bank)
	if g < 0 or g == 0 or g == N:
		return
	var i: int = bank * N + g
	var lo: float = xs[i - 1] + W
	var hi: float = xs[i]
	if hi - lo < 4.0:
		return
	var warn_k := clampf(move_t[bank] / WARN, 0.0, 1.0)
	var fl := 0.55 + 0.45 * sin(t * (14.0 + 18.0 * warn_k))
	var r := Rect2(lo, TOP, hi - lo, H)
	draw_rect(r, Pal.red(0.012 * fl * dim, 1.2))
	var hatch := PackedVector2Array()
	var y := TOP + 8.0
	while y < TOP + H - 8.0:
		hatch.append(Vector2(lo + 6.0, y + 18.0))
		hatch.append(Vector2(minf(hi - 6.0, lo + 6.0 + 24.0), y))
		if hi - lo > 60.0:
			hatch.append(Vector2(hi - 30.0, y + 18.0))
			hatch.append(Vector2(hi - 6.0, y))
		y += 30.0
	if hatch.size() > 0:
		draw_multiline(hatch, Pal.red((0.25 + 0.4 * warn_k) * fl * dim, 1.5), 2.0)
	draw_line(Vector2(lo, TOP), Vector2(lo, TOP + H), Pal.red((0.5 + 0.5 * warn_k) * fl * dim, 2.0), 2.5)
	draw_line(Vector2(hi, TOP), Vector2(hi, TOP + H), Pal.red((0.5 + 0.5 * warn_k) * fl * dim, 2.0), 2.5)
	# arrows on the floor at both ends: which way it shuts
	for yy: float in [TOP - 16.0, TOP + H + 16.0]:
		var m := (lo + hi) * 0.5
		var s := minf(14.0, (hi - lo) * 0.3)
		draw_line(Vector2(lo + 2.0, yy), Vector2(m - 3.0, yy), Pal.red(0.7 * fl * dim, 1.6), 2.0)
		draw_line(Vector2(hi - 2.0, yy), Vector2(m + 3.0, yy), Pal.red(0.7 * fl * dim, 1.6), 2.0)
		draw_line(Vector2(m - 3.0, yy), Vector2(m - 3.0 - s * 0.6, yy - s * 0.5), Pal.red(0.7 * fl * dim, 1.6), 2.0)
		draw_line(Vector2(m - 3.0, yy), Vector2(m - 3.0 - s * 0.6, yy + s * 0.5), Pal.red(0.7 * fl * dim, 1.6), 2.0)
		draw_line(Vector2(m + 3.0, yy), Vector2(m + 3.0 + s * 0.6, yy - s * 0.5), Pal.red(0.7 * fl * dim, 1.6), 2.0)
		draw_line(Vector2(m + 3.0, yy), Vector2(m + 3.0 + s * 0.6, yy + s * 0.5), Pal.red(0.7 * fl * dim, 1.6), 2.0)
	# where the new aisle opens
	var to := _xs_for(bank, aisle[bank])
	var ng: int = aisle[bank]
	if ng > 0 and ng < N:
		var nr := Rect2(to[ng - 1] + W, TOP, to[ng] - to[ng - 1] - W, H)
		draw_rect(nr.grow(-4.0), Pal.ink(0.18 * (1.0 - _move_k(bank)) * dim), false, 1.0)


# A shelf from above: the box spines down both faces, the back-to-back
# divider, the end caps, a hand wheel on the near cap, its volumes stencilled.
func _draw_shelf(i: int, dim: float) -> void:
	var r := rect(i)
	var bank: int = i / N
	var block := Pal.ink(0.62 * dim)
	draw_rect(r, Pal.WALL)
	draw_rect(r, block, false, 2.0)
	var spine := PackedVector2Array()
	var y := r.position.y + 14.0
	var n := 0
	while y < r.end.y - 14.0:
		var w := 5.0 + float((i * 7 + n * 3) % 5)
		spine.append(Vector2(r.position.x + 3.0, y))
		spine.append(Vector2(r.position.x + 3.0 + w + 8.0, y))
		spine.append(Vector2(r.end.x - 3.0 - w - 8.0, y + 5.0))
		spine.append(Vector2(r.end.x - 3.0, y + 5.0))
		y += 11.0 + float((i + n) % 3) * 2.0
		n += 1
	draw_multiline(spine, Pal.ink(0.2 * dim), 1.0)
	draw_line(Vector2(r.get_center().x, r.position.y + 12.0), Vector2(r.get_center().x, r.end.y - 12.0), Pal.ink(0.32 * dim), 1.5)
	# end caps
	draw_rect(Rect2(r.position.x - 2.0, r.position.y, W + 4.0, 10.0), Color(0.07, 0.07, 0.075))
	draw_rect(Rect2(r.position.x - 2.0, r.position.y, W + 4.0, 10.0), Pal.ink(0.5 * dim), false, 1.5)
	draw_rect(Rect2(r.position.x - 2.0, r.end.y - 10.0, W + 4.0, 10.0), Color(0.07, 0.07, 0.075))
	draw_rect(Rect2(r.position.x - 2.0, r.end.y - 10.0, W + 4.0, 10.0), Pal.ink(0.5 * dim), false, 1.5)
	# the hand wheel, turning as it moves
	var wc := Vector2(r.get_center().x, r.end.y + 9.0)
	draw_circle(wc, 9.0, Color(0.05, 0.05, 0.055))
	draw_arc(wc, 9.0, 0.0, TAU, 18, Pal.ink(0.55 * dim), 1.5)
	for s in 3:
		var a: float = wheel[bank] + TAU * s / 3.0
		draw_line(wc, wc + Vector2.from_angle(a) * 8.0, Pal.ink(0.45 * dim), 1.2)
	# its volumes, stencilled down the divider
	var lab := Txt.t("shelf_tag") % VOLUMES[i % N]
	var fs := 12
	var sf := Fonts.get_font("SemiBold")
	var lw := sf.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(Vector2(r.get_center().x + 4.0, r.get_center().y - lw * 0.5), PI * 0.5, Vector2.ONE)
	draw_rect(Rect2(-4.0, -fs, lw + 8.0, fs + 4.0), Color(0.04, 0.04, 0.045))
	draw_string(sf, Vector2.ZERO, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.45 * dim))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
