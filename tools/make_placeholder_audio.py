#!/usr/bin/env python3
"""Generates Iron Carnage's placeholder sounds and music loop as 16-bit mono WAV files.

Everything here is synthesized from scratch (noise, oscillators, envelopes), so the
placeholders are original and free to use. Replace any file in assets/audio with
real audio of the same name and the game picks it up.

    python3 tools/make_placeholder_audio.py
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1977)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def lowpass(x, cutoff):
    """One-pole low-pass filter."""
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def env(n, attack, decay_pow=2.0):
    e = np.ones(n)
    a = max(1, int(attack * RATE))
    e[:a] = np.linspace(0, 1, a)
    tail = np.linspace(1, 0, n - a) ** decay_pow
    e[a:] = tail
    return e


def save(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (x * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("wrote", os.path.relpath(path), f"{len(x) / RATE:.2f}s")


def saw(freq, t):
    return 2.0 * ((t * freq) % 1.0) - 1.0


def engine():
    # A gruff V-twin-ish idle loop. Loops cleanly: 1.0 s of whole cycles.
    t = t_axis(1.0)
    f = 44.0
    tone = 0.6 * saw(f, t) + 0.3 * np.sin(2 * np.pi * f * 2 * t) + 0.2 * saw(f * 0.5, t)
    putter = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 11 * t))
    rough = lowpass(rng.normal(0, 1, len(t)), 900) * 0.6
    return lowpass(tone * (0.6 + 0.4 * putter) + rough * putter, 1800)


def gun():
    n = int(0.12 * RATE)
    noise = rng.normal(0, 1, n)
    crack = lowpass(noise, 3500) * env(n, 0.001, 3.0)
    t = t_axis(0.12)
    thump = np.sin(2 * np.pi * 120 * t * (1 - t * 3)) * env(n, 0.001, 4.0)
    return crack + 0.7 * thump


def explosion():
    n = int(1.6 * RATE)
    noise = rng.normal(0, 1, n)
    body = lowpass(noise, 500) * env(n, 0.005, 2.2)
    t = t_axis(1.6)
    boom = np.sin(2 * np.pi * (55 - 25 * t) * t) * env(n, 0.002, 3.0) * 1.5
    crackle = lowpass(noise, 4000) * (rng.random(n) > 0.985) * env(n, 0.0, 1.0) * 3
    return body + boom + crackle


def impact():
    n = int(0.35 * RATE)
    t = t_axis(0.35)
    clang = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(180, 1.0), (437, 0.5), (911, 0.3), (1630, 0.2)])
    thud = lowpass(rng.normal(0, 1, n), 300) * 2
    return (clang * 0.6 + thud) * env(n, 0.001, 3.0)


def pickup():
    # Low minor-third chime: uneasy, not cheerful.
    n = int(0.6 * RATE)
    t = t_axis(0.6)
    out = np.zeros(n)
    for i, f in enumerate([220.0, 261.63, 329.63]):
        start = int(i * 0.07 * RATE)
        seg = t[: n - start]
        tone = np.sin(2 * np.pi * f * seg) + 0.3 * np.sin(2 * np.pi * f * 2.01 * seg)
        out[start:] += tone * env(n - start, 0.005, 2.5)
    return out


def ui_click():
    n = int(0.06 * RATE)
    t = t_axis(0.06)
    return np.sin(2 * np.pi * 900 * t) * env(n, 0.001, 4.0) + lowpass(rng.normal(0, 1, n), 2500) * env(n, 0.0, 6.0) * 0.5


def shield():
    # Metal shutters slamming plus a rising electric hum.
    n = int(0.7 * RATE)
    t = t_axis(0.7)
    slam = lowpass(rng.normal(0, 1, n), 1500) * env(n, 0.001, 5.0) * 1.5
    hum = (saw(110 + 80 * t, t) * 0.4 + np.sin(2 * np.pi * 220 * t) * 0.3) * env(n, 0.05, 1.2)
    return slam + lowpass(hum, 2500)


def jump():
    # Hydraulic thump and hiss.
    n = int(0.45 * RATE)
    t = t_axis(0.45)
    thump = np.sin(2 * np.pi * (90 - 60 * t) * t) * env(n, 0.002, 3.0)
    hiss = lowpass(rng.normal(0, 1, n), 5000) * env(n, 0.01, 2.0) * 0.4
    return thump + hiss


def launch():
    # Rocket ignition whoosh.
    n = int(0.6 * RATE)
    noise = rng.normal(0, 1, n)
    body = lowpass(noise, 2200) * env(n, 0.01, 1.5)
    t = t_axis(0.6)
    tone = saw(140 + 300 * t, t) * env(n, 0.005, 2.0) * 0.2
    return body + tone


def freeze():
    # Glassy crackle: high partials with a fast decay.
    n = int(0.8 * RATE)
    t = t_axis(0.8)
    chime = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(1320, 1.0), (1760, 0.6), (2490, 0.4), (3310, 0.3)])
    crackle = lowpass(rng.normal(0, 1, n), 6000) * (rng.random(n) > 0.97) * 2.0
    return (chime * 0.4 + crackle) * env(n, 0.002, 2.5)


def mine_drop():
    # Heavy clunk on concrete, then a short arming beep.
    n = int(0.5 * RATE)
    t = t_axis(0.5)
    clunk = (np.sin(2 * np.pi * 160 * t) + lowpass(rng.normal(0, 1, n), 800)) * env(n, 0.001, 4.0)
    beep = np.zeros(n)
    s0 = int(0.3 * RATE)
    seg = t[: n - s0]
    beep[s0:] = np.sin(2 * np.pi * 1400 * seg) * env(n - s0, 0.002, 3.0) * 0.4
    return clunk + beep


def denied():
    # Dull double buzz for "not enough energy".
    n = int(0.3 * RATE)
    t = t_axis(0.3)
    gate = ((t % 0.15) < 0.09).astype(float)
    return lowpass(saw(95, t), 900) * gate * env(n, 0.002, 1.0)


def cloak():
    # Smog vent: a long hiss that falls away over a low, fading drone.
    n = int(0.9 * RATE)
    t = t_axis(0.9)
    hiss = lowpass(rng.normal(0, 1, n), 3000) * env(n, 0.02, 1.4)
    drone = np.sin(2 * np.pi * (70 - 25 * t) * t) * env(n, 0.05, 2.0) * 0.6
    return hiss + drone


def overdrive():
    # Gun motors spinning up: a rising whine over a fast ratchet.
    n = int(0.7 * RATE)
    t = t_axis(0.7)
    whine = saw(180 + 900 * t, t) * env(n, 0.05, 0.8) * 0.4
    ratchet = lowpass(rng.normal(0, 1, n), 2500) * ((t % 0.035) < 0.012) * env(n, 0.01, 1.0)
    return lowpass(whine, 3500) + ratchet


def thruster():
    # Rocket turbo roar. Loops cleanly: 1.0 s of noise with matching ends, a low
    # rumble and a ragged crackle on top.
    t = t_axis(1.0)
    n = len(t)
    roar = lowpass(rng.normal(0, 1, n), 1400)
    rumble = lowpass(rng.normal(0, 1, n), 160) * 2.5
    crackle = lowpass(rng.normal(0, 1, n), 5000) * (rng.random(n) > 0.96) * 1.5
    flutter = 0.8 + 0.2 * np.sin(2 * np.pi * 23 * t)
    x = (roar + rumble) * flutter + crackle
    # Crossfade the ends so the loop has no click.
    f = int(0.05 * RATE)
    fade = np.linspace(0, 1, f)
    x[:f] = x[:f] * fade + x[-f:] * (1 - fade)
    return x[: n - f]


def nitro():
    # Nitrous hit: a sharp pop, a hissing rush and a falling whoosh.
    n = int(0.7 * RATE)
    t = t_axis(0.7)
    pop = lowpass(rng.normal(0, 1, n), 2500) * env(n, 0.001, 6.0) * 2.0
    rush = lowpass(rng.normal(0, 1, n), 4500) * env(n, 0.02, 1.6)
    whoosh = np.sin(2 * np.pi * (180 - 120 * t) * t) * env(n, 0.005, 2.0) * 0.6
    return pop + rush + whoosh


def hook():
    # Harpoon: a sharp twang, then chain rattling out.
    n = int(0.6 * RATE)
    t = t_axis(0.6)
    twang = np.sin(2 * np.pi * (520 - 300 * t) * t) * env(n, 0.001, 4.0) * 0.6
    rattle = lowpass(rng.normal(0, 1, n), 4000) * ((t % 0.04) < 0.012) * env(n, 0.01, 1.2)
    clank = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(870, 1.0), (1730, 0.5), (2610, 0.3)]) * ((t % 0.09) < 0.01) * 0.4
    return twang + rattle + clank


def sawblade():
    # Blade spinning up: a metallic whine over grinding grit.
    n = int(0.7 * RATE)
    t = t_axis(0.7)
    whine = saw(600 + 900 * t, t)
    grit = lowpass(rng.normal(0, 1, n), 6000) * (rng.random(n) > 0.9) * 0.8
    return (lowpass(whine, 4000) * 0.5 + grit) * env(n, 0.02, 1.3)


def slam():
    # Dead Weight: a huge concrete thud with a ground rumble and a metal ring.
    n = int(1.4 * RATE)
    t = t_axis(1.4)
    thud = np.sin(2 * np.pi * (48 - 20 * t) * t) * env(n, 0.002, 2.5) * 1.6
    rumble = lowpass(rng.normal(0, 1, n), 220) * env(n, 0.01, 1.8) * 2.0
    ring = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(140, 1.0), (377, 0.5), (811, 0.25)]) * env(n, 0.001, 3.0) * 0.3
    return thud + rumble + ring


def music_yard():
    """A 32-second dark industrial loop at 90 bpm in D minor: drone, pulse, metal hits."""
    bpm = 90.0
    beat = 60.0 / bpm
    bars = 12
    seconds = bars * 4 * beat  # 32 s
    t = t_axis(seconds)
    n = len(t)
    out = np.zeros(n)

    # Drone: D1 and A1 with slow beating, filtered.
    drone = 0.5 * saw(36.71, t) + 0.35 * saw(55.0 * 1.002, t) + 0.25 * np.sin(2 * np.pi * 73.42 * t)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t / seconds * 2) ** 2
    out += lowpass(drone, 380) * swell * 0.55

    # Bass pulse: an original 2-bar pattern, root moves D, D, Bb, A over 8 bars.
    roots = [73.42, 73.42, 58.27, 55.0]
    pattern = [1, 0, 0, 1, 0, 0, 1, 0]  # eighth notes
    eighth = beat / 2
    for bar in range(bars):
        root = roots[(bar // 2) % len(roots)]
        for step, hit in enumerate(pattern):
            if not hit:
                continue
            start = int((bar * 4 * beat + step * eighth) * RATE)
            length = int(eighth * 1.6 * RATE)
            end = min(n, start + length)
            seg = t[: end - start]
            note = saw(root, seg) * 0.7 + np.sin(2 * np.pi * root * 0.5 * seg) * 0.6
            out[start:end] += lowpass(note, 600) * env(end - start, 0.004, 2.0) * 0.5

    # Kick on beats 1 and 3, a metal hit on beat 4 of every other bar.
    for bar in range(bars):
        for b in (0, 2):
            start = int((bar * 4 + b) * beat * RATE)
            ln = int(0.4 * RATE)
            end = min(n, start + ln)
            seg = t[: end - start]
            kick = np.sin(2 * np.pi * (60 - 40 * seg / 0.4) * seg) * env(end - start, 0.002, 3.0)
            out[start:end] += kick * 0.8
        if bar % 2 == 1:
            start = int((bar * 4 + 3) * beat * RATE)
            ln = int(1.2 * RATE)
            end = min(n, start + ln)
            seg = t[: end - start]
            metal = sum(np.sin(2 * np.pi * f * seg) * a for f, a in [(311, 1.0), (743, 0.6), (1187, 0.4), (2011, 0.25)])
            out[start:end] += metal * env(end - start, 0.001, 2.5) * 0.18

    # Distant machinery hiss that breathes over the loop.
    hiss = lowpass(rng.normal(0, 1, n), 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0)) * 0.06
    out += hiss

    # Short fades at the ends so the loop point is clean.
    f = int(0.02 * RATE)
    out[:f] *= np.linspace(0, 1, f)
    out[-f:] *= np.linspace(1, 0, f)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    save("engine", engine(), 0.8)
    save("gun", gun(), 0.8)
    save("explosion", explosion(), 0.95)
    save("impact", impact(), 0.8)
    save("pickup", pickup(), 0.7)
    save("ui_click", ui_click(), 0.6)
    save("music_yard", music_yard(), 0.75)
    # Milestone 2 sounds (generated after the music so the music stays the same).
    save("shield", shield(), 0.8)
    save("jump", jump(), 0.8)
    save("launch", launch(), 0.75)
    save("freeze", freeze(), 0.7)
    save("mine_drop", mine_drop(), 0.75)
    save("denied", denied(), 0.6)
    save("cloak", cloak(), 0.75)
    save("overdrive", overdrive(), 0.7)
    save("thruster", thruster(), 0.7)
    save("nitro", nitro(), 0.8)
    save("hook", hook(), 0.8)
    save("saw", sawblade(), 0.7)
    save("slam", slam(), 0.95)


if __name__ == "__main__":
    main()
