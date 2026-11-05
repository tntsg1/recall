# Bakes the pixelfx effects the game uses into sprite sheets (assets/pixelfx/)
# and their frame tables (scripts/pixel_sheets.gd).
# pixelfx: https://github.com/patch-gg/pixelfx (MIT), cloned at PIXELFX (default G:/ext/pixelfx).
# Every sheet is forced onto the game's ramp by brightness, so no stray hue survives.
# Usage: python tools/pixelfx_export.py
import json, os, subprocess, sys, shutil
from PIL import Image

PIXELFX = os.environ.get("PIXELFX", "G:/ext/pixelfx")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "pixelfx")
TMP = os.path.join(os.environ.get("TEMP", "."), "neonraid_pixelfx")
# dark to white through the game's red, or through the player's cyan
RAMPS = {
	"red": [(0x16, 0x02, 0x02), (0x44, 0x0c, 0x0c), (0xa8, 0x1e, 0x22), (0xff, 0x44, 0x48), (0xff, 0xc8, 0xc8), (0xff, 0xff, 0xff)],
	"cyan": [(0x02, 0x10, 0x12), (0x08, 0x38, 0x3e), (0x1c, 0x8a, 0x98), (0x2b, 0xc4, 0xd6), (0xb8, 0xf2, 0xf8), (0xff, 0xff, 0xff)],
}
PALETTE = '{"palette":["#100","#411","#a22","#f44","#fcc","#fff"]}'
# name in the game -> pixelfx id (a name ending in _c takes the cyan ramp)
FX = {
	# the fight: rare, large moments
	"implosion": "explosions/implosion",
	"implosion_c": "explosions/implosion",
	"zap": "lightning/zap-hit",
	"spark": "impacts/hit-spark",
	# the rooms' screens
	"coin": "pickups/coin-spin",
	"heart": "pickups/heart-pickup",
	"chest": "pickups/chest-open",
	"scanner": "scifi/scanner",
	"hologram": "scifi/hologram",
	"glitch": "scifi/glitch",
}


def ramp(v: float, RAMP: list):
	v = max(0.0, min(1.0, v)) * (len(RAMP) - 1)
	i = min(int(v), len(RAMP) - 2)
	f = v - i
	a, b = RAMP[i], RAMP[i + 1]
	return tuple(int(a[k] + (b[k] - a[k]) * f) for k in range(3))


# The fight's sheets keep only their light: the dim smudges round a burst read
# as dirt on the game's black.
FIGHT = {"implosion", "implosion_c", "zap", "spark"}


def recolor(img: Image.Image, ramp_name: str, clean: bool = False) -> Image.Image:
	RAMP = RAMPS[ramp_name]
	px = img.load()
	for y in range(img.height):
		for x in range(img.width):
			r, g, b, a = px[x, y]
			if a == 0:
				continue
			lum = max(r, g, b) / 255.0 * 0.7 + (0.299 * r + 0.587 * g + 0.114 * b) / 255.0 * 0.3
			if clean and lum < 0.3:
				px[x, y] = (0, 0, 0, 0)
				continue
			px[x, y] = ramp(lum, RAMP) + (a,)
	return img


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	shutil.rmtree(TMP, ignore_errors=True)
	table = {}
	for name, fid in FX.items():
		if not os.path.exists(os.path.join(TMP, *fid.split("/"))):
			subprocess.run(["node", "tools/render.mjs", fid, "--sheet", "--no-actor", "--opts", PALETTE, "--out", TMP],
				cwd=PIXELFX, check=True, stdout=subprocess.DEVNULL)
		base = os.path.join(TMP, *fid.split("/"), fid.split("/")[1])
		meta = json.load(open(base + ".json"))["meta"]["pixelfx"]
		sheet = recolor(Image.open(base + ".png").convert("RGBA"), "cyan" if name.endswith("_c") else "red", name in FIGHT)
		sheet.save(os.path.join(OUT, name + ".png"), optimize=True)
		fw, fh, cols = meta["frameSize"][0], meta["frameSize"][1], meta["columns"]
		# where anything is ever drawn, over all its frames (a screen shows only that)
		box = None
		for f in range(meta["frames"]):
			b = sheet.crop(((f % cols) * fw, (f // cols) * fh, (f % cols + 1) * fw, (f // cols + 1) * fh)).getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
			if b:
				box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
		box = box or (0, 0, fw, fh)
		table[name] = [fw, fh, cols, meta["frames"], meta["fps"], meta["loop"], meta["pivot"][0], meta["pivot"][1], box[0], box[1], box[2] - box[0], box[3] - box[1]]
		print(name, fid, meta["frames"], "frames")
	lines = ["class_name PixelSheets", "# Made by tools/pixelfx_export.py: do not edit by hand.",
		"# name: [frame w, frame h, columns, frames, fps, loops, pivot x, pivot y, drawn x, y, w, h]", "const S := {"]
	for name, row in table.items():
		lines.append('\t"%s": [%s],' % (name, ", ".join(str(v).lower() for v in row)))
	lines.append("}")
	open(os.path.join(ROOT, "scripts", "pixel_sheets.gd"), "w", newline="\n").write("\n".join(lines) + "\n")


if __name__ == "__main__":
	sys.exit(main())
