"""被附身敌人的霓虹像素贴图 → assets/sprites/shell/*.png + *.json（RotSprite 32 个角度）

被夺的壳换成《霓虹行者》的青色霓虹像素：深青机身、亮青描边、白色核心，
异体是从机身长出来的青白晶刺（分短 / 长两档，生长时先短后长）。
所有部件朝 +x 画，轴心在机身中心，运行时角度 = 朝向。
运行：G:/audio_library/venv/Scripts/python.exe tools/pixel/build_shells.py
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import pix  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites", "shell")
N = 32


def inside(pts, x, y):
    c = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            c = not c
        j = i
    return c


def mask(pts, w, h):
    m = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            m[y, x] = inside(pts, x + 0.5, y + 0.5)
    return m


def paint(img, m, col):
    img[m] = pix.rgba(col)


def edge(m):
    """mask 的内侧一圈"""
    e = np.zeros_like(m)
    p = np.pad(m, 1)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        e |= m & ~p[1 + dy:1 + dy + m.shape[0], 1 + dx:1 + dx + m.shape[1]]
    return e


def disc(w, h, cx, cy, r):
    yy, xx = np.mgrid[0:h, 0:w]
    return (xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 <= r * r


def body(pts, w, h, core, core_r):
    """深青机身 → 中青内层 → 亮青描边 → 白色核心"""
    img = np.zeros((h, w, 4), np.uint8)
    m = mask(pts, w, h)
    paint(img, m, "c0")
    # 内层：离边越远越亮
    inner = m & ~edge(m)
    inner2 = inner & ~edge(inner)
    paint(img, inner2, "c1")
    paint(img, edge(m), "c2")
    c = disc(w, h, core[0], core[1], core_r + 1.0)
    paint(img, c & m, "c3")
    paint(img, disc(w, h, core[0], core[1], core_r), "w0")
    return img


def spikes(w, h, tris, light=True):
    img = np.zeros((h, w, 4), np.uint8)
    for t in tris:
        m = mask(t, w, h)
        paint(img, m, "c2")
        if light:
            paint(img, m & ~edge(m), "c3")
    return img


def save(name, img, pivot):
    pix.atlas(img, pivot, N, name, OUT)


# ---- 追击者：前尖后宽的钻头三角，中心偏后一颗白核；异体 = 后掠双翼晶刺 + 钻尖延长
W, H = 31, 25
cx, cy = 13, 12
chaser = [(cx + 13, cy), (cx - 8, cy - 9), (cx - 4, cy), (cx - 8, cy + 9)]
save("chaser", body(chaser, W, H, (cx - 2, cy), 1.6), (cx, cy))


def chaser_spk(k):
    return spikes(W, H, [
        [(cx - 5, cy - 7), (cx - 5 - 6 * k, cy - 7 - 4 * k), (cx - 1, cy - 5)],
        [(cx - 5, cy + 7), (cx - 5 - 6 * k, cy + 7 + 4 * k), (cx - 1, cy + 5)],
        [(cx + 11, cy - 1.5), (cx + 13 + 4 * k, cy), (cx + 11, cy + 1.5)],
        [(cx + 2, cy - 4), (cx + 4 + 2 * k, cy - 6 - 3 * k), (cx + 5, cy - 3)],
        [(cx + 2, cy + 4), (cx + 4 + 2 * k, cy + 6 + 3 * k), (cx + 5, cy + 3)],
    ])


save("chaser_spk1", chaser_spk(0.5), (cx, cy))
save("chaser_spk2", chaser_spk(1.0), (cx, cy))

# ---- 吸附者：五边形，白核居中；异体 = 五个角各长一根向外的晶刺（触手由运行时画）
W, H = 31, 31
cx, cy = 15, 15
pent = [(cx + 9 * math.cos(a), cy + 9 * math.sin(a)) for a in [i * 2 * math.pi / 5 for i in range(5)]]
save("leech", body(pent, W, H, (cx, cy), 2.2), (cx, cy))


def leech_spk(k):
    tris = []
    for i in range(5):
        a = i * 2 * math.pi / 5
        b = a + 0.32
        c = a - 0.32
        tip = 9 + 6 * k
        tris.append([(cx + 7 * math.cos(b), cy + 7 * math.sin(b)), (cx + tip * math.cos(a), cy + tip * math.sin(a)), (cx + 7 * math.cos(c), cy + 7 * math.sin(c))])
    return spikes(W, H, tris)


save("leech_spk1", leech_spk(0.45), (cx, cy))
save("leech_spk2", leech_spk(1.0), (cx, cy))
print("shell sprites ->", os.path.abspath(OUT))
