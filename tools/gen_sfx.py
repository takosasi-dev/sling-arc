"""効果音 4 種(発射・衝突・ゴール・コース完了)を assets/sfx/*.wav に書き出す(D-14)。
標準ライブラリだけを使い、同じ入力なら同じバイト列になる(雑音も自前の線形合同法)。
使い方: python tools/gen_sfx.py
"""
import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")


class Lcg:
    def __init__(self, seed):
        self.x = seed & 0xFFFFFFFF

    def next(self):
        self.x = (1664525 * self.x + 1013904223) & 0xFFFFFFFF
        return self.x / 0xFFFFFFFF * 2.0 - 1.0


def env(t, attack, length):
    if t < attack:
        return t / attack
    return max(0.0, 1.0 - (t - attack) / max(1e-6, length - attack)) ** 2


def launch():
    n = int(RATE * 0.32)
    out, phase, noise = [], 0.0, Lcg(7)
    for i in range(n):
        t = i / RATE
        f = 180 + 900 * (t / 0.32) ** 1.6
        phase += 2 * math.pi * f / RATE
        s = 0.55 * math.sin(phase) + 0.18 * noise.next() * (1 - t / 0.32)
        out.append(s * env(t, 0.01, 0.32))
    return out


def crash():
    n = int(RATE * 0.5)
    out, noise, lp = [], Lcg(11), 0.0
    for i in range(n):
        t = i / RATE
        a = 0.35 - 0.3 * t / 0.5
        lp = lp + a * (noise.next() - lp)
        thump = math.sin(2 * math.pi * (90 - 60 * t) * t)
        out.append((0.8 * lp + 0.5 * thump) * env(t, 0.003, 0.5))
    return out


def tone(freqs, length, start=0.0):
    def f(t):
        if t < start:
            return 0.0
        tt = t - start
        s = sum(math.sin(2 * math.pi * fr * tt) + 0.3 * math.sin(4 * math.pi * fr * tt) for fr in freqs)
        return s / len(freqs) * env(tt, 0.005, length)
    return f


def mix(parts, length):
    n = int(RATE * length)
    return [sum(p(i / RATE) for p in parts) * 0.5 for i in range(n)]


def goal():
    return mix([tone([1046.5], 0.35), tone([1318.5], 0.4, 0.08), tone([1568.0, 2093.0], 0.6, 0.16)], 0.8)


def complete():
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    parts = [tone([f], 0.5, i * 0.11) for i, f in enumerate(notes)]
    parts.append(tone([1046.5, 1318.5, 1568.0], 1.1, len(notes) * 0.11))
    return mix(parts, 1.8)


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.8 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("launch", launch), ("crash", crash), ("goal", goal), ("complete", complete)]:
        write(name, fn())
        print("wrote", name)
