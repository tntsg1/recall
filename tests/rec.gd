extends Node
# Band-free video capture for the HDR build. The root buffer is linear half
# float; Godot's movie writer squeezes it through 8-bit linear and the darks
# posterize. Here a non-HDR SubViewport redraws the root texture through a
# float-precision sRGB encode and the bytes are piped straight into ffmpeg.

var sub: SubViewport
var pipe: FileAccess
var pid := -1
var frames := 0


func start(out_path: String, fps: int = 60) -> void:
	var size := get_tree().root.size
	sub = SubViewport.new()
	sub.size = size
	sub.use_hdr_2d = false
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var tr := TextureRect.new()
	tr.texture = get_tree().root.get_texture()
	tr.size = Vector2(size)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
vec3 enc(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
void fragment() {
	COLOR = vec4(enc(texture(TEXTURE, UV).rgb), 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	tr.material = mat
	sub.add_child(tr)
	var args := ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", "%dx%d" % [size.x, size.y], "-r", str(fps), "-i", "-",
		"-c:v", "libx264", "-preset", "medium", "-crf", "16", "-pix_fmt", "yuv420p", "-movflags", "+faststart", ProjectSettings.globalize_path(out_path)]
	var info := OS.execute_with_pipe("ffmpeg", args, false)
	pipe = info["stdio"]
	pid = info["pid"]
	print("REC -> ", out_path, " ", size)


# Call once per frame after the frame was drawn.
func grab() -> void:
	if pipe == null:
		return
	var img := sub.get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	pipe.store_buffer(img.get_data())
	frames += 1


func finish() -> void:
	if pipe == null:
		return
	pipe.close()
	pipe = null
	while OS.is_process_running(pid):
		OS.delay_msec(50)
	print("REC done, ", frames, " frames")
