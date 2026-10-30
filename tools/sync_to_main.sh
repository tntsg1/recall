#!/usr/bin/env bash
# Copy the tested dev copy (E:/godot/cshi_dev) over the copy the user plays
# from (E:/godot/cshi) and export a fresh exe there. Run only after the
# headless checks pass, so the user's F5 never meets half-made code.
set -e
SRC=/e/godot/cshi_dev
DST=/e/godot/cshi
for d in scripts shaders assets scenes tests tools design addons; do
	rm -rf "$DST/$d"
	cp -r "$SRC/$d" "$DST/$d"
done
cp "$SRC/project.godot" "$SRC/README.md" "$SRC/export_presets.cfg" "$SRC/icon.svg" "$SRC/default_bus_layout.tres" "$DST/"
G=/e/godot/godot47/Godot_v4.7-stable_win64_console.exe
"$G" --headless --path "$DST" --import > /dev/null 2>&1 || true
"$G" --headless --path "$DST" --export-release "Windows Desktop" build/RECALL.exe 2>&1 | grep -E "SCRIPT ERROR" || true
ls -la "$DST/build/RECALL.exe"
