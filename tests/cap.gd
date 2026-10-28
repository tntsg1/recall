extends RefCounted
# Screenshot helper. With hdr_2d the root buffer is linear half-float; going
# through 8-bit linear first crushes the darks into visible bands, so convert
# each half straight to an sRGB byte through a lookup table.

static var lut := PackedByteArray()


static func _half(h: int) -> float:
	var e := (h >> 10) & 31
	var m := h & 1023
	var v: float
	if e == 0:
		v = m / 1024.0 / 16384.0
	elif e == 31:
		v = 65504.0
	else:
		v = (1.0 + m / 1024.0) * pow(2.0, e - 15)
	return -v if h & 0x8000 else v


static func _build() -> void:
	lut.resize(65536)
	for h in 65536:
		var c := clampf(_half(h), 0.0, 1.0)
		var s := c * 12.92 if c < 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055
		lut[h] = int(clampf(s, 0.0, 1.0) * 255.0 + 0.5)


static func to_srgb8(img: Image) -> Image:
	if not ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
		return img
	if img.get_format() != Image.FORMAT_RGBAH:
		img.convert(Image.FORMAT_RGBAH)
	if lut.is_empty():
		_build()
	var src := img.get_data()
	var n := src.size() / 8
	var dst := PackedByteArray()
	dst.resize(n * 4)
	var o := 0
	var d := 0
	for i in n:
		dst[d] = lut[src.decode_u16(o)]
		dst[d + 1] = lut[src.decode_u16(o + 2)]
		dst[d + 2] = lut[src.decode_u16(o + 4)]
		dst[d + 3] = 255
		o += 8
		d += 4
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, dst)


static func save(root: Viewport, path: String) -> void:
	var t := Time.get_ticks_msec()
	var img := to_srgb8(root.get_texture().get_image())
	img.save_png(path)
	print("SHOT ", path, " (", Time.get_ticks_msec() - t, " ms)")
