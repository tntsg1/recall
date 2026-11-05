class_name PixelFx
# Pixel art effects from pixelfx (https://github.com/patch-gg/pixelfx, MIT License,
# (c) 2026 Patch, (c) 2026 Hugo Duprez), baked into sheets by
# tools/pixelfx_export.py; their frame tables are in PixelSheets. Drawn with hard
# pixels: in the fight at a whole-number scale with an HDR colour, so the glow
# softens them into the room's light; on the rooms' screens small, as the
# screen's own low-resolution picture. The full game only (not the demo).

static var _tex := {}


static func tex(name: String) -> Texture2D:
	var t = _tex.get(name)
	if t == null:
		var ct := CanvasTexture.new()
		ct.diffuse_texture = load("res://assets/pixelfx/%s.png" % name)
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_tex[name] = ct
		t = ct
	return t


# How long a one-shot plays, in seconds.
static func length(name: String) -> float:
	var s: Array = PixelSheets.S[name]
	return float(s[3]) / float(s[4])


# The frame at time `t`: a loop wraps, a one-shot past its end gives -1.
static func frame_at(name: String, t: float) -> int:
	var s: Array = PixelSheets.S[name]
	var f := int(t * float(s[4]))
	if s[5]:
		return posmod(f, s[3])
	return f if f < s[3] else -1


# Its frame at `t` with its pivot on `pos`, `scale` screen pixels to one of its own.
static func draw(ci: CanvasItem, name: String, t: float, pos: Vector2, scale: float, c: Color, flip: bool = false) -> void:
	var f := frame_at(name, t)
	if f < 0:
		return
	var s: Array = PixelSheets.S[name]
	var src := Rect2((f % s[2]) * s[0], (f / s[2]) * s[1], s[0], s[1])
	var size := Vector2(s[0], s[1]) * scale
	var o := (pos - Vector2(s[6] if not flip else s[0] - s[6], s[7]) * scale).round()
	if flip:
		ci.draw_texture_rect_region(tex(name), Rect2(o + Vector2(size.x, 0), Vector2(-size.x, size.y)), src, c)
	else:
		ci.draw_texture_rect_region(tex(name), Rect2(o, size), src, c)


# Its frame at `t`, the part of it anything is ever drawn in, filling `r` as far
# as it fits, centred: a screen's picture.
static func draw_fit(ci: CanvasItem, name: String, t: float, r: Rect2, c: Color) -> void:
	var f := frame_at(name, t)
	if f < 0:
		return
	var s: Array = PixelSheets.S[name]
	var box := Rect2(s[8], s[9], s[10], s[11])
	var k := minf(r.size.x / box.size.x, r.size.y / box.size.y)
	# half pixels at least once it is larger than itself; a small glass shrinks it as it must
	if k >= 1.0:
		k = floorf(k * 2.0) / 2.0
	var size := box.size * k
	var src := Rect2(Vector2((f % s[2]) * s[0], (f / s[2]) * s[1]) + box.position, box.size)
	ci.draw_texture_rect_region(tex(name), Rect2((r.get_center() - size / 2.0).round(), size), src, c)
