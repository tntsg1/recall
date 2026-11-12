class_name TransitView
extends Node2D
# Above the HUD during a ride (Transit): first the map, the way from one place
# to the next drawn in red on the Board's own map; it falls away into the
# ride. On the ride, where you are going and on what, a thin line for how far,
# and (a ride seen before) the hold-to-skip. At the end the view goes dark and
# comes up on the next chapter.

const RING_C := Vector2(960, 590)
const CUT_C := Vector2(960, 500)   # the section is drawn this much larger, about this point
const CUT_K := 1.15
# the capital from above: where each place is, as (angle in degrees, radius)
const RING_AT := {1: Vector2(212, 410), 2: Vector2(196, 104), 3: Vector2(292, 282), 4: Vector2(22, 288),
	5: Vector2(100, 224), 6: Vector2(148, 402), 7: Vector2(326, 100), 12: Vector2(0, 0)}
# the section from the sea floor to orbit, in screen space
const CUT_AT := {1: Vector2(430, 860), 7: Vector2(760, 610), 8: Vector2(1385, 880), 9: Vector2(1470, 450),
	10: Vector2(1470, 232), 11: Vector2(1085, 214), 12: Vector2(900, 352)}
const CUT_WAY := {7: [Vector2(760, 610), Vector2(1250, 640), Vector2(1385, 880)],
	8: [Vector2(1385, 880), Vector2(1470, 640), Vector2(1470, 450)],
	9: [Vector2(1470, 450), Vector2(1470, 232)],
	10: [Vector2(1470, 232), Vector2(1280, 196), Vector2(1085, 214)],
	11: [Vector2(1085, 214), Vector2(990, 260), Vector2(900, 352)]}

var tr: Transit
var ma := 1.0                # the map's alpha, for ik()
var font: Font
var font_s: Font
var font_l: Font


func _ready() -> void:
	font = Fonts.get_font("SemiBold")
	font_s = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	visible = false


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	match tr.state:
		Transit.MAP:
			_draw_map()
		Transit.RIDE:
			_draw_ride()
		Transit.ARRIVE:
			_draw_ride()
			# dark, then the next chapter comes up out of it
			var k := tr.t / (Transit.ARRIVE_T * 0.5)
			var a := clampf(k, 0.0, 1.0) if k < 1.0 else clampf(2.0 - k, 0.0, 1.0)
			draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, Pal.ease_io(a)))


# ------------------------------------------------------------------ the map

func _draw_map() -> void:
	var t := tr.t
	var zoom_u := clampf((t - (Transit.MAP_T - Transit.ZOOM_T)) / Transit.ZOOM_T, 0.0, 1.0)
	var a := clampf(t / 0.18, 0.0, 1.0) * (1.0 - Pal.ease_in(zoom_u))
	var head := _way_point(1.0)
	# it falls away toward where you are going, into the ride
	var s := 1.0 + Pal.ease_in(zoom_u) * 2.2 + (1.0 - Pal.ease_out(clampf(t / 0.35, 0.0, 1.0))) * 0.04
	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, a))
	var hc := head if tr.view_map() == "ring" else CUT_C + (head - CUT_C) * CUT_K
	# (where the way ends goes to the middle of the screen as the map grows: the deck is there)
	var land := hc.lerp(Vector2(960, 540), Pal.ease_io(clampf(zoom_u * 1.4, 0.0, 1.0)))
	var off := land - hc
	draw_set_transform(hc - hc * s + off, 0.0, Vector2(s, s))
	if tr.view_map() == "ring":
		_ring_map(a)
	else:
		# (the section is drawn half as large again, about the screen's middle)
		draw_set_transform(hc - hc * s + (CUT_C - CUT_C * CUT_K) * s + off, 0.0, Vector2(s, s) * CUT_K)
		_cut_map(a)
	if tr.view_map() != "ring":
		draw_set_transform(hc - hc * s + (CUT_C - CUT_C * CUT_K) * s + off, 0.0, Vector2(s, s) * CUT_K)
	_way(a, clampf((t - 0.3) / 0.8, 0.0, 1.0))
	_markers(a, tr.view_map() == "ring")
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the title of the map and what you are taking
	var title := Txt.t("map_ring" if tr.view_map() == "ring" else "map_cut")
	draw_string(font_s, Vector2(120, 92), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.55 * a))
	draw_line(Vector2(120, 104), Vector2(560, 104), Pal.ink(0.25 * a), 1.0)
	var from := Chapters.title_story(tr.leg)
	var to := Chapters.title_story(tr.leg + 1)
	Picks.scramble(self, font, from + "  →  " + to, Vector2(960, 1000), 30, Pal.ink(0.95 * a, 1.2), (t - 0.1) * 2.6, true)
	draw_string(font_s, Vector2(960, 1040), Txt.t("ride_v_%d" % tr.leg), HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Pal.ink(0.5 * a))


func ik(x: float, k := 1.0) -> Color:
	return Pal.ink(x * ma, k)


func _ring_pos(story: int) -> Vector2:
	var v: Vector2 = RING_AT.get(story, Vector2.ZERO)
	return RING_C + Vector2.from_angle(deg_to_rad(v.x)) * v.y


func _ring_map(a: float) -> void:
	var c := RING_C
	ma = a
	# lower streets: a dense band of lanes; the industrial ring: blocks; the loop: a lit line
	draw_arc(c, 440.0, 0, TAU, 160, ik(0.45), 1.5)
	draw_arc(c, 330.0, 0, TAU, 140, ik(0.35), 1.0)
	for k in 72:
		var v := Vector2.from_angle(TAU * k / 72.0)
		draw_line(c + v * 336.0, c + v * (432.0 - (k % 3) * 18.0), ik(0.1), 1.0)
	for k in 36:
		var v := Vector2.from_angle(TAU * k / 36.0 + 0.05)
		var p := c + v * 282.0
		var n := Vector2(-v.y, v.x)
		var q := PackedVector2Array([p - n * 18 - v * 22, p + n * 18 - v * 22, p + n * 18 + v * 22, p - n * 18 + v * 22, p - n * 18 - v * 22])
		draw_polyline(q, ik(0.18), 1.0)
	draw_arc(c, 232.0, 0, TAU, 120, ik(0.25), 1.0)
	draw_arc(c, 224.0, 0, TAU, 120, ik(0.12), 8.0)
	draw_arc(c, 224.0, 0, TAU, 120, ik(0.8, 1.5), 2.0)
	draw_arc(c, 160.0, 0, TAU, 100, ik(0.4), 1.0)
	for gx in range(-4, 5):
		for gy in range(-4, 5):
			var p := c + Vector2(gx, gy) * 30.0
			if p.distance_to(c) < 140.0 and p.distance_to(c) > 34.0:
				draw_rect(Rect2(p - Vector2(10, 10), Vector2(20, 20)), ik(0.14), false, 1.0)
	# the tower in the middle, its light the brightest thing on the map
	draw_circle(c, 16.0, ik(0.9, 1.8))
	draw_arc(c, 26.0, 0, TAU, 40, ik(0.4, 1.4), 1.0)
	# the districts' names, along the top of their bands
	for row in [["map_lower", 386.0], ["map_industry", 300.0], ["map_loop", 248.0], ["map_center", 182.0]]:
		var p := c + Vector2(0, -float(row[1]))
		draw_string(font_s, p + Vector2(-160, 6), Txt.t(row[0]), HORIZONTAL_ALIGNMENT_CENTER, 320, 15, ik(0.4))
	draw_string(font_s, c + Vector2(-160, 52), Txt.t("map_tower"), HORIZONTAL_ALIGNMENT_CENTER, 320, 15, ik(0.55))
	# 13th Street is underground: a dashed outline, twelve floors down
	var u := _ring_pos(1)
	_dashed_rect(Rect2(u - Vector2(34, 26), Vector2(68, 52)), ik(0.5))
	draw_string(font_s, u + Vector2(-160, 46), Txt.t("map_under"), HORIZONTAL_ALIGNMENT_CENTER, 320, 13, ik(0.35))


func _cut_map(a: float) -> void:
	ma = a
	var ground := 640.0
	# orbit
	draw_line(Vector2(240, 240), Vector2(1680, 240), ik(0.2), 1.0)
	for i in 70:
		var p := Vector2(240 + fmod(i * 197.0, 1440.0), 150 + fmod(i * 61.0, 120.0))
		draw_rect(Rect2(p, Vector2(2, 2)), ik(0.35, 1.2))
	draw_string(font_s, Vector2(250, 232), Txt.t("map_orbit"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ik(0.4))
	# the cloud line
	var cl := PackedVector2Array()
	for i in 73:
		var x := 240.0 + i * 20.0
		cl.append(Vector2(x, 432.0 + 6.0 * sin(i * 0.9)))
	draw_polyline(cl, ik(0.28), 1.0)
	draw_string(font_s, Vector2(250, 424), Txt.t("map_cloud"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ik(0.4))
	# ground and the city on it, the white tower through the clouds
	draw_line(Vector2(240, ground), Vector2(1250, ground), ik(0.6), 1.5)
	for i in 30:
		var x := 570.0 + i * 22.0
		var h := 30.0 + fmod(i * 47.0, 110.0)
		if absf(x - 900.0) < 30.0:
			continue
		draw_rect(Rect2(x, ground - h, 16, h), ik(0.25), false, 1.0)
	draw_rect(Rect2(884, 352, 32, ground - 352), Color(0.05, 0.05, 0.056, a))
	draw_rect(Rect2(884, 352, 32, ground - 352), ik(0.85, 1.5), false, 1.5)
	# the bedrock under the city, in faint strata
	for k in 4:
		var st := PackedVector2Array()
		for i in 18:
			var x := 570.0 + i * 40.0
			st.append(Vector2(x, ground + 70.0 + k * 60.0 + 8.0 * sin(i * 0.8 + k * 1.7)))
		draw_polyline(st, ik(0.09), 1.0)
	# the undercity: twelve floors below the street
	for k in 13:
		var y := ground + 18.0 + k * 19.0
		draw_line(Vector2(300, y), Vector2(560, y), ik(0.22 if k < 12 else 0.4), 1.0)
	draw_string(font_s, Vector2(300, ground + 280), Txt.t("map_under"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ik(0.35))
	# the sea and its floor
	var sea := PackedVector2Array()
	for i in 22:
		sea.append(Vector2(1250 + i * 20.0, ground + 3.0 * sin(i * 1.3)))
	draw_polyline(sea, ik(0.5), 1.0)
	draw_string(font_s, Vector2(1560, ground - 10), Txt.t("map_sea"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ik(0.4))
	for k in 4:
		var y := ground + 60.0 + k * 62.0
		draw_line(Vector2(1258, y), Vector2(1290, y), ik(0.4), 1.0)
		draw_line(Vector2(1300, y), Vector2(1440, y), ik(0.08), 1.0)
		draw_rect(Rect2(1532, y - 16, 58, 18), Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, 0.92 * ma))
		draw_string(font_s, Vector2(1536, y - 3), ["-1000 M", "-2000 M", "-3000 M", "-4200 M"][k], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ik(0.5))
	var bed := PackedVector2Array()
	for i in 22:
		bed.append(Vector2(1250 + i * 20.0, 900.0 + 14.0 * sin(i * 0.7) + fmod(i * 13.0, 9.0)))
	draw_polyline(bed, ik(0.4), 1.0)
	# the orbital lift: from its anchor in the sea to the shipyard
	draw_line(Vector2(1470, 900), Vector2(1470, 210), ik(0.75, 1.4), 1.5)
	draw_rect(Rect2(1420, 206, 100, 40), ik(0.5), false, 1.0)
	# the institute: rings in orbit
	draw_arc(Vector2(1085, 214), 24.0, 0, TAU, 32, ik(0.6, 1.3), 1.5)
	draw_arc(Vector2(1085, 214), 36.0, 0.4, TAU - 0.6, 32, ik(0.3), 1.0)


# Every place on this map: a dim mark, the two of this ride bright, their names.
func _markers(a: float, ring: bool) -> void:
	var table: Dictionary = RING_AT if ring else CUT_AT
	for story in table:
		var p: Vector2 = _ring_pos(story) if ring else CUT_AT[story]
		var here: bool = story == tr.leg or story == tr.leg + 1
		var past: bool = story < tr.leg
		var c := Pal.ink((0.95 if here else 0.45) * a, 1.4 if here else 1.0)
		if story == tr.leg + 1:
			var pulse := 0.5 + 0.5 * sin(tr.t * 9.0)
			draw_arc(p, 14.0 + pulse * 6.0, 0, TAU, 24, Pal.red(0.7 * a, 1.6), 2.0)
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Pal.red(0.8 * a, 1.2) if past or story == tr.leg else Color(0, 0, 0, 0))
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), c, false, 1.5)
		if here or story != 12:
			var side := 1.0 if p.x >= (RING_C.x if ring else 960.0) else -1.0
			var name := Chapters.title_story(story)
			var size := 22 if here else 14
			var w := (font if here else font_s).get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var at := p + Vector2(18.0 if side > 0.0 else -18.0 - w, 7.0)
			if not ring:
				at.y -= 30.0
			draw_rect(Rect2(at + Vector2(-6, -size - 1.0), Vector2(w + 12, size + 10.0)), Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, 0.95 * a))
			draw_string(font if here else font_s, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c if here else Pal.ink(0.45 * a))


# The way taken so far (dim) and this ride's leg (drawn on as k goes 0..1).
func _way(a: float, k: float) -> void:
	for s in range(1, tr.leg):
		if _uses_map(s) == tr.view_map():
			var old := _leg_pts(s)
			if old.size() >= 2:
				draw_polyline(old, Pal.red(0.3 * a), 2.0)
	var pts := _leg_pts(tr.leg)
	var n := int(pts.size() * Pal.ease_io(k))
	if n >= 2:
		var shown := pts.slice(0, n)
		draw_polyline(shown, Pal.red(0.15 * a), 14.0)
		if tr.view_map() == "ring":
			draw_polyline(shown, Pal.red(0.95 * a, 1.8), 4.0)
		else:
			# under the sea the way goes darker and thinner the deeper it runs
			for i in range(shown.size() - 1):
				var deep := clampf((shown[i].y - 640.0) / 260.0, 0.0, 1.0)
				draw_line(shown[i], shown[i + 1], Pal.red((0.95 - 0.45 * deep) * a, 1.8 - 0.8 * deep), 4.0 - 2.0 * deep)
		for i in range(0, n, 8):
			draw_circle(shown[i], 4.0, Pal.red(0.9 * a, 1.4))
		draw_circle(shown[shown.size() - 1], 8.0, Pal.red(a, 2.2))
		if k >= 1.0:
			for kk in 2:
				var rip := fmod(tr.t * 1.4 + kk * 0.5, 1.0)
				draw_arc(shown[shown.size() - 1], 10.0 + rip * 46.0, 0, TAU, 32, Pal.red((1.0 - rip) * 0.8 * a, 1.8), 2.0)


func _uses_map(story: int) -> String:
	return (Transit.LEGS.get(story, {}) as Dictionary).get("map", "")


func _leg_pts(story: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if _uses_map(story) == "ring":
		var a: Vector2 = RING_AT.get(story, Vector2.ZERO)
		var b: Vector2 = RING_AT.get(story + 1, Vector2.ZERO)
		var a0 := deg_to_rad(a.x)
		var a1 := deg_to_rad(b.x)
		var da := wrapf(a1 - a0, -PI, PI)
		for i in 41:
			var f := i / 40.0
			# out along the radius first, round the ring, then in: the way the lines run
			var rr := lerpf(a.y, b.y, Pal.ease_io(f))
			out.append(RING_C + Vector2.from_angle(a0 + da * f) * rr)
	else:
		var way: Array = CUT_WAY.get(story, [])
		for i in range(way.size() - 1):
			for j in 20:
				out.append((way[i] as Vector2).lerp(way[i + 1], j / 20.0))
		if not way.is_empty():
			out.append(way[way.size() - 1])
	return out


func _way_point(k: float) -> Vector2:
	var pts := _leg_pts(tr.leg)
	if pts.is_empty():
		return Vector2(960, 540)
	return pts[clampi(int((pts.size() - 1) * k), 0, pts.size() - 1)]


func _dashed_rect(r: Rect2, c: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var p0: Vector2 = corners[i]
		var p1: Vector2 = corners[(i + 1) % 4]
		var n := int(p0.distance_to(p1) / 8.0)
		for k in range(0, n, 2):
			draw_line(p0.lerp(p1, float(k) / n), p0.lerp(p1, float(k + 1) / n), c, 1.0)


# ------------------------------------------------------------------ the ride

func _draw_ride() -> void:
	var a := clampf(tr.t / 0.5, 0.0, 1.0) if tr.state == Transit.RIDE else 1.0
	var to := Chapters.title_story(tr.leg + 1)
	var line := Txt.t("ride_v_%d" % tr.leg)
	# a dark band down from the top, so the line reads over the city
	var c0 := Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, 0.88 * a)
	var c1 := Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, 0.0)
	# (only behind the words: the deep middle of the view sits up here too)
	# (the whole width round the progress line goes quiet, so no red of the city reads as it)
	var c4 := Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, 0.0)
	var c5 := Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, 0.97 * a)
	draw_polygon(PackedVector2Array([Vector2(0, 110), Vector2(1920, 110), Vector2(1920, 140), Vector2(0, 140)]), PackedColorArray([c4, c4, c5, c5]))
	draw_rect(Rect2(0, 140, 1920, 150), c5)
	draw_polygon(PackedVector2Array([Vector2(0, 290), Vector2(1920, 290), Vector2(1920, 300), Vector2(0, 300)]), PackedColorArray([c5, c5, c4, c4]))
	var c9 := Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, 0.94 * a)
	draw_rect(Rect2(560, 0, 800, 200), c9)
	draw_polygon(PackedVector2Array([Vector2(560, 200), Vector2(1360, 200), Vector2(1360, 270), Vector2(560, 270)]), PackedColorArray([c9, c9, c1, c1]))
	draw_polygon(PackedVector2Array([Vector2(360, 0), Vector2(560, 0), Vector2(560, 250), Vector2(360, 250)]), PackedColorArray([c1, c0, c1, c1]))
	draw_polygon(PackedVector2Array([Vector2(1360, 0), Vector2(1560, 0), Vector2(1560, 250), Vector2(1360, 250)]), PackedColorArray([c0, c1, c1, c1]))
	var b0 := Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, 0.0)
	var b1 := Color(Pal.BG.r, Pal.BG.g, Pal.BG.b, 0.9 * a)
	draw_polygon(PackedVector2Array([Vector2(0, 930), Vector2(1920, 930), Vector2(1920, 1080), Vector2(0, 1080)]), PackedColorArray([b0, b0, b1, b1]))
	draw_string(font_s, Vector2(560, 150), line, HORIZONTAL_ALIGNMENT_CENTER, 800, 19, Pal.ink(0.6 * a))
	draw_string(font, Vector2(460, 192), "→  " + to, HORIZONTAL_ALIGNMENT_CENTER, 1000, 30, Pal.ink(0.95 * a, 1.25))
	# how far along: a red line, the way on the map
	var w := 480.0
	var x0 := 960.0 - w / 2.0
	draw_line(Vector2(x0, 220), Vector2(x0 + w, 220), Pal.ink(0.14 * a), 4.0)
	draw_line(Vector2(x0, 220), Vector2(x0 + w * tr.u, 220), Pal.red(0.95 * a, 1.6), 4.0)
	draw_circle(Vector2(x0 + w * tr.u, 220), 5.0, Pal.red(a, 2.2))
	if tr.seen and tr.state == Transit.RIDE:
		var k := tr.skip_t / Transit.SKIP_HOLD
		var txt := Txt.t("ride_skip")
		var tw := font_s.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var p := Vector2(Hud.BAND_EDGE, 1040)
		draw_string(font_s, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Pal.ink((0.5 + 0.45 * k) * a))
		draw_line(p + Vector2(0, 8), p + Vector2(tw, 8), Pal.ink(0.15 * a), 2.0)
		draw_line(p + Vector2(0, 8), p + Vector2(tw * k, 8), Pal.red(0.95, 1.6), 2.0)
