"""A numbered listening board of every sound (an MP4: each sound's number and name on screen while it plays), to pick
from by number.   <comfy python> tools/sfx_board.py <out.mp4>"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FFMPEG = ('C:/Users/ajisa/AppData/Local/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/.venv/Lib/site-packages/'
          'imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe')
GROUPS = [
    ('Hits', [('hit_light', 'a hit'), ('hit_heavy', 'a big hit'), ('hit_counter', 'a counter hit'),
              ('edge', "at the fan's edge (with a hit)")]),
    ('Defence', [('block', 'a block'), ('push', 'a Push Block'), ('parry', 'a parry'), ('clash', 'a clash'),
                 ('countered', 'Mirror (countered)')]),
    ('Her fans', [('swing', 'a swing (any attack)'), ('fan_throw', 'Fan Throw'), ('catch', 'a fan caught'),
                  ('recall', 'Recall'), ('sweep', 'the big fan sweep'), ('gust', 'Updraft'), ('blink', 'Fan Step')]),
    ('Bodies', [('grab', 'a grab'), ('down', 'knocked down'), ('bounce', 'a ground bounce'), ('wall', 'a wall splat'),
                ('land', 'landing a drop')]),
    ('Big moments', [('super', 'a super starts'), ('burst', 'a Burst'), ('ko', 'a KO'), ('time', 'time up')]),
    ('Tempo and the rest', [('beat', 'a Tempo beat'), ('onbeat', 'ON BEAT (Tempo full)'), ('sad', 'Sadness'),
                            ('snap', 'Instant / Whiff Cancel')]),
    ('Menus', [('ui_click', 'a button'), ('ui_turn', 'your turn'), ('ui_tick', 'the clock running out')]),
]
SR = 44100
GAP = 0.55


def read(name):
    with wave.open(str(ROOT / 'assets' / 'sfx' / f'{name}.wav')) as w:
        return np.frombuffer(w.readframes(w.getnframes()), '<i2')


def main(out):
    font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 64)
    small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 40)
    tmp = Path(tempfile.mkdtemp())
    audio = []
    lines = []
    n = 0
    for group, items in GROUPS:
        for name, what in items:
            n += 1
            for _rep in range(2):   # (each played twice)
                x = read(name)
                seg = np.concatenate([np.zeros(int(SR * 0.15), '<i2'), x, np.zeros(int(SR * GAP), '<i2')])
                audio.append(seg)
                im = Image.new('RGB', (1280, 720), (11, 12, 16))
                d = ImageDraw.Draw(im)
                d.text((80, 200), group.upper(), font=small, fill=(138, 138, 156))
                d.text((80, 280), f'{n}. {what}', font=font, fill=(242, 242, 247))
                d.text((80, 380), name, font=small, fill=(255, 210, 63))
                p = tmp / f'{len(lines):03d}.png'
                im.save(p)
                lines.append(f"file '{p.as_posix()}'\nduration {len(seg) / SR:.4f}")
    lines.append(f"file '{(tmp / f'{len(lines) - 1:03d}.png').as_posix()}'")
    (tmp / 'list.txt').write_text('\n'.join(lines), encoding='utf-8')
    with wave.open(str(tmp / 'all.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(np.concatenate(audio).tobytes())
    subprocess.run([FFMPEG, '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(tmp / 'list.txt'),
                    '-i', str(tmp / 'all.wav'), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-c:a', 'aac',
                    '-b:a', '160k', '-shortest', out], check=True)
    print(out, n, 'sounds')


if __name__ == '__main__':
    main(sys.argv[1])
