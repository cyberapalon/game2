#!/usr/bin/env python3
"""Original deterministic PCM sound design, no samples or external service."""
from array import array
import math
from pathlib import Path
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
OUTPUT = ROOT / 'assets/audio'


def write(name: str, samples: list[float]) -> None:
    # All recipes leave headroom; clamp only as a last guard against overload.
    data = array('h', (round(max(-0.95, min(0.95, x)) * 32767) for x in samples))
    if sys.byteorder != 'little':
        data.byteswap()
    with wave.open(str(OUTPUT / name), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(data.tobytes())


def impact(duration: float, seed: int, weight: float) -> list[float]:
    rng = random.Random(seed)
    low = 0.0
    samples = []
    for index in range(round(duration * RATE)):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        low += (noise - low) * 0.09
        attack = min(1.0, t * 600)
        thud = math.sin(math.tau * (95 - 50 * t) * t) * math.exp(-t * 34)
        grit = (noise * 0.11 + low * 1.8) * math.exp(-t * 24)
        samples.append((thud * 0.24 + grit) * attack * weight)
    return samples


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(7163)
    duration = 16
    low, mid = 0.0, 0.0
    ambient = []
    for index in range(duration * RATE):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        low += (noise - low) * 0.0025
        mid += (noise - mid) * 0.025
        swell = 0.65 + 0.25 * math.sin(math.tau * t / 16)
        wind = (low * 2.2 + mid * 0.16) * swell
        drone = sum(math.sin(math.tau * frequency * t) * strength for frequency, strength in
                    [(55, 0.014), (82.5, 0.008), (110.0625, 0.005)])
        # An intermittent, low, timber-like creak under the wind.
        creak_gate = max(0.0, math.sin(math.tau * t / 8)) ** 12
        creak = math.sin(math.tau * 137.5 * t + math.sin(math.tau * t / 4)) * creak_gate * 0.012
        ambient.append(wind + drone + creak)
    # Equal-power overlap removes a noise discontinuity at the loop boundary.
    overlap = RATE
    for index in range(overlap):
        phase = index / (overlap - 1) * math.pi / 2
        ambient[index] = ambient[-overlap + index] * math.cos(phase) + ambient[index] * math.sin(phase)
    write('surface_ambience.wav', ambient[:-overlap])
    for index in range(4):
        write(f'step_{index}.wav', impact(0.20, 810 + index, 0.38 + index * 0.025))
    write('land.wav', impact(0.32, 902, 1.0))
    write('jump.wav', impact(0.16, 1003, 0.22))
    print('Seven original WAV files built; no recorded or third-party samples.')


if __name__ == '__main__':
    main()
