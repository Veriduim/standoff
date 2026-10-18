"""The game's sound effects, made from scratch in code (nothing recorded or borrowed - 19 Oct 00:38 list item 2, "Sound").
Writes assets/sfx/<name>.wav (44.1 kHz, 16-bit mono). Run it again after changing a recipe; the seeds are fixed, so the
same recipe makes the same file.
    <comfy python> tools/sfx_make.py [name ...]
"""
import sys
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, lfilter, sosfilt

SR = 44100
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'sfx'
rng = np.random.default_rng(19)


def t(d):
    return np.arange(int(SR * d)) / SR


def decay(d, tau, attack=0.002):
    x = t(d)
    e = np.exp(-x / tau)
    if attack > 0:
        e *= np.clip(x / attack, 0, 1)
    return e


def noise(d):
    return rng.standard_normal(int(SR * d))


def lp(x, fc, order=2):
    return sosfilt(butter(order, fc, 'low', fs=SR, output='sos'), x)


def hp(x, fc, order=2):
    return sosfilt(butter(order, fc, 'high', fs=SR, output='sos'), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)


def sweep(d, f0, f1, curve='exp'):
    """A sine gliding f0 -> f1 over d seconds."""
    x = t(d)
    if curve == 'exp':
        f = f0 * (f1 / f0) ** (x / d)
    else:
        f = f0 + (f1 - f0) * x / d
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def tone(d, f):
    return np.sin(2 * np.pi * f * t(d))


def moving_bp(x, c0, c1, q=1.6, steps=40):
    """Band-pass noise whose centre moves c0 -> c1 (in chunks - a whoosh)."""
    out = np.zeros_like(x)
    n = len(x)
    edges = np.linspace(0, n, steps + 1).astype(int)
    zi = None
    for k in range(steps):
        c = c0 * (c1 / c0) ** (k / max(steps - 1, 1))
        lo, hi = c / q, min(c * q, SR / 2 - 100)
        b, a = butter(2, [lo, hi], 'band', fs=SR)
        seg = x[edges[k]:edges[k + 1]]
        if zi is None or len(zi) != max(len(a), len(b)) - 1:
            zi = np.zeros(max(len(a), len(b)) - 1)
        y, zi = lfilter(b, a, seg, zi=zi)
        out[edges[k]:edges[k + 1]] = y
    return out


def swell(d, peak=0.4):
    """0 -> 1 -> 0, the top at `peak` of the way (a whoosh's shape)."""
    x = t(d) / d
    up = np.clip(x / peak, 0, 1)
    down = np.clip((1 - x) / (1 - peak), 0, 1)
    return np.minimum(up, down) ** 1.6


def at(x, delay, total):
    """x placed `delay` s into a buffer `total` s long."""
    out = np.zeros(int(SR * total))
    i = int(SR * delay)
    n = min(len(x), len(out) - i)
    out[i:i + n] += x[:n]
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def bell(d, f, partials, taus, amps):
    """Struck metal: partials (ratios to f) each with its own decay."""
    out = np.zeros(int(SR * d))
    for r, tau, a in zip(partials, taus, amps):
        out += a * tone(d, f * r) * decay(d, tau, 0.001)
    return out


def knock(d, f0, f1, tau):
    """The mid-range punch a phone speaker can actually play (its bass is gone below ~300 Hz)."""
    return sweep(d, f0, f1) * decay(d, tau)


def finish(x, peak, drive=0.0, cut=140):
    x = hp(x, cut, order=2) if cut else x   # (a phone can't play below ~300 Hz: no headroom spent on it)
    if drive > 0:
        x = np.tanh(x * (1 + drive)) / np.tanh(1 + drive)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


# --- the recipes -----------------------------------------------------------------------------------------------------
def hit_light():
    d = 0.2
    body = sweep(d, 420, 170) * decay(d, 0.045)
    snap = bp(noise(d), 1000, 4500) * decay(d, 0.012)
    click = bp(noise(d), 3000, 7000) * decay(d, 0.003)
    return finish(mix(body * 1.0, knock(d, 700, 300, 0.025) * 0.9, snap * 0.55, click * 0.3), 0.8, drive=1.2)


def hit_heavy():
    d = 0.4
    body = sweep(d, 500, 180) * decay(d, 0.09)
    thump = lp(noise(d), 1200) * decay(d, 0.05)
    crack = bp(noise(d), 1800, 6000) * decay(d, 0.012)
    return finish(mix(body * 1.0, knock(d, 560, 220, 0.05) * 1.3, thump * 0.7, crack * 0.4), 0.95, drive=2.0)


def hit_counter():
    d = 0.6
    heavy = np.pad(hit_heavy(), (0, int(SR * d) - int(SR * 0.4)))
    ring = bell(d, 1180, [1, 1.51, 2.32, 3.1], [0.22, 0.15, 0.09, 0.05], [1, 0.6, 0.4, 0.25]) * 0.3
    return finish(mix(heavy, ring), 0.95)


def edge():
    d = 0.5
    chime = bell(d, 2093, [1, 1.5, 2.01], [0.16, 0.1, 0.06], [1, 0.5, 0.3])
    shimmer = bp(noise(d), 5000, 9000) * decay(d, 0.04) * 0.12
    return finish(mix(chime, shimmer), 0.45)


def block():
    d = 0.18
    knock = tone(d, 310) * decay(d, 0.035)
    wood = bp(noise(d), 500, 1900) * decay(d, 0.022)
    return finish(mix(knock * 0.8, wood), 0.7, drive=0.6)


def push():
    d = 0.4
    b = np.pad(block(), (0, int(SR * d) - int(SR * 0.18)))
    gust = moving_bp(noise(d), 500, 1600) * swell(d, 0.25) * 0.5
    return finish(mix(b, gust), 0.75)


def parry():
    d = 0.7
    ring = bell(d, 1568, [1, 1.47, 2.09, 2.76, 3.9], [0.3, 0.2, 0.14, 0.09, 0.05], [1, 0.7, 0.5, 0.35, 0.2])
    scrape = bp(noise(d), 3000, 9000) * decay(d, 0.03) * 0.5
    return finish(mix(ring, scrape), 0.75)


def clash():
    d = 0.5
    ring = bell(d, 720, [1, 1.58, 2.51, 3.3], [0.16, 0.11, 0.07, 0.05], [1, 0.8, 0.5, 0.3])
    hitn = bp(noise(d), 800, 4000) * decay(d, 0.02)
    return finish(mix(ring, hitn * 0.8), 0.8, drive=0.5)


def grab():
    d = 0.35
    cloth = bp(noise(d), 1500, 5000) * decay(d, 0.03)
    thud = at(sweep(0.25, 140, 60) * decay(0.25, 0.06) + knock(0.25, 480, 220, 0.04) * 1.2, 0.06, d)
    return finish(mix(cloth * 0.6, thud), 0.8, drive=0.8)


def fan_throw():
    d = 0.32
    w = moving_bp(noise(d), 700, 2600, q=1.5) * swell(d, 0.3)
    flutter = 0.65 + 0.35 * np.sin(2 * np.pi * 34 * t(d))   # (the fan spinning)
    return finish(w * flutter, 0.6)


def catch():
    d = 0.16
    snap = bp(noise(d), 1800, 6000) * decay(d, 0.004)
    snap2 = at(bp(noise(0.05), 1800, 6000) * decay(0.05, 0.003), 0.035, d)
    tick = tone(d, 1760) * decay(d, 0.03)
    return finish(mix(snap, snap2 * 0.7, tick * 0.8), 0.5)


def recall():
    d = 0.3
    w = moving_bp(noise(d), 2400, 900, q=1.6) * swell(d, 0.75)
    ping = at(tone(0.12, 1320) * decay(0.12, 0.04), 0.22, d) * 0.4
    return finish(mix(w, ping), 0.5)


def sweep_big():
    d = 0.6
    w = moving_bp(noise(d), 300, 1700, q=1.4) * swell(d, 0.35)
    air = lp(noise(d), 500) * swell(d, 0.3) * 0.5
    return finish(mix(w, air), 0.75)


def gust():
    d = 0.7
    base = lp(noise(d), 900, order=3)
    swells = 0.55 + 0.45 * np.sin(2 * np.pi * 5.5 * t(d)) ** 2
    hiss = moving_bp(noise(d), 1500, 4000, q=1.4) * 0.35
    return finish((base * swells + hiss) * swell(d, 0.3), 0.6)


def blink():
    d = 0.2
    zip_ = sweep(d, 500, 2600) * decay(d, 0.06, 0.004)
    air = bp(noise(d), 3000, 8000) * swell(d, 0.4) * 0.2
    return finish(mix(zip_, air), 0.45)


def down():
    d = 0.35
    thud = sweep(d, 95, 38) * decay(d, 0.09)
    dust = lp(noise(d), 1200) * decay(d, 0.06)
    return finish(mix(thud, knock(d, 420, 200, 0.06) * 1.3, dust * 0.6), 0.8, drive=1.0)


def bounce():
    d = 0.22
    thud = sweep(d, 130, 60) * decay(d, 0.05)
    dust = lp(noise(d), 1600) * decay(d, 0.03)
    return finish(mix(thud, knock(d, 460, 230, 0.035) * 1.2, dust * 0.5), 0.65, drive=0.8)


def wall():
    d = 0.45
    thud = sweep(d, 110, 40) * decay(d, 0.1)
    rattle = bp(noise(d), 300, 2500) * decay(d, 0.09) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 28 * t(d))))
    return finish(mix(thud, knock(d, 500, 210, 0.07) * 1.3, rattle * 0.5), 0.9, drive=1.6)


def ko():
    d = 1.4
    boom = sweep(d, 85, 28) * decay(d, 0.45)
    rumble = lp(noise(d), 500) * decay(d, 0.35)
    crack = bp(noise(d), 1500, 6000) * decay(d, 0.02)
    ring = bell(d, 392, [1, 2.0, 2.98], [0.6, 0.4, 0.25], [1, 0.4, 0.2]) * 0.25
    return finish(mix(boom, knock(d, 520, 180, 0.14) * 1.4, rumble * 0.6, crack * 0.4, ring), 0.95, drive=1.4)


def burst():
    d = 0.8
    rise = moving_bp(noise(0.2), 250, 3500, q=1.5) * np.linspace(0, 1, int(SR * 0.2)) ** 2
    boom = at(sweep(0.6, 120, 35) * decay(0.6, 0.18) + knock(0.6, 540, 200, 0.09) * 1.3
              + lp(noise(0.6), 1500) * decay(0.6, 0.12) * 0.6, 0.18, d)
    return finish(mix(rise * 0.7, boom), 0.95, drive=1.0)


def super_():
    d = 1.0
    notes = [523.25, 659.25, 783.99, 1046.5]   # (a rising chord, each note a little later)
    out = np.zeros(int(SR * d))
    for k, f in enumerate(notes):
        dd = d - k * 0.06
        vib = np.sin(2 * np.pi * f * t(dd) + 0.004 * f * np.sin(2 * np.pi * 6 * t(dd)) / 6)
        out += at(vib * decay(dd, 0.35, 0.01) * 0.3, k * 0.06, d)
    boom = sweep(0.5, 90, 40) * decay(0.5, 0.15) + knock(0.5, 480, 200, 0.07)
    air = moving_bp(noise(d), 400, 6000, q=1.6) * swell(d, 0.25) * 0.4
    return finish(mix(out, boom * 0.8, air), 0.9)


def sad():
    d = 0.5
    a = tone(0.22, 392) * decay(0.22, 0.12, 0.01)
    b = at(sweep(0.28, 330, 262) * decay(0.28, 0.15, 0.01), 0.2, d)
    soft = lambda x: lp(np.tanh(x * 2.5), 2500)
    return finish(mix(soft(a), soft(b)), 0.4)


def beat():
    d = 0.09
    wood = tone(d, 1050) * decay(d, 0.018) + bp(noise(d), 1500, 4000) * decay(d, 0.006) * 0.4
    return finish(wood, 0.32)


def onbeat():
    d = 0.45
    note = lambda f, dd: (tone(dd, f) + 0.25 * tone(dd, f * 4)) * decay(dd, 0.09, 0.002)
    return finish(mix(note(880, 0.3), at(note(1318.5, 0.35), 0.09, d)), 0.5)


def snap():
    d = 0.14
    s = bp(noise(d), 2000, 7000) * decay(d, 0.01)
    blip = sweep(d, 1800, 900) * decay(d, 0.03)
    return finish(mix(s, blip * 0.6), 0.5)


def countered():
    d = 0.7
    return finish(mix(parry() * 1.0, np.pad(push(), (0, int(SR * 0.3))) * 0.6), 0.85)


def time_up():
    d = 1.6
    return finish(bell(d, 392, [1, 2.76, 5.4, 8.9], [0.8, 0.45, 0.25, 0.12], [1, 0.6, 0.35, 0.2]), 0.7)


def swing():
    d = 0.18
    w = moving_bp(noise(d), 600, 1800, q=1.5) * swell(d, 0.45)
    return finish(w, 0.35)


def land():
    d = 0.12
    return finish(lp(noise(d), 900) * decay(d, 0.025) + knock(d, 340, 190, 0.03) * 1.2, 0.35)


def ui_click():
    d = 0.05
    return finish(tone(d, 1400) * decay(d, 0.008) + bp(noise(d), 2500, 6000) * decay(d, 0.002) * 0.3, 0.3)


def ui_turn():
    d = 0.35
    note = lambda f, dd: (tone(dd, f) + 0.2 * tone(dd, f * 3)) * decay(dd, 0.1, 0.003)
    return finish(mix(note(659.25, 0.2), at(note(987.77, 0.25), 0.08, d)), 0.4)


def ui_tick():
    d = 0.07
    return finish(tone(d, 1600) * decay(d, 0.012) + bp(noise(d), 2000, 6000) * decay(d, 0.004) * 0.3, 0.35)


RECIPES = {
    'hit_light': hit_light, 'hit_heavy': hit_heavy, 'hit_counter': hit_counter, 'edge': edge, 'block': block,
    'push': push, 'parry': parry, 'clash': clash, 'grab': grab, 'fan_throw': fan_throw, 'catch': catch,
    'recall': recall, 'sweep': sweep_big, 'gust': gust, 'blink': blink, 'down': down, 'bounce': bounce, 'wall': wall,
    'ko': ko, 'burst': burst, 'super': super_, 'sad': sad, 'beat': beat, 'onbeat': onbeat, 'snap': snap,
    'countered': countered, 'time': time_up, 'swing': swing, 'land': land, 'ui_click': ui_click, 'ui_turn': ui_turn,
    'ui_tick': ui_tick,
}


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype('<i2').tobytes()
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


if __name__ == '__main__':
    names = sys.argv[1:] or list(RECIPES)
    for n in names:
        rng = np.random.default_rng(sum(map(ord, n)) * 7919)   # (each sound its own fixed noise)
        x = RECIPES[n]()
        write(n, x)
        print(f'{n:12s} {len(x) / SR:.2f}s')
