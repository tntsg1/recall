class_name Warm
extends Node2D
# Seamless start: while the title is on screen, everything the run needs is
# brought in a little at a time — a millisecond or two of loading a frame, a
# heavy shader alone in its frame — and kept alive here, so building the run
# only assembles things that are already in memory. Then each shader, texture and text size the run uses is drawn
# once, all but invisibly in a corner, so the GPU has compiled its pipelines and
# rasterised its glyphs before the first real frame of play.

static var held: Array = []
static var done := false

var jobs: Array[Callable] = []
var pipeline_frames := 3
const BUDGET_US := 1500
var mats: Array = []
var textures: Array = []
var fonts: Array = []
var glyph_jobs: Array = []      # [font, size, chars]: a few characters at a time
const GLYPHS := "0123456789×+.:/ S A B C CORE Q 贯穿连击负荷第章波裂痕夺壳"
# the sizes each weight is drawn at in the run (a new size costs a few ms the
# first time, for its glyph atlas)
const SIZES := {"Regular": [12, 13, 14, 15, 16, 17, 18, 20, 22], "SemiBold": [13, 14, 15, 16, 18, 20, 22, 24, 26, 30, 120],
	"Medium": [17, 22, 24, 28, 30, 34, 52, 60], "Light": [22, 24, 28, 56]}
# Then, without holding anything up, every character the menus, cards and pages
# can show, at the sizes those use — so no page opens on a rasterising stall.
const PAGE_SIZES := {"Regular": [13, 14, 15, 16, 18, 20, 22], "SemiBold": [14, 15, 16, 18, 20, 22], "Medium": [24, 28, 30, 34], "Light": [22, 24, 28]}
var page_jobs: Array = []      # [font, size, chars]
var page_strings: Array = []
var page_seen := {}
var page_new := ""
var scanning := true
var drawn_pairs := {}
const ALONE := [&"_prepare_material", &"_hold_alone"]


func _ready() -> void:
	z_index = -100
	z_as_relative = false
	if done:
		queue_free()
		return
	# sounds and the first chapter's music
	for n in Sfx.NAMES:
		var p := "res://assets/audio/%s.ogg" % n
		jobs.append(func(): _hold(p))
	for k in Sfx.LAYERS:
		var p2 := "res://assets/audio/ch1_%s.ogg" % k
		jobs.append(func(): _hold(p2))
	# the seized shells' pixel sprites
	for k in Possess.NAMES:
		for suffix in ["", "_spk1", "_spk2"]:
			var sp: String = "res://assets/sprites/shell/" + Possess.NAMES[k] + suffix
			jobs.append(func(): held.append(PixelPart.get_part(sp)))
	# shaders, fonts, generated textures
	for sh in ["floor", "post", "bullet", "blur"]:
		jobs.append(_hold_alone.bind("res://shaders/%s.gdshader" % sh))
	for w in ["Regular", "Light", "SemiBold", "Medium"]:
		jobs.append(func(): held.append(Fonts.get_font(w)))
	jobs.append(func(): held.append(Fx.make_glow_texture()))
	jobs.append(func(): held.append(Fx.make_ring_texture()))
	jobs.append(func(): held.append(Fx.make_dot_texture()))
	jobs.append(func(): held.append(Hud._vignette_texture()))
	jobs.append(_prepare_draw)


func _hold(p: String) -> void:
	if ResourceLoader.exists(p):
		held.append(load(p))


# a heavy load (a shader compiles as it loads): given a frame of its own
func _hold_alone(p: String) -> void:
	_hold(p)


func _process(_dt: float) -> void:
	# a couple of milliseconds of work a frame at most: loading first, then
	# drawing — never both in one frame
	if not jobs.is_empty():
		var t0 := Time.get_ticks_usec()
		var first := true
		while not jobs.is_empty() and Time.get_ticks_usec() - t0 < BUDGET_US:
			var alone: bool = (jobs[0] as Callable).get_method() in ALONE
			if alone and not first:
				break
			first = false
			var j: Callable = jobs.pop_front()
			j.call()
			if alone:
				break
		return
	if not done:
		# the pipelines need a few frames on screen; the glyphs go a slice a frame
		pipeline_frames -= 1
		if pipeline_frames <= 0 and glyph_jobs.is_empty():
			done = true
			_queue_pages()
		queue_redraw()
	elif scanning:
		_scan_pages()
	elif page_jobs.is_empty():
		queue_free()
	else:
		queue_redraw()


func _prepare_draw() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	# one material a frame: making one compiles its shader (2–3 ms), and each
	# brings its own set of pipelines to the next frame's render
	for sh in ["", "add", "floor", "post", "bullet", "blur"]:
		jobs.append(_prepare_material.bind(sh, quad))
	textures = [Fx.make_glow_texture(), Fx.make_ring_texture(), Fx.make_dot_texture(), Hud._vignette_texture()]
	for k in Possess.NAMES:
		textures.append(PixelPart.get_part("res://assets/sprites/shell/" + Possess.NAMES[k]).tex)
	fonts = [Fonts.get_font("Regular"), Fonts.get_font("Light"), Fonts.get_font("SemiBold"), Fonts.get_font("Medium")]
	for w in SIZES:
		var f: Font = Fonts.get_font(w)
		for size in SIZES[w]:
			var step := 3 if size >= 44 else 6
			for k in range(0, GLYPHS.length(), step):
				glyph_jobs.append([f, size, GLYPHS.substr(k, step)])


func _prepare_material(sh: String, quad: QuadMesh) -> void:
	var m: Material = null
	if sh == "add":
		m = CanvasItemMaterial.new()
		(m as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	elif sh != "":
		m = ShaderMaterial.new()
		(m as ShaderMaterial).shader = load("res://shaders/%s.gdshader" % sh)
	var r := ColorRect.new()
	r.material = m
	r.size = Vector2(2, 2)
	r.modulate = Color(1, 1, 1, 0.004)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	mats.append(r)
	# lines, polygons, texture rects, text: each its own pipeline
	var n := Node2D.new()
	n.material = m
	n.modulate = Color(1, 1, 1, 0.004)
	n.draw.connect(_draw_kinds.bind(n))
	add_child(n)
	mats.append(n)
	for filt in [CanvasItem.TEXTURE_FILTER_PARENT_NODE, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS]:
		var mmi := MultiMeshInstance2D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = quad
		mm.instance_count = 2
		mm.set_instance_transform_2d(0, Transform2D(0.0, Vector2(1, 1)))
		mm.set_instance_transform_2d(1, Transform2D(0.0, Vector2(2, 1)))
		mm.set_instance_color(0, Color(1, 1, 1, 0.004))
		mm.set_instance_color(1, Color(1, 1, 1, 0.004))
		mmi.multimesh = mm
		mmi.material = m
		mmi.texture_filter = filt
		mmi.modulate = Color(1, 1, 1, 0.004)
		add_child(mmi)
		mats.append(mmi)


func _draw_kinds(n: Node2D) -> void:
	var c := Color(1, 1, 1, 0.004)
	var tex: Texture2D = textures[0] if not textures.is_empty() else null
	n.draw_rect(Rect2(0, 0, 2, 2), c)
	n.draw_rect(Rect2(0, 0, 2, 2), c, false, 1.0)
	n.draw_line(Vector2(0, 0), Vector2(2, 2), c, 1.0)
	n.draw_line(Vector2(0, 0), Vector2(2, 2), c, 2.0)
	n.draw_polyline(PackedVector2Array([Vector2(0, 0), Vector2(1, 2), Vector2(2, 0)]), c, 2.0)
	n.draw_multiline(PackedVector2Array([Vector2(0, 0), Vector2(2, 2), Vector2(0, 2), Vector2(2, 0)]), c, 1.6)
	n.draw_arc(Vector2(1, 1), 1.0, 0.0, TAU, 8, c, 1.0)
	n.draw_circle(Vector2(1, 1), 1.0, c)
	n.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(1, 2)]), c)
	if tex != null:
		n.draw_texture_rect(tex, Rect2(0, 0, 2, 2), false, c)
		n.draw_texture_rect(Fx.make_dot_texture(), Rect2(0, 0, 2, 2), false, c)
	if not fonts.is_empty():
		n.draw_string(fonts[0], Vector2(0, 2), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)


func _draw() -> void:
	var c := Color(1, 1, 1, 0.004)
	for tx in textures:
		draw_texture_rect(tx, Rect2(0, 0, 2, 2), false, c)
	# every digit and the run's common glyphs at the sizes the HUD uses, then
	# every character the pages can show — a slice each frame, within budget
	var t0 := Time.get_ticks_usec()
	var q: Array = glyph_jobs if not glyph_jobs.is_empty() else (page_jobs if done else [])
	var pair := []
	while not q.is_empty() and Time.get_ticks_usec() - t0 < BUDGET_US:
		# a font size not yet drawn makes its atlas: let that be the frame's only one
		var nxt: Array = q[0]
		if not pair.is_empty() and (nxt[0] != pair[0] or nxt[1] != pair[1]) and not drawn_pairs.has([nxt[0], nxt[1]]):
			break
		pair = [nxt[0], nxt[1]]
		drawn_pairs[pair] = true
		var g: Array = q.pop_front()
		draw_string(g[0], Vector2(0, -200), g[2], HORIZONTAL_ALIGNMENT_LEFT, -1, g[1], c)


func _queue_pages() -> void:
	# the strings first (cheap), then their characters a batch per frame
	_collect(Txt.S, page_strings)
	_collect(Ach.LIST, page_strings)
	_collect(Loadout.GUNS, page_strings)
	_collect(Loadout.STAKES, page_strings)


func _scan_pages() -> void:
	var t0 := Time.get_ticks_usec()
	while not page_strings.is_empty() and Time.get_ticks_usec() - t0 < BUDGET_US:
		var str_: String = page_strings.pop_back()
		for ch in str_:
			if not page_seen.has(ch) and ch != "%" and ch != " ":
				page_seen[ch] = true
				page_new += ch
	if page_strings.is_empty():
		for w in PAGE_SIZES:
			var f: Font = Fonts.get_font(w)
			for size in PAGE_SIZES[w]:
				for i in range(0, page_new.length(), 6):
					page_jobs.append([f, size, page_new.substr(i, 6)])
		page_new = ""
		scanning = false


func _collect(v, into: Array) -> void:
	if v is String:
		into.append(v)
	elif v is Array:
		for x in v:
			_collect(x, into)
	elif v is Dictionary:
		for k in v:
			_collect(v[k], into)
