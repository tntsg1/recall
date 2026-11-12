class_name Transit
extends Node2D
# Between two chapters (full game only): a map draws the way on (the capital
# ring from above, or the section from the sea floor to orbit), then a ride.
# R-0 stands on a moving deck (a freight lift, a maglev flatcar, a pressure
# capsule...) while the FCU's megastructures pass beneath (Scenery), and a
# few units climb aboard to be shot or seized. The chapter's fight is over,
# so nothing they do can hurt you, and the ride's time counts toward no par.
# A ride seen once can be skipped by holding Tab / Select.
# This node draws the deck; the map and the captions are TransitView's.

enum { OFF, MAP, RIDE, ARRIVE }

const DECK := Rect2(500, 300, 920, 480)
const MAP_T := 1.75         # the map, before the ride
const ZOOM_T := 0.45        # its last part: the map falls away into the ride
const RIDE_MIN := 13.0
const RIDE_MAX := 22.0
const ARRIVE_T := 1.0       # the view goes dark and comes up on the next chapter
const SKIP_HOLD := 0.7
const CABLE := Rect2(915, 495, 90, 90)   # the lift's cable through the deck (legs 8, 9)

# by the story number the ride leaves from: what you ride, which map, who climbs aboard
const LEGS := {
	1: {"deck": "lift", "map": "ring", "kinds": [Enemies.CHASER, Enemies.GUARD, Enemies.PRISM]},
	2: {"deck": "car", "map": "ring", "kinds": [Enemies.CHASER, Enemies.CHARGER, Enemies.ECHO]},
	3: {"deck": "flat", "map": "ring", "kinds": [Enemies.CHASER, Enemies.CHARGER, Enemies.LEECH]},
	4: {"deck": "flat", "map": "ring", "kinds": [Enemies.CHASER, Enemies.GUARD, Enemies.PRISM]},
	5: {"deck": "car", "map": "ring", "kinds": [Enemies.CHASER, Enemies.CHARGER, Enemies.PULSE]},
	6: {"deck": "flat", "map": "ring", "kinds": [Enemies.CHASER, Enemies.GUARD, Enemies.PULSE]},
	7: {"deck": "capsule", "map": "cut", "kinds": [Enemies.CHASER, Enemies.CHARGER, Enemies.ECHO]},
	8: {"deck": "lift", "map": "cut", "kinds": [Enemies.CHASER, Enemies.GUARD, Enemies.PULSE]},
	9: {"deck": "lift", "map": "cut", "kinds": [Enemies.CHASER, Enemies.CHARGER, Enemies.PRISM]},
	10: {"deck": "car", "map": "cut", "kinds": [Enemies.CHASER, Enemies.GUARD, Enemies.PHASE]},
	11: {"deck": "capsule", "map": "cut", "kinds": [Enemies.CHASER, Enemies.CHARGER, Enemies.PULSE]},
}

static var force := false   # tests: ride even with a bot playing

var game
var state := OFF
var t := 0.0
var leg := 0                # the story number the ride leaves from
var u := 0.0                # how far along (0..1)
var end_at := RIDE_MAX
var groups: Array = []      # [time, kind, count]
var spawned := 0
var skip_t := 0.0
var seen := false
var swapped := false
var deck_kind := "lift"
var scenery: Scenery
var view: TransitView
var font: Font


func _ready() -> void:
	z_index = -9
	z_as_relative = false
	visible = false
	font = Fonts.get_font("SemiBold")
	scenery = Scenery.new()
	add_sibling.call_deferred(scenery)
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	view = TransitView.new()
	view.tr = self
	layer.add_child(view)
	if not InputMap.has_action("skip_ride"):
		InputMap.add_action("skip_ride")
		var k := InputEventKey.new()
		k.physical_keycode = KEY_TAB
		InputMap.action_add_event("skip_ride", k)
		var b := InputEventJoypadButton.new()
		b.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event("skip_ride", b)


# From Waves, when a chapter is done: true while a ride runs (it starts one if it should).
func take(ch: int) -> bool:
	if state != OFF:
		return true
	if not wanted(ch):
		return false
	_begin(ch)
	return true


func wanted(ch: int) -> bool:
	if not Demo.extras() or game.tutorial != null or (game.bot != null and not force):
		return false
	if ch + 1 >= Chapters.count():
		return false
	var a := Chapters.story(ch)
	return LEGS.has(a) and Chapters.story(ch + 1) == a + 1


# The map and the cut to dark hold the world still.
func holds() -> bool:
	return state == MAP or (state == ARRIVE and not swapped)


func riding() -> bool:
	return state == RIDE


func view_map() -> String:
	return (LEGS.get(leg, {}) as Dictionary).get("map", "ring")


func _begin(ch: int) -> void:
	leg = Chapters.story(ch)
	var d: Dictionary = LEGS[leg]
	deck_kind = d.deck
	state = MAP
	t = 0.0
	u = 0.0
	end_at = RIDE_MAX
	spawned = 0
	skip_t = 0.0
	swapped = false
	seen = _seen(leg)
	game.lightwalk.stop()
	game.ammo = mini(game.mag, game.ammo + game.bullets.clear_for_chapter())
	for e in game.enemies.list:
		e.state = Enemies.DEAD
	# the deck: blocks all round hold you, your rounds and the climbers on it
	var r := Arena.ROOM
	var walls: Array = [Rect2(r.position.x, r.position.y, r.size.x, DECK.position.y - r.position.y),
		Rect2(r.position.x, DECK.end.y, r.size.x, r.end.y - DECK.end.y),
		Rect2(r.position.x, DECK.position.y, DECK.position.x - r.position.x, DECK.size.y),
		Rect2(DECK.end.x, DECK.position.y, r.end.x - DECK.end.x, DECK.size.y)]
	var cover: Array = [CABLE] if _has_cable() else []
	game.arena.open = true
	game.arena.setup(-1, {"walls": walls, "cover": cover})
	game.lasers.setup(-1)
	game.arms.setup(-1)
	game.maglev.setup(-1, -1)
	game.arcs.setup(-1)
	game.scan_rings.setup(-1)
	game.shelves.setup(-1)
	game.vents.setup(-1)
	game.plates.setup(-1)
	game.stasis.setup(-1)
	game.nodes.setup(-1)
	game.rooms.active = false
	game.rooms.lay = {}
	game.rooms.visible = false
	game.lore.visible = false
	game.floor_rect.visible = false
	game.boss.visible = false
	if game.vista != null:
		game.vista.visible = false
	game.player.pos = DECK.get_center() + Vector2(-220, 0)
	game.player.vel = Vector2.ZERO
	scenery.begin(leg)
	scenery.step(0.0, 0.0)
	visible = true
	view.visible = true
	groups = [[2.2, Enemies.CHASER, 3], [6.0, d.kinds[1], 1], [6.3, Enemies.CHASER, 2], [9.8, d.kinds[2], 2], [10.1, Enemies.CHASER, 2]]
	game.sfx.play("title", 0.8, -4.0)


func _has_cable() -> bool:
	return leg == 8 or leg == 9


func step(dt: float) -> void:
	match state:
		MAP:
			t += dt
			if t >= MAP_T:
				state = RIDE
				t = 0.0
				game.sfx.play("dash", 0.6, -6.0)
		RIDE:
			t += dt
			while spawned < groups.size() and t >= groups[spawned][0]:
				_spawn(groups[spawned])
				spawned += 1
			if spawned >= groups.size() and game.enemies.remaining() == 0:
				end_at = minf(end_at, maxf(t + 2.6, RIDE_MIN))
			if absf(t - 1.2) < dt * 0.6:
				game.hud.radio(Txt.t("ride_r_%d" % leg))
			var left := maxf(end_at - t, 0.001)
			u = minf(1.0, u + (1.0 - u) * minf(dt / left, 1.0))
			if seen and Input.is_action_pressed("skip_ride"):
				skip_t += dt
				if skip_t >= SKIP_HOLD:
					_arrive()
			else:
				skip_t = maxf(0.0, skip_t - dt * 2.0)
			if t >= end_at:
				_arrive()
		ARRIVE:
			t += dt
			if not swapped and t >= ARRIVE_T * 0.5:
				_swap()
			if t >= ARRIVE_T:
				state = OFF
				view.visible = false
	if state != OFF and not swapped:
		scenery.step(dt, u)
	queue_redraw()


func _spawn(g: Array) -> void:
	var kind: int = g[1]
	var n: int = g[2]
	var spec: Dictionary = Enemies.SPEC[kind]
	var pl: Vector2 = game.player.pos
	for i in n:
		var p := Vector2.ZERO
		for tries in 30:
			var side := randi() % 4
			var m: float = spec.r + 30.0
			match side:
				0: p = Vector2(randf_range(DECK.position.x + 80, DECK.end.x - 80), DECK.position.y + m)
				1: p = Vector2(randf_range(DECK.position.x + 80, DECK.end.x - 80), DECK.end.y - m)
				2: p = Vector2(DECK.position.x + m, randf_range(DECK.position.y + 80, DECK.end.y - 80))
				_: p = Vector2(DECK.end.x - m, randf_range(DECK.position.y + 80, DECK.end.y - 80))
			if p.distance_to(pl) > 280.0 and game.arena.is_free(p, spec.r + 6.0):
				break
		game.enemies.spawn(kind, p, i * 0.12)
		# it climbs over the rail: a flash where its hands catch
		game.fx.ring(p, 6.0, 36.0, 0.35, Pal.ink(0.6, 1.4), 1.2)


func _arrive() -> void:
	if state != RIDE:
		return
	for e in game.enemies.list:
		if e.state != Enemies.DEAD and e.state != Enemies.HOST:
			game.fx.ring(e.pos, 6.0, 30.0, 0.3, Pal.ink(0.4), 1.0)
			e.state = Enemies.DEAD
	if game.possess.hosting():
		game.possess.end(false, true)
	_mark_seen(leg)
	state = ARRIVE
	t = 0.0
	game.sfx.play("tick", 0.6, -4.0)


func _swap() -> void:
	swapped = true
	scenery.visible = false
	visible = false
	game.arena.open = false
	game.rooms.visible = true
	game.lore.visible = true
	game.floor_rect.visible = true
	var old = game.boss
	game.next_chapter()
	old.visible = true
	game.boss.visible = true


# ------------------------------------------------------------------ seen

static func _seen(story: int) -> bool:
	var d := Meta.load_data()
	return d.get("rides", {}) is Dictionary and (d.get("rides", {}) as Dictionary).has(str(story))


static func _mark_seen(story: int) -> void:
	var d := Meta.load_data()
	if not d.get("rides") is Dictionary:
		d.rides = {}
	if not d.rides.has(str(story)):
		d.rides[str(story)] = true
		Meta.save()


# ------------------------------------------------------------------ the deck

func _draw() -> void:
	if state == OFF or swapped:
		return
	var f: float = game.focus
	var rim := Pal.ink(0.9 - 0.3 * f, 1.25)
	var faint := Pal.ink(0.14 - 0.05 * f)
	var r := DECK
	# a hair of vibration along the rim: the deck is moving
	var jit := Vector2(0, 0.6 * sin(scenery.t * 37.0)) * minf(scenery.vel.length() / 900.0, 1.5)
	match deck_kind:
		"capsule":
			_round_rect(r, 70.0, Color(0.05, 0.05, 0.056), true)
			_round_rect(r.grow(-2.0), 68.0, rim, false, 3.0)
			_round_rect(r.grow(-16.0), 56.0, faint, false, 1.0)
			# rivets round the hull
			for k in 28:
				var fpos := float(k) / 28.0
				var p := _round_rect_point(r.grow(-9.0), 62.0, fpos)
				draw_circle(p, 2.0, Pal.ink(0.35))
		_:
			draw_rect(r, Color(0.05, 0.05, 0.056))
			# floor: plates for a lift, slats along a car, a grid on a flatcar
			match deck_kind:
				"lift":
					var x := r.position.x + 90.0
					while x < r.end.x:
						draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), faint, 1.0)
						x += 90.0
					var y := r.position.y + 96.0
					while y < r.end.y:
						draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), faint, 1.0)
						y += 96.0
				"car":
					var y := r.position.y + 36.0
					while y < r.end.y:
						draw_line(Vector2(r.position.x + 30, y), Vector2(r.end.x - 30, y), faint, 1.0)
						y += 36.0
				_:
					var x := r.position.x + 60.0
					while x < r.end.x:
						draw_line(Vector2(x, r.position.y + 20), Vector2(x, r.end.y - 20), faint, 1.0)
						x += 60.0
			draw_rect(Rect2(r.position + jit, r.size), rim, false, 3.0)
			draw_rect(r.grow(-12.0), faint, false, 1.0)
			# hazard stripes along the edge you would fall from
			var step := 22.0
			var hz := Pal.ink(0.22)
			var x2 := r.position.x + 8.0
			while x2 < r.end.x - 20.0:
				draw_line(Vector2(x2, r.position.y + 4), Vector2(x2 + 10, r.position.y + 12), hz, 2.0)
				draw_line(Vector2(x2, r.end.y - 12), Vector2(x2 + 10, r.end.y - 4), hz, 2.0)
				x2 += step
			# corner posts (a lift's guide shoes; a car's couplings)
			for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				var q := Rect2(c - Vector2(14, 14), Vector2(28, 28))
				draw_rect(q, Pal.WALL)
				draw_rect(q, rim, false, 2.0)
				draw_circle(c, 3.0, Pal.ink(0.9, 1.8))
	# the stencil on the floor
	var label := "FCU-%02d" % (leg * 7 % 97)
	draw_string(font, r.position + Vector2(40, r.size.y - 34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Pal.ink(0.07))
	if _has_cable():
		# the lift's cable runs up through the middle of the deck
		var c := CABLE.get_center()
		draw_rect(CABLE, Pal.WALL)
		draw_rect(CABLE, rim, false, 2.0)
		draw_circle(c, 30.0, Color(0.09, 0.09, 0.1))
		draw_arc(c, 30.0, 0, TAU, 32, Pal.ink(0.8, 1.6), 2.0)
		var spin := scenery.t * 9.0
		for k in 6:
			var v := Vector2.from_angle(spin + TAU * k / 6.0)
			draw_line(c + v * 12.0, c + v * 28.0, Pal.ink(0.5), 1.5)


func _round_rect(r: Rect2, rad: float, c: Color, filled: bool, w := 1.0) -> void:
	var pts := PackedVector2Array()
	for k in 64:
		pts.append(_round_rect_point(r, rad, k / 64.0))
	if filled:
		draw_colored_polygon(pts, c)
	else:
		pts.append(pts[0])
		draw_polyline(pts, c, w)


# A point a fraction f of the way round a rounded rectangle (corners as quarter circles).
func _round_rect_point(r: Rect2, rad: float, f: float) -> Vector2:
	var corners := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var q := int(f * 4.0) % 4
	var g := f * 4.0 - floorf(f * 4.0)
	# each quarter: a straight run, then a quarter circle
	var a0 := -PI / 2.0 + q * PI / 2.0
	var c: Vector2 = corners[q]
	var prev: Vector2 = corners[(q + 3) % 4]
	if g < 0.5:
		var s := prev + Vector2.from_angle(a0) * rad
		var e := c + Vector2.from_angle(a0) * rad
		return s.lerp(e, g * 2.0)
	return c + Vector2.from_angle(a0 + (g - 0.5) * 2.0 * PI / 2.0) * rad
