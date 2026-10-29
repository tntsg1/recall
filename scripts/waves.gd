class_name Waves
extends Node
# A chapter: a title, six waves drawn at random from a budget, then the boss.
# Each wave runs a clock from the first enemy to the last kill (+5 s per hit)
# and closes with an S / A / B stamp; a card pick follows every wave.

enum { INTRO, TITLE, FIGHT, CLEAR, DONE }

const C := Enemies.CHASER
const G := Enemies.GUARD
const H := Enemies.CHARGER
const P := Enemies.PRISM
const L := Enemies.LEECH
const U := Enemies.PULSE
const E := Enemies.ECHO
const I := Enemies.INSPECTOR
const W := Enemies.PROOFREADER
const COUNT := 7
const BOSS := 6
const COST := {C: 1, G: 5, H: 4, P: 3, L: 3, U: 4, E: 3, I: 3, W: 3}
const BUDGET := [16, 22, 28, 32, 40, 48]
# the waves' own notes, by enemy pool (the boss wave's note comes from Chapters)
const NOTES := [{2: "note_guard", 3: "note_charger"}, {0: "note_mirror", 1: "note_prism"}, {0: "note_arms", 1: "note_leech"}, {0: "note_rings", 1: "note_pulse"}, {}, {0: "note_rails"}, {0: "note_lasers", 1: "note_echo"}, {0: "note_arcs", 1: "note_inspector"}, {0: "note_shelves", 1: "note_proofreader"}]
const SIDES := ["T", "B", "L", "R"]

var game
var phase := INTRO
var index := -1
var t := 0.0
var clock := 0.0
var penalty := 0.0
var queue: Array = []
var results: Array = []   # [time, grade]
var pick_state := 0       # 0 none yet, 1 cards up, 2 chosen
var pick_done_t := 0.0
var plan: Array = []      # per wave: {groups: [[delay, kind, count, side]], par: [S, A]}
var chapter := 0
var pool := 0                 # which enemies this chapter teaches and mixes (Chapters)
var chapter_log: Array = []   # finished chapters: [label, time, grades]


func _ready() -> void:
	_build_plan()


func start_chapter(ch: int) -> void:
	chapter = ch
	pool = Chapters.pool(ch)
	index = -1
	phase = INTRO
	t = 0.0
	results.clear()
	queue.clear()
	pick_state = 0
	_build_plan()


# Random waves, with the two teaching waves keeping their new enemy.
func _build_plan() -> void:
	plan.clear()
	var scale := (1.0 + 0.3 * chapter) * Loadout.budget()
	for i in BOSS:
		var budget: int = int(BUDGET[i] * scale)
		var kinds: Array = []
		var left := budget
		match i:
			0:
				pass
			1 when pool == 0 or pool == 5 or pool == 4:
				pass
			1 when pool == 1:
				kinds.append(P)
				kinds.append(P)
				left -= COST[P] * 2
			1 when pool == 2:
				kinds.append(L)
				kinds.append(L)
				kinds.append(L)
				left -= COST[L] * 3
			1 when pool == 3:
				for k in 3:
					kinds.append(U)
				left -= COST[U] * 3
			1 when pool == 6:
				for k in 3:
					kinds.append(E)
				left -= COST[E] * 3
			1 when pool == 7:
				for k in 3:
					kinds.append(I)
				left -= COST[I] * 3
			1 when pool == 8:
				for k in 3:
					kinds.append(W)
				left -= COST[W] * 3
			1:
				pass
			2 when pool == 0:
				kinds.append(G)
				left -= COST[G]
			3 when pool == 0:
				kinds.append(H)
				kinds.append(H)
				left -= COST[H] * 2
			_:
				var specials := randi_range(2, 4) + chapter
				var mix: Array = [G, H]
				if pool == 1:
					mix = [G, H, P, P]
				elif pool == 2:
					mix = [G, H, P, L, L]
				elif pool == 5:
					mix = [G, H, H, P, L]
				elif pool == 3:
					mix = [G, H, L, U, U]
				elif pool == 6:
					mix = [G, H, H, P, E]
				elif pool == 7:
					mix = [G, H, P, L, I, I]
				elif pool == 8:
					mix = [G, H, P, L, E, W, W]
				elif pool == 4:
					mix = [G, H, P, L, U, E, E]
				for k in specials:
					var kind: int = mix[randi() % mix.size()]
					if left - COST[kind] >= 8:
						kinds.append(kind)
						left -= COST[kind]
		var groups: Array = []
		var delay := 0.0
		var side_i := randi() % 4
		for kind in kinds:
			groups.append([delay, kind, 1, SIDES[side_i]])
			side_i = (side_i + 1 + randi() % 3) % 4
			delay += randf_range(0.6, 1.4)
		# the rest are chasers, in packs of 4-8
		var chase := left
		delay = 0.0 if kinds.is_empty() else 1.0
		while chase > 0:
			var n := mini(chase, randi_range(4, 8))
			if chase - n < 3:
				n = chase
			groups.append([delay, C, n, SIDES[side_i]])
			side_i = (side_i + 1 + randi() % 3) % 4
			chase -= n
			delay += randf_range(2.0, 3.4)
		var last := 0.0
		for g in groups:
			last = maxf(last, g[0])
		var s := roundf(3.0 + 0.26 * budget + 0.45 * last)
		plan.append({"groups": groups, "par": [s, roundf(s * 1.5)]})
	plan.append({"groups": [], "par": Chapters.at(chapter).par})


func time_now() -> float:
	return clock + penalty


func par(i: int) -> Array:
	return plan[i].par


func grade_for(i: int, time: float) -> String:
	var p: Array = par(i)
	if time <= p[0]:
		return "S"
	if time <= p[1]:
		return "A"
	return "B"


func add_penalty(s: float) -> void:
	if phase == FIGHT:
		penalty += s


func step(dt: float) -> void:
	t += dt
	match phase:
		INTRO:
			if t >= 2.6:
				_next()
		TITLE:
			if t >= (2.6 if index == BOSS else 1.5):
				phase = FIGHT
				t = 0.0
				clock = 0.0
				penalty = 0.0
				queue = (plan[index].groups as Array).duplicate(true)
				game.on_wave_start()
				if index == BOSS:
					game.boss.start()
		FIGHT:
			clock += dt
			var k := 0
			while k < queue.size():
				var q: Array = queue[k]
				if t >= q[0]:
					_spawn_group(q[1], q[2], q[3])
					queue.remove_at(k)
				else:
					k += 1
			var boss_up: bool = index == BOSS and game.boss.state != Boss.DEAD
			if queue.is_empty() and game.enemies.remaining() == 0 and not boss_up and not game.trial:
				var tm := time_now()
				var g := grade_for(index, tm)
				results.append([tm, g])
				phase = CLEAR
				t = 0.0
				game.wave_half = false
				game.on_wave_clear(index, tm, g)
				if index == BOSS:
					game.on_chapter_clear()
					var sum := 0.0
					var grades := {"S": 0, "A": 0, "B": 0}
					for r in results:
						sum += r[0]
						if grades.has(r[1]):   # waves skipped in dev mode carry "-"
							grades[r[1]] += 1
					chapter_log.append([Chapters.label(chapter) + " · " + Chapters.title(chapter), sum, "S%d A%d B%d" % [grades.S, grades.A, grades.B]])
		CLEAR:
			# the run ends after the last chapter's boss; other bosses lead on
			var last: bool = index + 1 >= COUNT and chapter + 1 >= Chapters.count()
			if not last and pick_state == 0 and t >= 1.1:
				pick_state = 1
				game.start_pick()
			if pick_state == 1:
				return
			if t >= 2.4 and (last or t >= pick_done_t + 0.7):
				if last:
					phase = DONE
					t = 0.0
					game.on_run_done(chapter_log)
				elif index + 1 >= COUNT:
					game.next_chapter()
				else:
					_next()


func pick_done() -> void:
	pick_state = 2
	pick_done_t = t


func _next() -> void:
	pick_state = 0
	index += 1
	phase = TITLE
	t = 0.0
	var note: String = Chapters.at(chapter).note if index == BOSS else (NOTES[pool] as Dictionary).get(index, "")
	game.on_wave_title(index, note)
	if index == BOSS:
		game.boss.begin_track()


func _spawn_group(kind: int, count: int, side: String) -> void:
	var room := Arena.ROOM.grow(-70)
	var pl: Vector2 = game.player.pos
	var center := Vector2.ZERO
	for tries in 40:
		match side:
			"T":
				center = Vector2(randf_range(room.position.x + 200, room.end.x - 200), room.position.y + 40)
			"B":
				center = Vector2(randf_range(room.position.x + 200, room.end.x - 200), room.end.y - 40)
			"L":
				center = Vector2(room.position.x + 40, randf_range(room.position.y + 150, room.end.y - 150))
			_:
				center = Vector2(room.end.x - 40, randf_range(room.position.y + 150, room.end.y - 150))
		if center.distance_to(pl) > 420.0:
			break
	var spec: Dictionary = Enemies.SPEC[kind]
	var placed: Array[Vector2] = []
	for i in count:
		var p := center
		for tries in 30:
			p = center + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 30.0 + count * 14.0)
			p = p.clamp(room.position, room.end)
			var ok: bool = game.arena.is_free(p, spec.r + 6.0) and p.distance_to(pl) > 300.0
			for o in placed:
				if o.distance_to(p) < spec.r * 2.6:
					ok = false
			if ok:
				break
		placed.append(p)
		game.enemies.spawn(kind, p, i * 0.07)
