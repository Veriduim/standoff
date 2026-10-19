"""The game's sound effects, made from scratch in code - nothing recorded or borrowed (19 Oct 00:38 list item 2,
"Sound"; second pass 03:07 "They arent bad but they arent amazing what we have").
Writes assets/sfx/<name>.wav (44.1 kHz, 16-bit STEREO) - and <name>_2.wav, <name>_3.wav for the ones heard most, so the
same hit doesn't sound stamped. Second pass: every sound layered (a crack, a body, a smack, a tail), a short room
reverb in stereo, phone-speaker friendly (nothing much under 140 Hz - a mid 'knock' carries the weight), her fans with
their own sounds (a slash for a fan cut, a wood-and-metal clack for a block on the fans).
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


# --- building blocks --------------------------------------------------------------------------------------------------
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
    return sosfilt(butter(order, [lo, min(hi, SR / 2 - 200)], 'band', fs=SR, output='sos'), x)


def sweep(d, f0, f1):
    x = t(d)
    f = f0 * (f1 / f0) ** (x / d)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def tone(d, f):
    return np.sin(2 * np.pi * f * t(d))


def moving_bp(x, c0, c1, q=1.6, steps=48):
    out = np.zeros_like(x)
    edges = np.linspace(0, len(x), steps + 1).astype(int)
    zi = None
    for k in range(steps):
        c = c0 * (c1 / c0) ** (k / max(steps - 1, 1))
        b, a = butter(2, [c / q, min(c * q, SR / 2 - 200)], 'band', fs=SR)
        if zi is None:
            zi = np.zeros(max(len(a), len(b)) - 1)
        out[edges[k]:edges[k + 1]], zi = lfilter(b, a, x[edges[k]:edges[k + 1]], zi=zi)
    return out


def swell(d, peak=0.4):
    x = t(d) / d
    return np.minimum(np.clip(x / peak, 0, 1), np.clip((1 - x) / (1 - peak), 0, 1)) ** 1.6


def at(x, delay, total):
    out = np.zeros(int(SR * total))
    i = int(SR * delay)
    n = min(len(x), len(out) - i)
    out[i:i + n] += x[:n]
    return out


def mix(*parts):
    out = np.zeros(max(len(p) for p in parts))
    for p in parts:
        out[:len(p)] += p
    return out


def bell(d, f, partials, taus, amps):
    out = np.zeros(int(SR * d))
    for r, tau, a in zip(partials, taus, amps):
        out += a * tone(d, f * r) * decay(d, tau, 0.001)
    return out


def knock(d, f0, f1, tau):
    """The mid-range punch a phone speaker can actually play."""
    return sweep(d, f0, f1) * decay(d, tau)


def drive(x, amount):
    return np.tanh(x * (1 + amount)) / np.tanh(1 + amount) if amount > 0 else x


# --- the room: a small stereo reverb (Schroeder - four combs, two allpasses a side) -----------------------------------
def _comb(x, d, g):
    a = np.zeros(d + 1)
    a[0], a[d] = 1.0, -g
    return lfilter([1.0], a, x)


def _allpass(x, d, g):
    b = np.zeros(d + 1)
    b[0], b[d] = -g, 1.0
    a = np.zeros(d + 1)
    a[0], a[d] = 1.0, -g
    return lfilter(b, a, x)


def room(x, wet, size=1.0, tail=0.35, g=0.72):
    """x (mono, dry) in a room: (left, right). wet 0 = dry; size scales the room; the tail is added room after it."""
    pad = np.concatenate([x, np.zeros(int(SR * tail))])
    chans = []
    for side, off in ((0, 0), (1, 31)):
        y = np.zeros_like(pad)
        for ms in (29.7, 37.1, 41.1, 43.7):
            y += _comb(pad, int(SR * ms * size / 1000) + off, g)
        y = _allpass(y, int(SR * 0.005) + off, 0.7)
        y = _allpass(y, int(SR * 0.0017) + off // 3, 0.7)
        y = lp(hp(y, 300), 5200)
        chans.append(pad + wet * y / 4.0)
    return chans


def out(x, peak, wet=0.12, size=1.0, tail=0.35, g=0.72, cut=140, width=0.0):
    """Finish a dry sound: cut the lows a phone can't play, the room, a touch of width, the level."""
    x = hp(x, cut) if cut else x
    left, right = room(x, wet, size, tail, g) if wet > 0 else (x.copy(), x.copy())
    if width > 0:   # (a few samples' offset on one side - a little wider, still fine summed to one speaker)
        d = int(SR * 0.0004 * width)
        right = np.concatenate([np.zeros(d), right[:-d]]) if d > 0 else right
    m = max(np.max(np.abs(left)), np.max(np.abs(right))) + 1e-9
    left, right = left / m * peak, right / m * peak
    fade = min(len(left), int(SR * 0.01))
    for ch in (left, right):
        ch[-fade:] *= np.linspace(1, 0, fade)
    return np.stack([left, right], axis=1)


# --- the recipes (v = variant 0, 1, 2 - small changes so repeats don't sound stamped) ---------------------------------
def hit_light(v=0):
    d = 0.22
    f0 = [250, 280, 230][v]
    crack = bp(noise(d), 2800, 9000) * decay(d, 0.0025)
    body = (sweep(d, f0 * 1.6, f0 * 0.6) + 0.45 * sweep(d, f0 * 3.2, f0 * 1.2)) * decay(d, 0.045)
    smack = bp(noise(d), 700, 2600) * decay(d, 0.016)
    tail = lp(noise(d), 1400) * decay(d, 0.06) * 0.35
    return out(drive(mix(crack * 0.5, body, smack * 0.7, tail), 1.4), 0.8, wet=0.10, size=0.7, tail=0.25, g=0.62)


def hit_heavy(v=0):
    d = 0.42
    f0 = [170, 150][v]
    crack = bp(noise(d), 1800, 7000) * decay(d, 0.006)
    body = (sweep(d, f0 * 3.0, f0) + 0.5 * sweep(d, f0 * 6.0, f0 * 2.0)) * decay(d, 0.08)
    punch = knock(d, 560, 210, 0.05) * 1.2
    tail = lp(noise(d), 1600) * decay(d, 0.09) * 0.6
    return out(drive(mix(crack * 0.6, body, punch, tail), 2.2), 0.95, wet=0.16, size=0.9, tail=0.35, g=0.68)


def hit_counter():
    d = 0.6
    heavy = hp(lp(noise(0.02), 6000), 1500) * decay(0.02, 0.004)
    body = (sweep(d, 520, 160) + 0.5 * sweep(d, 1040, 320)) * decay(d, 0.08)
    ring = bell(d, 1240, [1, 1.51, 2.32, 3.1], [0.24, 0.16, 0.1, 0.06], [1, 0.6, 0.4, 0.25]) * 0.35
    return out(drive(mix(heavy, body, knock(d, 600, 220, 0.06), ring), 1.6), 0.95, wet=0.22, size=1.0, tail=0.5)


def slash(v=0):
    """Her fan cutting (a fan hit, 03:07): a fast descending swish with a thin steel ring, a soft thump under it."""
    d = 0.3
    hi, lo = [(7000, 2400), (6200, 2100), (7600, 2700)][v]
    swish = moving_bp(noise(d), hi, lo, q=1.4) * swell(d, 0.18)
    ring = bell(d, [3100, 2900, 3300][v], [1, 1.5, 2.1], [0.06, 0.04, 0.03], [1, 0.5, 0.3]) * 0.35
    thump = knock(d, 380, 150, 0.03) * 0.7
    return out(drive(mix(swish * 1.2, ring, thump), 0.8), 0.8, wet=0.14, size=0.8, tail=0.3, width=2.0)


def edge():
    d = 0.6
    chime = bell(d, 2093, [1, 1.5, 2.01, 3.0], [0.2, 0.12, 0.07, 0.05], [1, 0.5, 0.3, 0.15])
    shimmer = bp(noise(d), 5000, 9500) * decay(d, 0.05) * 0.1
    return out(mix(chime, shimmer), 0.45, wet=0.3, size=1.2, tail=0.6, width=3.0)


def fan_block(v=0):
    """A hit caught on her fans (03:07): a wooden 'tok' of the ribs, a steel clink, a low thud."""
    d = 0.22
    tok = (bp(noise(d), 900, 2600) * decay(d, 0.012) + tone(d, [520, 560][v]) * decay(d, 0.02) * 0.6)
    clink = bell(d, [2250, 2400][v], [1, 1.53], [0.04, 0.025], [1, 0.5]) * 0.4
    thud = knock(d, 400, 230, 0.03) * 0.8
    return out(drive(mix(tok, clink, thud), 0.6), 0.72, wet=0.08, size=0.6, tail=0.2, g=0.6)


def push():
    d = 0.45
    gust = moving_bp(noise(d), 400, 1900, q=1.5) * swell(d, 0.25) * 0.8
    return out(mix(fan_block(0)[:, 0], gust), 0.78, wet=0.16, tail=0.35)


def parry():
    d = 0.8
    ring = bell(d, 1568, [1, 1.47, 2.09, 2.76, 3.9], [0.34, 0.22, 0.15, 0.1, 0.06], [1, 0.7, 0.5, 0.35, 0.2])
    scrape = moving_bp(noise(0.12), 8000, 3000, q=1.5) * swell(0.12, 0.1) * 0.6
    return out(mix(ring, scrape), 0.78, wet=0.28, size=1.2, tail=0.6, width=3.0)


def clash():
    d = 0.6
    ring = bell(d, 640, [1, 1.58, 2.47, 3.48], [0.2, 0.13, 0.08, 0.05], [1, 0.8, 0.5, 0.3])
    hitn = bp(noise(d), 900, 4500) * decay(d, 0.02)
    return out(drive(mix(ring, hitn * 0.8), 0.6), 0.82, wet=0.22, size=1.0, tail=0.45)


def grab():
    d = 0.38
    cloth = bp(noise(d), 1500, 5500) * decay(d, 0.03)
    thud = at(sweep(0.25, 420, 190) * decay(0.25, 0.05) + knock(0.25, 520, 240, 0.04), 0.06, d)
    return out(drive(mix(cloth * 0.6, thud), 0.9), 0.82, wet=0.12, tail=0.3)


def fan_throw(v=0):
    d = 0.36
    lo, hi = [(700, 2700), (800, 3000)][v]
    w = moving_bp(noise(d), lo, hi, q=1.5) * swell(d, 0.3)
    flutter = 0.6 + 0.4 * np.sin(2 * np.pi * [34, 39][v] * t(d))   # (the fan spinning)
    return out(w * flutter, 0.62, wet=0.12, tail=0.3, width=4.0)


def catch():
    d = 0.18
    snap = bp(noise(d), 1800, 6500) * decay(d, 0.004)
    snap2 = at(bp(noise(0.05), 1800, 6500) * decay(0.05, 0.003), 0.035, d)
    tick = tone(d, 1760) * decay(d, 0.03)
    return out(mix(snap, snap2 * 0.7, tick * 0.8), 0.5, wet=0.08, tail=0.2)


def recall():
    d = 0.34
    w = moving_bp(noise(d), 2600, 900, q=1.6) * swell(d, 0.75)
    ping = at(bell(0.15, 1320, [1, 2.0], [0.05, 0.03], [1, 0.4]), 0.25, d) * 0.4
    return out(mix(w, ping), 0.52, wet=0.16, tail=0.35, width=3.0)


def sweep_big():
    d = 0.65
    w = moving_bp(noise(d), 300, 1900, q=1.4) * swell(d, 0.35)
    air = lp(noise(d), 600) * swell(d, 0.3) * 0.4
    return out(mix(w, air), 0.75, wet=0.2, size=1.1, tail=0.45, width=4.0)


def gust():
    d = 0.8
    base = lp(noise(d), 1000, order=3)
    swells = 0.55 + 0.45 * np.sin(2 * np.pi * 5.0 * t(d)) ** 2
    hiss = moving_bp(noise(d), 1500, 4200, q=1.4) * 0.35
    return out((base * swells + hiss) * swell(d, 0.3), 0.65, wet=0.25, size=1.2, tail=0.5, width=4.0)


def blink():
    d = 0.22
    zip_ = sweep(d, 500, 2800) * decay(d, 0.06, 0.004)
    air = bp(noise(d), 3000, 8000) * swell(d, 0.4) * 0.2
    return out(mix(zip_, air), 0.45, wet=0.15, tail=0.3, width=3.0)


def down():
    d = 0.4
    thud = (sweep(d, 440, 190) + knock(d, 520, 240, 0.06)) * decay(d, 0.09)
    dust = lp(noise(d), 1300) * decay(d, 0.07)
    return out(drive(mix(thud, dust * 0.6), 1.0), 0.8, wet=0.12, tail=0.3)


def bounce():
    d = 0.25
    thud = (sweep(d, 340, 140) + knock(d, 460, 230, 0.035)) * decay(d, 0.05)
    dust = lp(noise(d), 1700) * decay(d, 0.03)
    return out(drive(mix(thud, dust * 0.5), 0.8), 0.65, wet=0.1, tail=0.25)


def wall():
    d = 0.5
    thud = (sweep(d, 440, 180) + knock(d, 560, 240, 0.07)) * decay(d, 0.1)
    rattle = bp(noise(d), 300, 2600) * decay(d, 0.09) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 28 * t(d))))
    return out(drive(mix(thud, rattle * 0.5), 1.6), 0.9, wet=0.18, size=1.0, tail=0.4)


def ko():
    d = 1.4
    boom = (sweep(d, 360, 130) * decay(d, 0.45) + knock(d, 560, 220, 0.14) * 1.4)
    rumble = lp(noise(d), 600) * decay(d, 0.35)
    crack = bp(noise(d), 1500, 6000) * decay(d, 0.02)
    ring = bell(d, 392, [1, 2.0, 2.98], [0.6, 0.4, 0.25], [1, 0.4, 0.2]) * 0.25
    return out(drive(mix(boom, rumble * 0.6, crack * 0.4, ring), 1.4), 0.95, wet=0.3, size=1.4, tail=1.0, g=0.78,
               width=4.0)


def burst():
    d = 0.9
    rise = moving_bp(noise(0.2), 250, 3800, q=1.5) * np.linspace(0, 1, int(SR * 0.2)) ** 2
    boom = at(sweep(0.6, 300, 90) * decay(0.6, 0.18) + knock(0.6, 540, 200, 0.09) * 1.3
              + lp(noise(0.6), 1600) * decay(0.6, 0.12) * 0.6, 0.18, d)
    return out(drive(mix(rise * 0.7, boom), 1.0), 0.95, wet=0.25, size=1.2, tail=0.6, width=4.0)


def super_():
    """A super starting: a bright rising chord over a swell of air, a low hit under it."""
    d = 1.1
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    chord = np.zeros(int(SR * d))
    for k, f in enumerate(notes):
        dd = d - k * 0.05
        vib = np.sin(2 * np.pi * f * t(dd) + 0.004 * f * np.sin(2 * np.pi * 6 * t(dd)) / 6)
        chord += at(vib * decay(dd, 0.38, 0.01) * 0.28, k * 0.05, d)
    boom = sweep(0.5, 300, 100) * decay(0.5, 0.15) + knock(0.5, 480, 200, 0.07)
    air = moving_bp(noise(d), 400, 6500, q=1.6) * swell(d, 0.25) * 0.45
    return out(mix(chord, boom * 0.8, air), 0.9, wet=0.32, size=1.3, tail=0.8, width=5.0)


def sad():
    d = 0.55
    a = tone(0.22, 392) * decay(0.22, 0.12, 0.01)
    b = at(sweep(0.3, 330, 262) * decay(0.3, 0.15, 0.01), 0.2, d)
    soft = lambda x: lp(np.tanh(x * 2.5), 2500)
    return out(mix(soft(a), soft(b)), 0.4, wet=0.2, tail=0.4)


def beat():
    d = 0.1
    wood = tone(d, 1050) * decay(d, 0.018) + bp(noise(d), 1500, 4200) * decay(d, 0.006) * 0.4
    return out(wood, 0.32, wet=0.06, tail=0.15)


def onbeat():
    d = 0.5
    note = lambda f, dd: (tone(dd, f) + 0.25 * tone(dd, f * 4)) * decay(dd, 0.1, 0.002)
    return out(mix(note(880, 0.3), at(note(1318.5, 0.35), 0.09, d)), 0.5, wet=0.18, tail=0.4, width=3.0)


def snap():
    d = 0.15
    s = bp(noise(d), 2000, 7500) * decay(d, 0.01)
    blip = sweep(d, 1900, 900) * decay(d, 0.03)
    return out(mix(s, blip * 0.6), 0.5, wet=0.08, tail=0.2)


def countered():
    d = 0.8
    ring = bell(d, 1760, [1, 1.47, 2.09, 2.76], [0.3, 0.2, 0.14, 0.09], [1, 0.7, 0.5, 0.35])
    gust_ = moving_bp(noise(0.4), 500, 1800, q=1.5) * swell(0.4, 0.25) * 0.6
    return out(mix(ring, at(gust_, 0.05, d)), 0.85, wet=0.28, size=1.2, tail=0.6, width=3.0)


def time_up():
    d = 1.6
    return out(bell(d, 392, [1, 2.76, 5.4, 8.9], [0.8, 0.45, 0.25, 0.12], [1, 0.6, 0.35, 0.2]), 0.7, wet=0.35,
               size=1.5, tail=1.0, g=0.78)


def swing(v=0):
    d = 0.2
    lo, hi = [(600, 1900), (700, 2200), (520, 1700)][v]
    w = moving_bp(noise(d), lo, hi, q=1.5) * swell(d, [0.45, 0.4, 0.5][v])
    return out(w, 0.36, wet=0.06, tail=0.15, width=3.0)


def land():
    d = 0.14
    return out(lp(noise(d), 1000) * decay(d, 0.025) + knock(d, 340, 190, 0.03) * 1.2, 0.35, wet=0.05, tail=0.12)


def ui_click():
    d = 0.05
    return out(tone(d, 1400) * decay(d, 0.008) + bp(noise(d), 2500, 6000) * decay(d, 0.002) * 0.3, 0.3, wet=0)


def ui_turn():
    d = 0.4
    note = lambda f, dd: (tone(dd, f) + 0.2 * tone(dd, f * 3)) * decay(dd, 0.1, 0.003)
    return out(mix(note(659.25, 0.2), at(note(987.77, 0.25), 0.08, d)), 0.4, wet=0.1, tail=0.3)


def ui_tick():
    d = 0.07
    return out(tone(d, 1600) * decay(d, 0.012) + bp(noise(d), 2000, 6000) * decay(d, 0.004) * 0.3, 0.35, wet=0)


RECIPES = {
    'hit_light': (hit_light, 3), 'hit_heavy': (hit_heavy, 2), 'hit_counter': (hit_counter, 1), 'slash': (slash, 3),
    'edge': (edge, 1), 'block': (fan_block, 2), 'push': (push, 1), 'parry': (parry, 1), 'clash': (clash, 1),
    'grab': (grab, 1), 'fan_throw': (fan_throw, 2), 'catch': (catch, 1), 'recall': (recall, 1),
    'sweep': (sweep_big, 1), 'gust': (gust, 1), 'blink': (blink, 1), 'down': (down, 1), 'bounce': (bounce, 1),
    'wall': (wall, 1), 'ko': (ko, 1), 'burst': (burst, 1), 'super': (super_, 1), 'sad': (sad, 1), 'beat': (beat, 1),
    'onbeat': (onbeat, 1), 'snap': (snap, 1), 'countered': (countered, 1), 'time': (time_up, 1),
    'swing': (swing, 3), 'land': (land, 1), 'ui_click': (ui_click, 1), 'ui_turn': (ui_turn, 1), 'ui_tick': (ui_tick, 1),
}


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype('<i2').tobytes()
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


if __name__ == '__main__':
    names = sys.argv[1:] or list(RECIPES)
    for n in names:
        fn, variants = RECIPES[n]
        for v in range(variants):
            rng = np.random.default_rng(sum(map(ord, n)) * 7919 + v * 104729)   # (each sound its own fixed noise)
            x = fn(v) if variants > 1 else fn()
            write(n if v == 0 else f'{n}_{v + 1}', x)
        print(f'{n:12s} x{variants}  {len(x) / SR:.2f}s')
