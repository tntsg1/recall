"""归弹 RECALL audio: every sound is synthesized here (numpy only, fixed seeds).
Usage: G:/audio_library/venv/Scripts/python.exe tools/make_audio.py [only_prefix]
"""
from pathlib import Path
import subprocess
import sys
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'audio'
WORK = ROOT / 'tools' / 'audio_work'
OUT.mkdir(parents=True, exist_ok=True)
WORK.mkdir(parents=True, exist_ok=True)
SR = 44100
ONLY = sys.argv[1] if len(sys.argv) > 1 else ''
rng = np.random.default_rng(7)


def tv(d):
    return np.arange(int(SR * d)) / SR


def env(t, a, d, curve=1.0):
    e = np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-np.maximum(0.0, t - a) / d * curve)
    return e


def lp(x, cut):
    # one-pole low-pass, cut may be an array
    cut = np.broadcast_to(np.asarray(cut, dtype=float), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * cut / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def hp(x, cut):
    return x - lp(x, cut)


def noise(n):
    return rng.standard_normal(n)


def sweep(f0, f1, d, curve=2.0):
    t = tv(d)
    k = (t / d) ** curve
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def fade(x, a=0.002, r=0.02):
    n = len(x)
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return x * e


def stereo(x, width=0.0, delay_ms=0.0):
    d = int(SR * delay_ms / 1000.0)
    l = x.copy()
    r = np.concatenate([np.zeros(d), x[:len(x) - d]]) if d > 0 else x.copy()
    return np.stack([l * (1 - width * 0.5) + r * width * 0.5, r * (1 - width * 0.5) + l * width * 0.5], axis=1)


def room(x, mix=0.18, size=0.045, fb=0.45):
    # tiny feedback-delay ambience
    y = x.copy()
    for k, ms in enumerate([size, size * 1.37, size * 1.71]):
        d = int(SR * ms)
        buf = np.zeros(len(x) + d * 8)
        buf[:len(x)] = x
        for i in range(1, 8):
            buf[d * i: d * i + len(x)] += x * (fb ** i)
        y = y + buf[:len(x)] * mix / 3.0
    return y


def write(name, a, peak=0.8, tail=0.0):
    if ONLY and not name.startswith(ONLY):
        return
    if tail > 0:
        a = np.concatenate([a, np.zeros((int(SR * tail),) + a.shape[1:])])
    if a.ndim == 1:
        a = np.stack([a, a], axis=1)
    a = a - a.mean(axis=0)
    m = np.max(np.abs(a))
    if m > 0:
        a = a * (peak / m)
    pcm = (np.clip(a, -1, 1) * 32767).astype('<i2')
    f = WORK / (name + '.wav')
    with wave.open(str(f), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(f), '-c:a', 'libvorbis', '-q:a', '6', str(OUT / (name + '.ogg'))], check=True)
    print('wrote', name, '%.2fs' % (len(a) / SR))


def shot():
    d = 0.16
    t = tv(d)
    click = hp(noise(len(t)), 2500) * env(t, 0.0005, 0.006)
    body = sweep(1900, 420, d, 0.5) * env(t, 0.001, 0.025) * 0.6
    thump = np.sin(2 * np.pi * 110 * t) * env(t, 0.001, 0.03) * 0.7
    air = lp(noise(len(t)), 5000) * env(t, 0.002, 0.04) * 0.25
    x = click * 0.8 + body + thump + air
    return stereo(room(fade(x), 0.12), 0.3, 6)


def embed():
    d = 0.4
    t = tv(d)
    knock = lp(noise(len(t)), 1800) * env(t, 0.0005, 0.012) * 1.2
    thud = np.sin(2 * np.pi * 170 * t) * env(t, 0.001, 0.04)
    # metallic twang: inharmonic partials that ring briefly
    ring = sum(np.sin(2 * np.pi * f * t + i) * env(t, 0.001, dd) * g for i, (f, dd, g) in enumerate([(2350, 0.09, 0.35), (3410, 0.06, 0.22), (5120, 0.04, 0.12)]))
    trem = 1 + 0.35 * np.sin(2 * np.pi * 38 * t)
    x = knock + thud * 0.7 + ring * trem
    return stereo(room(fade(x), 0.2), 0.4, 9)


def hit():
    d = 0.18
    t = tv(d)
    x = np.sin(2 * np.pi * 880 * t) * env(t, 0.0005, 0.03) + hp(noise(len(t)), 3000) * env(t, 0.0005, 0.008) * 0.6
    x += np.sin(2 * np.pi * 220 * t) * env(t, 0.001, 0.025) * 0.6
    return stereo(fade(x), 0.2, 4)


def pierce():
    # a bright glassy strike; the game raises its pitch rung by rung
    d = 0.5
    t = tv(d)
    f = 660.0
    x = np.sin(2 * np.pi * f * t) * env(t, 0.0008, 0.12)
    x += np.sin(2 * np.pi * f * 2.0 * t) * env(t, 0.0008, 0.06) * 0.5
    x += np.sin(2 * np.pi * f * 3.01 * t) * env(t, 0.0008, 0.03) * 0.25
    x += hp(noise(len(t)), 4000) * env(t, 0.0003, 0.006) * 0.8
    x += np.sin(2 * np.pi * 110 * t) * env(t, 0.001, 0.04) * 0.6
    return stereo(room(fade(x), 0.25, 0.06), 0.5, 11)


def focus():
    d = 1.1
    t = tv(d)
    n = noise(len(t))
    cut = 6000 * np.exp(-t * 3.2) + 200
    whoosh = lp(n, cut) * env(t, 0.03, 0.35)
    sub = sweep(95, 48, d, 0.6) * env(t, 0.02, 0.5) * 0.9
    tone = np.sin(2 * np.pi * 330 * t) * env(t, 0.15, 0.4) * 0.12
    x = whoosh * 0.7 + sub + tone
    return stereo(room(fade(x, 0.005, 0.2), 0.3, 0.08), 0.6, 14)


def release():
    d = 1.4
    t = tv(d)
    pre = 0.12
    n = noise(len(t))
    rise = np.clip(t / pre, 0, 1) ** 3 * (t < pre)
    swell = lp(n, 800 + 9000 * np.clip(t / pre, 0, 1) ** 2) * rise * 0.8
    tt = np.maximum(0.0, t - pre)
    after = (t >= pre).astype(float)
    snap = hp(n, 1500) * np.exp(-tt / 0.02) * after * 1.0
    boom = np.sin(2 * np.pi * (52 + 40 * np.exp(-tt / 0.05)) * tt) * np.exp(-tt / 0.45) * after * 1.3
    shimmer = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.35) for f in (1320, 1980, 2640)) * after * 0.08
    x = swell + snap + boom + shimmer
    return stereo(room(fade(x, 0.002, 0.2), 0.3, 0.07), 0.7, 13)


def home():
    d = 0.16
    t = tv(d)
    x = np.sin(2 * np.pi * 1760 * t) * env(t, 0.0005, 0.025) * 0.6
    x += hp(noise(len(t)), 5000) * env(t, 0.0003, 0.004)
    t2 = np.maximum(0, t - 0.018)
    x += hp(noise(len(t)), 4000) * np.exp(-t2 / 0.003) * (t >= 0.018) * 0.6
    return stereo(fade(x), 0.3, 3)


def die():
    d = 0.9
    t = tv(d)
    x = np.zeros(len(t))
    # glassy grains scattered over the first 120 ms
    for i in range(26):
        st = rng.uniform(0, 0.12)
        f = rng.uniform(1800, 6200)
        g = np.sin(2 * np.pi * f * (t - st)) * np.exp(-np.maximum(0, t - st) / rng.uniform(0.01, 0.05)) * (t >= st)
        x += g * rng.uniform(0.2, 0.6)
    x += hp(noise(len(t)), 2000) * env(t, 0.0005, 0.04) * 1.2
    drop = sweep(300, 60, 0.5, 0.5) * env(tv(0.5), 0.001, 0.15)
    x[:len(drop)] += drop * 1.1
    return stereo(room(fade(x), 0.3, 0.07), 0.7, 12)


def spawn():
    d = 0.8
    t = tv(d)
    x = sweep(400, 1400, d, 1.5) * env(t, 0.35, 0.12) * 0.25
    x += sum(np.sin(2 * np.pi * f * t) * np.clip((t - s) / 0.02, 0, 1) * np.exp(-np.maximum(0, t - s) / 0.08) * (t >= s) * 0.2 for s, f in [(0.08, 990), (0.16, 1320), (0.24, 1760), (0.32, 2640)])
    return stereo(room(fade(x), 0.3, 0.05), 0.6, 10)


def empty():
    d = 0.12
    t = tv(d)
    x = lp(noise(len(t)), 900) * env(t, 0.0005, 0.01) + np.sin(2 * np.pi * 140 * t) * env(t, 0.001, 0.02) * 0.6
    return stereo(fade(x), 0.1)


def expire():
    d = 0.5
    t = tv(d)
    x = sweep(700, 240, d, 0.7) * env(t, 0.005, 0.12) * 0.5
    return stereo(room(fade(x), 0.3), 0.4, 8)


def lit():
    d = 0.2
    t = tv(d)
    x = np.sin(2 * np.pi * 2093 * t) * env(t, 0.001, 0.03) + np.sin(2 * np.pi * 3136 * t) * env(t, 0.001, 0.015) * 0.4
    return stereo(room(fade(x), 0.4, 0.05), 0.6, 9)


def dash():
    d = 0.3
    t = tv(d)
    n = noise(len(t))
    x = lp(hp(n, 400), 3000 + 4000 * np.sin(np.pi * t / d)) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 2
    return stereo(fade(x), 0.8, 16)


def arrive():
    d = 0.2
    t = tv(d)
    x = np.sin(2 * np.pi * 990 * t) * env(t, 0.001, 0.04)
    return stereo(fade(x), 0.3)


def music():
    # 32 s seamless loop at 90 bpm: a low pulse, a slow drone and sparse bells.
    bpm = 90.0
    beat = 60.0 / bpm
    bars = 12
    L = int(SR * beat * 4 * bars)
    t = np.arange(L) / SR
    dur = L / SR
    x = np.zeros(L)
    drone_f = 55.0
    drone = np.sin(2 * np.pi * drone_f * t) * 0.5 + np.sin(2 * np.pi * drone_f * 1.5 * t + 0.3) * 0.18
    lfo = 0.75 + 0.25 * np.sin(2 * np.pi * t / dur)
    x += drone * lfo * 0.55
    # pulse on every beat, softer off-beats
    nb = int(round(dur / beat))
    for i in range(nb):
        st = i * beat
        k = (t - st)
        m = (k >= 0) & (k < 0.5)
        amp = 0.9 if i % 4 == 0 else 0.45
        x[m] += np.sin(2 * np.pi * (48 + 30 * np.exp(-k[m] / 0.03)) * k[m]) * np.exp(-k[m] / 0.16) * amp
        if i % 2 == 1:
            mm = (k >= beat / 2) & (k < beat / 2 + 0.05)
            kk = k[mm] - beat / 2
            x[mm] += rng.standard_normal(mm.sum()) * np.exp(-kk / 0.008) * 0.05
    # bells: pentatonic minor around A, sparse, wrapping tails
    notes = [69, 72, 74, 76, 79, 81]
    r2 = np.random.default_rng(11)
    for i in range(nb):
        if r2.random() < 0.28:
            n = notes[r2.integers(len(notes))]
            f = 440.0 * 2 ** ((n - 69) / 12.0)
            st = i * beat + (beat / 2 if r2.random() < 0.3 else 0)
            k = (t - st) % dur
            x += (np.sin(2 * np.pi * f * k) + 0.3 * np.sin(2 * np.pi * f * 2 * k)) * np.exp(-k / 0.9) * 0.08
    x = lp(x, 9000)
    a = stereo(x, 0.6, 18)
    return a


def hurt():
    d = 0.7
    t = tv(d)
    crack = hp(noise(len(t)), 1200) * env(t, 0.0005, 0.03) * 1.2
    thud = np.sin(2 * np.pi * (70 + 60 * np.exp(-t / 0.04)) * t) * env(t, 0.001, 0.18) * 1.2
    glass = sum(np.sin(2 * np.pi * f * t) * env(t, 0.001, 0.12) for f in (1210, 1730, 2650)) * 0.12
    ring = np.sin(2 * np.pi * 440 * t) * np.sin(2 * np.pi * 7 * t) * env(t, 0.02, 0.25) * 0.15
    return stereo(room(fade(crack + thud + glass + ring), 0.25, 0.06), 0.5, 10)


def title():
    d = 1.4
    t = tv(d)
    n = noise(len(t))
    sweepn = lp(n, 300 + 5000 * np.sin(np.pi * np.clip(t / 0.6, 0, 1))) * np.sin(np.pi * np.clip(t / 0.6, 0, 1)) ** 2 * 0.5
    tone = (np.sin(2 * np.pi * 220 * t) + 0.5 * np.sin(2 * np.pi * 330 * t)) * env(t, 0.25, 0.5) * 0.25
    tick = np.zeros(len(t))
    st = int(SR * 0.22)
    k = t[st:] - t[st]
    tick[st:] = np.sin(2 * np.pi * 1760 * k) * np.exp(-k / 0.03) * 0.3
    return stereo(room(fade(sweepn + tone + tick, 0.01, 0.3), 0.3, 0.08), 0.7, 15)


def stamp():
    d = 1.2
    t = tv(d)
    hit = lp(noise(len(t)), 2500) * env(t, 0.0005, 0.02) * 1.4
    boom = np.sin(2 * np.pi * (48 + 50 * np.exp(-t / 0.03)) * t) * env(t, 0.001, 0.35) * 1.3
    bell = sum(np.sin(2 * np.pi * f * t) * env(t, 0.002, dd) * g for f, dd, g in [(523.25, 0.6, 0.25), (784, 0.45, 0.18), (1046.5, 0.3, 0.12)])
    return stereo(room(fade(hit + boom + bell, 0.001, 0.3), 0.3, 0.07), 0.6, 12)


def shield():
    d = 0.35
    t = tv(d)
    ping = sum(np.sin(2 * np.pi * f * t) * env(t, 0.0005, dd) * g for f, dd, g in [(1480, 0.08, 0.5), (2960, 0.05, 0.3), (4100, 0.03, 0.2)])
    click = hp(noise(len(t)), 3000) * env(t, 0.0003, 0.005)
    return stereo(room(fade(ping + click), 0.2, 0.04), 0.5, 7)


def windup():
    d = 0.85
    t = tv(d)
    x = sweep(180, 900, d, 2.2) * (t / d) ** 1.5 * 0.5
    x += lp(noise(len(t)), 600 + 3000 * (t / d) ** 2) * (t / d) ** 2 * 0.3
    trem = 1 + 0.4 * np.sin(2 * np.pi * (6 + 24 * t / d) * t)
    return stereo(fade(x * trem, 0.01, 0.02), 0.4, 6)


def dash_e():
    d = 0.5
    t = tv(d)
    n = noise(len(t))
    x = lp(hp(n, 300), 2500 + 6000 * np.exp(-t / 0.1)) * env(t, 0.005, 0.15)
    x += np.sin(2 * np.pi * (90 - 40 * t / d) * t) * env(t, 0.005, 0.12) * 0.6
    return stereo(fade(x), 0.7, 14)


def slam():
    d = 0.7
    t = tv(d)
    x = lp(noise(len(t)), 1500) * env(t, 0.0005, 0.04) * 1.3
    x += np.sin(2 * np.pi * (40 + 70 * np.exp(-t / 0.02)) * t) * env(t, 0.001, 0.22) * 1.2
    x += sum(np.sin(2 * np.pi * f * t) * env(t, 0.001, 0.08) for f in (620, 930)) * 0.15
    return stereo(room(fade(x), 0.25, 0.06), 0.5, 9)


def tick():
    d = 0.1
    t = tv(d)
    x = np.sin(2 * np.pi * 2400 * t) * env(t, 0.0005, 0.012) + hp(noise(len(t)), 5000) * env(t, 0.0003, 0.003) * 0.5
    return stereo(fade(x), 0.2)


def card():
    d = 0.5
    t = tv(d)
    n = noise(len(t))
    x = lp(hp(n, 800), 2000 + 7000 * np.sin(np.pi * np.clip(t / 0.25, 0, 1))) * np.sin(np.pi * np.clip(t / 0.25, 0, 1)) ** 2 * 0.5
    for k, st in enumerate((0.06, 0.15, 0.24)):
        kk = np.maximum(0, t - st)
        x += np.sin(2 * np.pi * (880 * 2 ** (k * 4 / 12)) * kk) * np.exp(-kk / 0.06) * (t >= st) * 0.2
    return stereo(room(fade(x), 0.3, 0.05), 0.7, 12)


def pick():
    d = 1.0
    t = tv(d)
    x = sum(np.sin(2 * np.pi * f * t) * env(t, 0.003, 0.5) * g for f, g in [(523.25, 0.3), (659.25, 0.25), (783.99, 0.22), (1046.5, 0.15)])
    x += hp(noise(len(t)), 4000) * env(t, 0.0005, 0.01) * 0.6
    x += np.sin(2 * np.pi * (60 + 40 * np.exp(-t / 0.03)) * t) * env(t, 0.001, 0.2) * 0.7
    return stereo(room(fade(x, 0.002, 0.3), 0.3, 0.07), 0.6, 10)


def split():
    d = 0.18
    t = tv(d)
    x = np.sin(2 * np.pi * 2600 * t) * env(t, 0.0005, 0.02) + np.sin(2 * np.pi * 3900 * t) * env(t, 0.0005, 0.012) * 0.5
    return stereo(fade(x), 0.5, 5)


def horn():
    d = 1.8
    t = tv(d)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
    x = np.zeros(len(t))
    for f, g in [(98.0, 1.0), (123.5, 0.8), (146.8, 0.6)]:
        ph = 2 * np.pi * np.cumsum(f * vib) / SR
        x += (np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)) * g
    x = lp(x, 1800) * env(t, 0.12, 0.9)
    return stereo(room(fade(x, 0.05, 0.4), 0.35, 0.09), 0.7, 18)


def brake():
    d = 1.3
    t = tv(d)
    f = 2400 - 900 * t / d + 60 * np.sin(2 * np.pi * 13 * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.35 + hp(noise(len(t)), 2500) * 0.3
    x *= np.sin(np.pi * np.clip(t / d, 0, 1)) ** 0.6
    return stereo(fade(x, 0.02, 0.2), 0.6, 9)


def core():
    d = 0.45
    t = tv(d)
    x = lp(noise(len(t)), 900 + 2500 * t / d) * env(t, 0.01, 0.12) * 0.7
    x += np.sin(2 * np.pi * (300 + 500 * t / d) * t) * env(t, 0.01, 0.1) * 0.3
    clank = np.zeros(len(t))
    st = int(SR * 0.3)
    k = t[st:] - t[st]
    clank[st:] = (np.sin(2 * np.pi * 820 * k) + np.sin(2 * np.pi * 1310 * k)) * np.exp(-k / 0.04) * 0.4
    return stereo(room(fade(x + clank), 0.2, 0.05), 0.5, 8)


def armor():
    d = 1.5
    t = tv(d)
    x = lp(noise(len(t)), 3000) * env(t, 0.0005, 0.08) * 1.5
    x += np.sin(2 * np.pi * (36 + 60 * np.exp(-t / 0.03)) * t) * env(t, 0.001, 0.4) * 1.4
    for i in range(14):
        st = rng.uniform(0.0, 0.5)
        f = rng.uniform(400, 2400)
        x += np.sin(2 * np.pi * f * (t - st)) * np.exp(-np.maximum(0, t - st) / rng.uniform(0.04, 0.15)) * (t >= st) * 0.25
    return stereo(room(fade(x, 0.001, 0.4), 0.35, 0.08), 0.8, 14)


def boss_die():
    d = 4.0
    t = tv(d)
    x = lp(noise(len(t)), 2000 * np.exp(-t / 0.6) + 120) * env(t, 0.001, 0.9) * 1.6
    x += np.sin(2 * np.pi * (28 + 50 * np.exp(-t / 0.08)) * t) * env(t, 0.002, 1.4) * 1.6
    x += sum(np.sin(2 * np.pi * f * t) * env(t, 0.2, 1.6) * 0.12 for f in (220, 330, 440, 660))
    return stereo(room(fade(x, 0.001, 1.0), 0.4, 0.11), 0.9, 20)


# ---------------------------------------------------------------- chapter 1 stems
# Four loops of identical length, tempo and key (A minor pentatonic, 90 bpm,
# 12 bars). The game plays them together and only moves their volumes.
BPM = 90.0
BEAT = 60.0 / BPM
BARS = 12
LOOP = int(SR * BEAT * 4 * BARS)
PENTA = [57, 60, 62, 64, 67, 69, 72, 74, 76, 79, 81]   # A minor pentatonic
DRONE = 55.0
BOSS_LINE = [57, 57, 64, 57, 60, 57, 62, 64]
BOSS_SHIFT = -24


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def _loop_render(fn):
    # render three loops and keep the middle one, so tails wrap seamlessly
    t = np.arange(LOOP * 3) / SR
    x = fn(t)
    return x[LOOP:LOOP * 2]


def stem_base():
    def f(t):
        dur = LOOP / SR
        x = np.sin(2 * np.pi * DRONE * t) * 0.5 + np.sin(2 * np.pi * DRONE * 1.5 * t + 0.3) * 0.18
        x *= 0.75 + 0.25 * np.sin(2 * np.pi * t / dur)
        r2 = np.random.default_rng(11)
        nb = int(round(t[-1] / BEAT)) + 1
        for i in range(nb):
            if r2.random() < 0.28:
                fr = midi(PENTA[5 + r2.integers(6)])
                st = i * BEAT + (BEAT / 2 if r2.random() < 0.3 else 0)
                k = t - st
                m = k >= 0
                x[m] += (np.sin(2 * np.pi * fr * k[m]) + 0.3 * np.sin(2 * np.pi * fr * 2 * k[m])) * np.exp(-k[m] / 0.9) * 0.08
        return lp(x, 9000)
    return stereo(_loop_render(f), 0.6, 18)


def stem_pulse():
    def f(t):
        x = np.zeros(len(t))
        nb = int(round(t[-1] / BEAT)) + 1
        for i in range(nb):
            st = i * BEAT
            k = t - st
            m = (k >= 0) & (k < 0.5)
            amp = 0.9 if i % 4 == 0 else 0.5
            x[m] += np.sin(2 * np.pi * (48 + 30 * np.exp(-k[m] / 0.03)) * k[m]) * np.exp(-k[m] / 0.16) * amp
            mm = (k >= BEAT / 2) & (k < BEAT / 2 + 0.06)
            kk = k[mm] - BEAT / 2
            x[mm] += rng.standard_normal(mm.sum()) * np.exp(-kk / 0.01) * (0.09 if i % 2 else 0.05)
            if i % 4 == 2:
                m2 = (k >= 0) & (k < 0.25)
                x[m2] += rng.standard_normal(m2.sum()) * np.exp(-k[m2] / 0.05) * 0.12
        return x
    return stereo(_loop_render(f), 0.3, 6)


def stem_glass():
    def f(t):
        x = np.zeros(len(t))
        step = BEAT / 4
        r3 = np.random.default_rng(23)
        pattern = [0, 2, 4, 2, 5, 4, 2, 1, 0, 2, 4, 6, 5, 4, 2, 4]
        ns = int(round(t[-1] / step)) + 1
        for i in range(ns):
            shift = [0, 1, -1, 2][(i // 16) % 4]
            fr = midi(PENTA[3 + (pattern[i % 16] + shift) % 8])
            st = i * step
            k = t - st
            m = (k >= 0) & (k < 1.2)
            g = (0.10 if i % 4 == 0 else 0.06) * (0.8 + 0.4 * r3.random())
            x[m] += (np.sin(2 * np.pi * fr * k[m]) + 0.45 * np.sin(2 * np.pi * fr * 3.01 * k[m]) * np.exp(-k[m] / 0.05)) * np.exp(-k[m] / 0.35) * g
        # a soft dotted-eighth echo makes it shimmer
        d = int(SR * BEAT * 0.75)
        y = x.copy()
        for j in range(1, 4):
            y[d * j:] += x[:-d * j] * (0.38 ** j)
        return y
    return stereo(_loop_render(f), 0.9, 22)


def stem_boss():
    def f(t):
        x = np.zeros(len(t))
        step = BEAT / 2
        line = BOSS_LINE
        ns = int(round(t[-1] / step)) + 1
        for i in range(ns):
            fr = midi(line[i % 8] + BOSS_SHIFT + (0 if (i // 32) % 2 == 0 else -2))
            st = i * step
            k = t - st
            m = (k >= 0) & (k < step)
            ph = 2 * np.pi * fr * k[m]
            saw = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.33 * np.sin(3 * ph) + 0.25 * np.sin(4 * ph)
            x[m] += saw * np.exp(-k[m] / 0.18) * 0.32
        # a slow rising swell every two bars
        per = BEAT * 8
        ph2 = (t % per) / per
        x += np.sin(2 * np.pi * DRONE * 2 * t) * np.sin(2 * np.pi * 7 * t) * ph2 ** 3 * 0.12
        return x
    return stereo(_loop_render(f), 0.4, 9)


def crack():
    d = 0.9
    t = tv(d)
    x = np.zeros(len(t))
    for i in range(22):
        st = rng.uniform(0, 0.08)
        f = rng.uniform(2200, 7000)
        x += np.sin(2 * np.pi * f * (t - st)) * np.exp(-np.maximum(0, t - st) / rng.uniform(0.02, 0.08)) * (t >= st) * rng.uniform(0.2, 0.5)
    x += hp(noise(len(t)), 2500) * env(t, 0.0005, 0.03) * 1.2
    x += np.sin(2 * np.pi * (60 + 80 * np.exp(-t / 0.03)) * t) * env(t, 0.001, 0.25) * 1.1
    return stereo(room(fade(x), 0.3, 0.07), 0.7, 11)


def mend():
    d = 1.0
    t = tv(d)
    x = np.zeros(len(t))
    for k, n in enumerate([69, 72, 76, 81]):
        st = k * 0.07
        kk = np.maximum(0, t - st)
        fr = midi(n)
        x += (np.sin(2 * np.pi * fr * kk) + 0.3 * np.sin(2 * np.pi * fr * 2 * kk)) * np.exp(-kk / 0.4) * (t >= st) * 0.25
    return stereo(room(fade(x, 0.002, 0.3), 0.35, 0.08), 0.7, 13)


def reroll():
    d = 0.6
    t = tv(d)
    win = np.sin(np.pi * np.clip(t / 0.35, 0, 1))
    x = lp(hp(noise(len(t)), 900), 3000 + 6000 * win) * win ** 2 * 0.5
    for k in range(6):
        st = 0.04 + k * 0.045
        kk = np.maximum(0, t - st)
        x += np.sin(2 * np.pi * (1400 + k * 180) * kk) * np.exp(-kk / 0.02) * (t >= st) * 0.18
    return stereo(room(fade(x), 0.25, 0.05), 0.7, 9)


def relic():
    d = 1.6
    t = tv(d)
    x = sum(np.sin(2 * np.pi * midi(n) * t) * env(t, 0.004, 0.8) * g for n, g in [(69, 0.28), (76, 0.22), (81, 0.2), (88, 0.12)])
    x += sum(np.sin(2 * np.pi * f * t + np.sin(2 * np.pi * 5 * t)) * env(t, 0.2, 0.6) * 0.04 for f in (2637, 3520))
    x += np.sin(2 * np.pi * (55 + 40 * np.exp(-t / 0.04)) * t) * env(t, 0.001, 0.3) * 0.6
    return stereo(room(fade(x, 0.002, 0.4), 0.4, 0.09), 0.8, 16)


def item():
    d = 0.7
    t = tv(d)
    x = sum(np.sin(2 * np.pi * midi(n) * t) * env(t, 0.003, 0.3) * 0.25 for n in (72, 79))
    x += hp(noise(len(t)), 5000) * env(t, 0.0005, 0.01) * 0.4
    return stereo(room(fade(x), 0.3, 0.06), 0.6, 10)


def over():
    d = 4.0
    t = tv(d)
    x = np.zeros(len(t))
    for k, n in enumerate([81, 76, 72, 69, 64, 57]):
        st = k * 0.28
        kk = np.maximum(0, t - st)
        fr = midi(n)
        x += (np.sin(2 * np.pi * fr * kk) + 0.4 * np.sin(2 * np.pi * fr * 3.01 * kk) * np.exp(-kk / 0.1)) * np.exp(-kk / 0.9) * (t >= st) * 0.2
    x += np.sin(2 * np.pi * (36 + 30 * np.exp(-t / 0.1)) * t) * env(t, 0.002, 1.5) * 0.9
    return stereo(room(fade(x, 0.002, 0.8), 0.45, 0.11), 0.8, 20)


def chapter():
    d = 3.0
    t = tv(d)
    gong = sum(np.sin(2 * np.pi * f * t) * env(t, 0.004, dd) * g for f, dd, g in [(55, 1.8, 0.8), (110.6, 1.2, 0.35), (164.5, 0.9, 0.2), (231, 0.6, 0.12)])
    shimmer = sum(np.sin(2 * np.pi * midi(n) * t) * np.clip((t - 0.6) / 1.2, 0, 1) * env(t, 1.2, 0.9) * 0.05 for n in (81, 84, 88, 93))
    return stereo(room(fade(gong + shimmer, 0.003, 0.6), 0.45, 0.1), 0.8, 18)


def cross():
    d = 0.6
    t = tv(d)
    x = sum(np.sin(2 * np.pi * midi(n) * t) * env(t, 0.0008, 0.2) * 0.3 for n in (81, 88, 93))
    x += hp(noise(len(t)), 4000) * env(t, 0.0003, 0.006)
    return stereo(room(fade(x), 0.3, 0.05), 0.7, 8)


def crit():
    d = 0.4
    t = tv(d)
    x = np.sin(2 * np.pi * 1760 * t) * env(t, 0.0008, 0.12) * 0.5 + np.sin(2 * np.pi * 2637 * t) * env(t, 0.0008, 0.08) * 0.3
    return stereo(room(fade(x), 0.3, 0.05), 0.6, 7)



def _chapter(bpm, bars, penta, drone, line, shift, fn):
    # run a stem builder with another chapter's tempo, key and bass line
    global BPM, BEAT, LOOP, PENTA, DRONE, BOSS_LINE, BOSS_SHIFT
    saved = (BPM, BEAT, LOOP, PENTA, DRONE, BOSS_LINE, BOSS_SHIFT)
    BPM = bpm
    BEAT = 60.0 / bpm
    LOOP = int(SR * BEAT * 4 * bars)
    PENTA, DRONE, BOSS_LINE, BOSS_SHIFT = penta, drone, line, shift
    try:
        return fn()
    finally:
        BPM, BEAT, LOOP, PENTA, DRONE, BOSS_LINE, BOSS_SHIFT = saved


# chapter 2, the Hall of Mirrors: E minor pentatonic, 96 bpm, 12 bars = 30 s
CH2 = (96.0, 12, [52, 55, 57, 59, 62, 64, 67, 69, 71, 74, 76], 41.2, [52, 52, 59, 52, 55, 52, 57, 59], -12)


def ch2(fn):
    return lambda: _chapter(*CH2, fn)


# chapter 3, the Maw: D minor pentatonic, 84 bpm, 12 bars = 240/7 s; the drone is
# picked so it and its fifth both complete whole cycles in one loop
CH3 = (84.0, 12, [50, 53, 55, 57, 60, 62, 65, 67, 69, 72, 74], 1258 * 7 / 240, [50, 50, 57, 50, 53, 50, 55, 57], -12)


def ch3(fn):
    return lambda: _chapter(*CH3, fn)


# chapter 4, the Beat: G minor pentatonic, 100 bpm, 12 bars = 28.8 s
CH4 = (100.0, 12, [55, 58, 60, 62, 65, 67, 70, 72, 74, 77, 79], 1412 / 28.8, [55, 55, 62, 55, 58, 55, 60, 62], -24)


def ch4(fn):
    return lambda: _chapter(*CH4, fn)


# chapter 5, Zero: C minor pentatonic, 92 bpm, 12 bars; the drone fits whole cycles
CH5 = (92.0, 12, [48, 51, 53, 55, 58, 60, 63, 65, 67, 70, 72], 2048 / (60.0 / 92.0 * 48), [48, 48, 55, 48, 51, 48, 53, 55], -12)


def ch5(fn):
    return lambda: _chapter(*CH5, fn)


SOUNDS = {
    'shot': shot, 'embed': embed, 'hit': hit, 'pierce': pierce, 'focus': focus, 'release': release,
    'home': home, 'die': die, 'spawn': spawn, 'empty': empty, 'expire': expire, 'lit': lit, 'dash': dash,
    'arrive': arrive, 'music': music, 'hurt': hurt, 'title': title, 'stamp': stamp, 'shield': shield,
    'windup': windup, 'dash_e': dash_e, 'slam': slam, 'tick': tick, 'card': card, 'pick': pick, 'split': split,
    'horn': horn, 'brake': brake, 'core': core, 'armor': armor, 'boss_die': boss_die,
    'ch1_base': stem_base, 'ch1_pulse': stem_pulse, 'ch1_glass': stem_glass, 'ch1_boss': stem_boss,
    'crack': crack, 'mend': mend, 'reroll': reroll, 'relic': relic, 'item': item, 'over': over,
    'chapter': chapter, 'cross': cross, 'crit': crit,
    'ch2_base': ch2(stem_base), 'ch2_pulse': ch2(stem_pulse), 'ch2_glass': ch2(stem_glass), 'ch2_boss': ch2(stem_boss),
    'ch3_base': ch3(stem_base), 'ch3_pulse': ch3(stem_pulse), 'ch3_glass': ch3(stem_glass), 'ch3_boss': ch3(stem_boss),
    'ch4_base': ch4(stem_base), 'ch4_pulse': ch4(stem_pulse), 'ch4_glass': ch4(stem_glass), 'ch4_boss': ch4(stem_boss),
    'ch5_base': ch5(stem_base), 'ch5_pulse': ch5(stem_pulse), 'ch5_glass': ch5(stem_glass), 'ch5_boss': ch5(stem_boss),
}

if __name__ == '__main__':
    for k, f in SOUNDS.items():
        if ONLY and not k.startswith(ONLY):
            continue
        write(k, f(), peak=0.55 if k == 'music' or k[:2] == 'ch' and k[3] == '_' else 0.8)
