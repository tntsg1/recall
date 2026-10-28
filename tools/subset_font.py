"""Build the game fonts: Noto Sans SC (OFL) cut to every character the scripts can show.
Regular (400) for UI, Light (300) for big numerals and titles.
Usage: python tools/subset_font.py"""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
root = Path(__file__).resolve().parents[1]
source = Path('E:/godot/zengliang/build/NotoSansSC-VF.ttf')
chars = set(chr(c) for c in range(0x20, 0x7F))
chars |= set("·—–→←↑↓×÷±%…「」『』（）《》，。！？：；、“”‘’°²³▲△▽◆◇○●■□★☆✦⌁∞≈≥≤▸▹◂◃")
for folder in ['scripts', 'scenes']:
    for f in (root / folder).rglob('*'):
        if f.suffix in ('.gd', '.tscn', '.json'):
            chars |= set(f.read_text(encoding='utf-8'))
chars = {c for c in chars if c.isprintable()}
for weight, name in [(400, 'RecallSC-Regular.ttf'), (300, 'RecallSC-Light.ttf'), (600, 'RecallSC-Semibold.ttf')]:
    opts = subset.Options(); opts.layout_features = ['*']; opts.name_IDs = ['*']; opts.notdef_outline = True
    font = subset.load_font(str(source), opts)
    font = instantiateVariableFont(font, {"wght": weight}, inplace=True)
    sub = subset.Subsetter(opts); sub.populate(text=''.join(sorted(chars))); sub.subset(font)
    out = root / 'assets' / 'fonts' / name
    subset.save_font(font, str(out), opts)
    print(name, len(chars), 'chars', out.stat().st_size, 'bytes')
