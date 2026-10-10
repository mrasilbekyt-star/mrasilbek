"""Generates the game's sound effects into assets/sfx/.

    python3 tool/gen_sfx.py

Every sound is synthesized here, so the game ships no third-party audio.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.9 / peak
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(s * gain * 32767)) for s in samples))


def env(i, n, attack=0.005, release=0.05):
    """Linear attack/release envelope, in seconds."""
    t = i / RATE
    a = min(1.0, t / attack) if attack else 1.0
    r = min(1.0, (n - i) / RATE / release) if release else 1.0
    return a * r


def tone(freq, dur, shape='sine', decay=0.0, attack=0.005, release=0.05):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq(i / RATE) if callable(freq) else freq
        phase += 2 * math.pi * f / RATE
        if shape == 'square':
            v = 1.0 if math.sin(phase) >= 0 else -1.0
        elif shape == 'triangle':
            v = 2 / math.pi * math.asin(math.sin(phase))
        else:
            v = math.sin(phase)
        out.append(v * env(i, n, attack, release) * math.exp(-decay * i / RATE))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def concat(*parts):
    return [s for p in parts for s in p]


def silence(dur):
    return [0.0] * int(RATE * dur)


# The classic "you touched the edge" buzzer.
write('buzz', [v * 0.5 for v in mix(tone(110, 0.38, 'square', decay=2),
                                    tone(166, 0.38, 'square', decay=2))])

# Object found under the X-ray.
write('found', concat(tone(880, 0.09, 'triangle', release=0.03),
                      tone(1320, 0.16, 'triangle', decay=8)))

# Object popped out of the body.
write('pop', tone(lambda t: 500 + 2600 * t, 0.12, 'sine', decay=25, release=0.02))

# One stitch.
random.seed(7)
write('stitch', [v * (0.6 + 0.4 * random.random())
                 for v in tone(2100, 0.05, 'sine', decay=60, release=0.01)])

# Stage cleared: quick major arpeggio.
write('stage', concat(*(tone(f, 0.11, 'triangle', decay=6, release=0.03)
                        for f in (523.25, 659.25, 783.99))))

# Operation successful fanfare.
write('win', concat(
    tone(523.25, 0.14, 'triangle', release=0.03),
    tone(659.25, 0.14, 'triangle', release=0.03),
    tone(783.99, 0.14, 'triangle', release=0.03),
    mix(tone(1046.5, 0.7, 'triangle', decay=3),
        tone(783.99, 0.7, 'sine', decay=3),
        tone(659.25, 0.7, 'sine', decay=3)),
))

# Monitor flatline after a couple of fast beeps.
write('fail', concat(
    tone(1000, 0.08, 'sine'), silence(0.12),
    tone(1000, 0.08, 'sine'), silence(0.12),
    tone(1000, 1.3, 'sine', release=0.4),
))
print('Sounds written to', os.path.normpath(OUT))
