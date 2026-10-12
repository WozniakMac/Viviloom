"""Synthesises every OpenSims sound into assets/audio/*.wav (pure Python, no deps).

Run:  python tools/make_audio.py

All sounds are original: little UI blips and chimes, a cash register, a level-up
arpeggio, babbling "voices" made from formant-filtered pulses, ambient birds and
crickets, and two music loops (a gentle live-mode tune and a bouncier build-mode
one) built from simple additive instruments.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = random.Random(7)


def write(name, samples, rate=RATE):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(x) for x in samples))
    scale = 0.85 / peak if peak > 0.85 else 1.0
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * scale)) * 32767)) for x in samples))
    print("WROTE", name, round(len(samples) / rate, 2), "s")


def silence(sec):
    return [0.0] * int(sec * RATE)


def mix(dst, src, at_sec, gain=1.0):
    i0 = int(at_sec * RATE)
    if len(dst) < i0 + len(src):
        dst.extend([0.0] * (i0 + len(src) - len(dst)))
    for i, x in enumerate(src):
        dst[i0 + i] += x * gain
    return dst


def env(n, attack, decay_rate):
    a = max(1, int(attack * RATE))
    return [(i / a if i < a else 1.0) * math.exp(-decay_rate * max(0, i - a) / RATE) for i in range(n)]


def tone(freq, sec, kind="sine", attack=0.005, decay=6.0, harmonics=None):
    n = int(sec * RATE)
    e = env(n, attack, decay)
    harmonics = harmonics or ([(1, 1.0)] if kind == "sine" else [(1, 1.0), (2, 0.5), (3, 0.25), (4, 0.12)])
    out = []
    for i in range(n):
        t = i / RATE
        v = sum(a * math.sin(2 * math.pi * freq * h * t) for h, a in harmonics)
        out.append(v * e[i])
    return out


def note(n):
    """MIDI note number to Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def piano(n, sec, vel=1.0):
    f = note(n)
    return [x * vel for x in tone(f, sec, harmonics=[(1, 1.0), (2, 0.42), (3, 0.2), (4, 0.1), (5, 0.05)], decay=2.6)]


def pluck(n, sec, vel=1.0):
    return [x * vel for x in tone(note(n), sec, harmonics=[(1, 1.0), (2, 0.3), (3, 0.15)], decay=7.0, attack=0.002)]


def bass(n, sec, vel=1.0):
    return [x * vel for x in tone(note(n), sec, harmonics=[(1, 1.0), (2, 0.25)], decay=3.0, attack=0.01)]


def noise_burst(sec, decay=30.0, lowpass=0.3):
    n = int(sec * RATE)
    out, y = [], 0.0
    for i in range(n):
        y += lowpass * (rng.uniform(-1, 1) - y)
        out.append(y * math.exp(-decay * i / RATE))
    return out


# --- UI ---------------------------------------------------------------------------
def ui_sounds():
    write("click", [x * 0.6 for x in tone(1400, 0.06, decay=60)])
    pop = []
    for i in range(int(0.12 * RATE)):
        t = i / RATE
        f = 500 + 900 * (t / 0.12)
        pop.append(math.sin(2 * math.pi * f * t) * math.exp(-28 * t))
    write("menu_open", pop)
    write("select", mix(tone(note(84), 0.25, decay=14), tone(note(91), 0.25, decay=14), 0.06))
    chime = silence(0.0)
    for k, n in enumerate([76, 81, 88]):
        mix(chime, tone(note(n), 0.7, harmonics=[(1, 1), (2.76, 0.3), (5.4, 0.1)], decay=5), k * 0.08, 0.6)
    write("notice", chime)
    cash = silence(0.0)
    mix(cash, noise_burst(0.08, 50, 0.7), 0.0, 0.5)
    mix(cash, tone(note(96), 0.6, harmonics=[(1, 1), (2.4, 0.5), (3.9, 0.3)], decay=6), 0.05, 0.7)
    mix(cash, tone(note(100), 0.6, harmonics=[(1, 1), (2.4, 0.5)], decay=6), 0.13, 0.6)
    write("cash", cash)
    lvl = silence(0.0)
    for k, n in enumerate([72, 76, 79, 84, 88]):
        mix(lvl, pluck(n, 0.5), k * 0.07, 0.7)
    mix(lvl, piano(84, 1.2), 0.38, 0.5)
    write("level_up", lvl)
    sad = silence(0.0)
    for k, n in enumerate([67, 63]):
        mix(sad, piano(n, 0.8), k * 0.18, 0.6)
    write("fail", sad)
    build_place = mix(noise_burst(0.12, 40, 0.15), tone(180, 0.15, decay=30), 0.0, 0.8)
    write("place", build_place)
    hammer = silence(0.0)
    for k in range(2):
        mix(hammer, mix(noise_burst(0.1, 45, 0.5), tone(120, 0.1, decay=40), 0.0, 0.8), k * 0.12)
    write("demolish", hammer)


# --- voices -----------------------------------------------------------------------
VOWELS = {"a": (800, 1200), "e": (500, 1900), "i": (320, 2400), "o": (500, 900), "u": (350, 800), "ae": (650, 1700)}


def _resonate(x, f, bw):
    r = math.exp(-math.pi * bw / RATE)
    c = 2 * r * math.cos(2 * math.pi * f / RATE)
    y1 = y2 = 0.0
    out = []
    for v in x:
        y = v + c * y1 - r * r * y2
        out.append(y)
        y2, y1 = y1, y
    return out


def babble(pitch, syllables, seed):
    r = random.Random(seed)
    out = []
    for s in range(syllables):
        dur = r.uniform(0.09, 0.2)
        n = int(dur * RATE)
        f0 = pitch * r.uniform(0.85, 1.25)
        glide = r.uniform(-0.25, 0.25)
        src, phase = [], 0.0
        for i in range(n):
            t = i / n
            phase += (f0 * (1 + glide * t)) / RATE
            src.append(1.0 if phase % 1.0 < 0.08 else -0.087)
        v1, v2 = VOWELS[r.choice(list(VOWELS))]
        a = _resonate(src, v1, 90)
        b = _resonate(src, v2, 120)
        e = env(n, 0.02, 4.0)
        tail = [min(1.0, (n - i) / (0.03 * RATE)) for i in range(n)]
        syl = [(a[i] + 0.5 * b[i]) * e[i] * tail[i] for i in range(n)]
        # An occasional consonant click at the start.
        if r.random() < 0.5:
            syl = mix(syl, noise_burst(0.025, 120, 0.8), 0.0, 3.0)
        out.extend(syl)
        out.extend([0.0] * int(r.uniform(0.02, 0.08) * RATE))
    return out


def voices():
    for k in range(4):
        write("voice_low_%d" % k, babble(120 + k * 6, 6 + k % 3, 100 + k))
        write("voice_high_%d" % k, babble(210 + k * 9, 6 + (k + 1) % 3, 200 + k))
    laugh = silence(0.0)
    for k in range(5):
        mix(laugh, babble(240 - k * 8, 1, 300 + k), k * 0.13, 1.0)
    write("laugh", laugh)


# --- ambience ---------------------------------------------------------------------
def ambience():
    birds = silence(12.0)
    for k in range(18):
        start = rng.uniform(0, 11)
        base = rng.uniform(2200, 3800)
        chirp = []
        for i in range(int(0.12 * RATE)):
            t = i / RATE
            chirp.append(math.sin(2 * math.pi * (base + 1800 * math.sin(t * 60)) * t) * math.sin(math.pi * t / 0.12))
        for rep in range(rng.randint(1, 3)):
            mix(birds, chirp, min(11.8, start + rep * 0.16), 0.15)
    wind = noise_burst(12.0, 0.0, 0.01)
    write("birds", [birds[i] + wind[i] * 0.6 for i in range(len(birds))])
    crickets = silence(12.0)
    for k in range(int(12 / 0.45)):
        burst = []
        for i in range(int(0.12 * RATE)):
            t = i / RATE
            burst.append(math.sin(2 * math.pi * 4400 * t) * (0.5 + 0.5 * math.sin(2 * math.pi * 45 * t)) * math.sin(math.pi * t / 0.12))
        mix(crickets, burst, k * 0.45 + rng.uniform(0, 0.05), 0.12)
    write("crickets", crickets)


# --- music ------------------------------------------------------------------------
def song(name, bpm, chords, melody_fn, instrument, bars_per_chord=1, seed=1):
    r = random.Random(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * len(chords) * bars_per_chord
    out = silence(total + 1.5)
    t = 0.0
    for chord in chords:
        for _ in range(bars_per_chord):
            root, kind = chord
            third = 3 if kind == "m" else 4
            notes = [root, root + third, root + 7]
            # Bass on beats 1 and 3, chord stabs, melody on top.
            mix(out, bass(root - 12, beat * 1.8), t, 0.5)
            mix(out, bass(root - 12 + 7, beat * 1.8), t + beat * 2, 0.4)
            for b in range(4):
                for k, nn in enumerate(notes):
                    mix(out, instrument(nn, beat * 1.5, 0.22), t + b * beat + k * 0.012, 1.0)
            for when, nn, length in melody_fn(r, notes, beat):
                mix(out, instrument(nn + 12, length, 0.5), t + when, 1.0)
            t += bar
    # Fold the tail into the start so the loop is seamless.
    n = int(total * RATE)
    for i in range(len(out) - n):
        out[i] += out[n + i]
    write(name, out[:n])


def gentle_melody(r, notes, beat):
    out = []
    pos = 0.0
    while pos < 4 * beat - 0.01:
        length = r.choice([beat, beat, beat * 0.5, beat * 2])
        if r.random() < 0.8:
            out.append((pos, r.choice(notes + [notes[0] + 12, notes[1] + 2]), length * 1.4))
        pos += length
    return out


def bouncy_melody(r, notes, beat):
    out = []
    for k in range(8):
        if r.random() < 0.7:
            out.append((k * beat * 0.5, r.choice(notes + [notes[2] + 2]), beat * 0.6))
    return out


def music():
    # I - vi - IV - V in C, then a lift to F.
    live = [(60, ""), (57, "m"), (65, ""), (67, ""), (60, ""), (64, "m"), (65, ""), (67, "")]
    song("music_live", 92, live, gentle_melody, piano, 1, 3)
    build = [(65, ""), (62, "m"), (58, ""), (60, ""), (65, ""), (69, "m"), (58, ""), (60, "")]
    song("music_build", 118, build, bouncy_melody, pluck, 1, 5)
    cas = [(62, ""), (59, "m"), (67, ""), (69, "")]
    song("music_cas", 100, cas * 2, gentle_melody, pluck, 1, 9)


if __name__ == "__main__":
    ui_sounds()
    voices()
    ambience()
    music()
