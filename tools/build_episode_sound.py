#!/usr/bin/env python3
"""Original composed PCM synthesis. No samples, recordings or audio services."""
import math
import random
from build_sound_resources import RATE, write, impact


def theme(name, duration, boss=False):
    rng = random.Random(197 if boss else 71)
    samples = []
    motif = [146.832, 174.614, 164.814, 110.0, 130.813, 110.0, 98.0, 110.0]
    low = 0.0
    for i in range(int(duration * RATE)):
        t = i / RATE
        beat = t % (0.6666667 if boss else 2.0)
        note = motif[int(t / (2.0 if boss else 4.0)) % len(motif)]
        low += (rng.uniform(-1, 1) - low) * .004
        drone = .035 * math.sin(math.tau * 55 * t) + .018 * math.sin(math.tau * 82.5 * t)
        bell = (.04 if boss else .032) * math.sin(math.tau * note * t) * math.exp(-beat * (4 if boss else 1.7))
        overtone = .012 * math.sin(math.tau * note * 2.001 * t) * math.exp(-beat * 3)
        pulse = .15 * math.sin(math.tau * (64 * beat - 23 * beat * beat)) * math.exp(-beat * 19) if boss else 0.0
        tension = .013 * math.sin(math.tau * 58.27 * t) * (0.5 + 0.5 * math.sin(math.tau * t / 8)) if boss else 0.0
        edge = min(1.0, t / .08, (duration - t) / .08)
        samples.append((drone + bell + overtone + pulse + tension + low * .06) * edge)
    write(name, samples)


def chime(name, frequencies, duration=1.2):
    write(name, [sum(math.sin(math.tau * f * i / RATE) * .13 / len(frequencies) * math.exp(-i / RATE * 3)
                     for f in frequencies) * min(1, i / (RATE * .015)) for i in range(int(RATE * duration))])


def main():
    theme('roots_theme.wav', 32)
    theme('heart_theme.wav', 16, True)
    for name, duration, seed, weight in [
        ('strike.wav', .18, 210, .5), ('hit.wav', .23, 211, 1.0),
        ('hurt.wav', .35, 212, 1.4), ('death.wav', .8, 213, 1.2),
        ('enemy_warning.wav', .3, 214, .4), ('enemy_death.wav', .55, 215, .8),
        ('boss_slam.wav', .9, 216, 1.7), ('gate.wav', 1.1, 217, 1.3),
    ]:
        write(name, impact(duration, seed, weight))
    chime('ability.wav', [220, 329.627, 440, 659.255], 2.0)
    chime('checkpoint.wav', [146.832, 220, 293.665])
    chime('dash.wav', [164.814, 329.627], .4)
    chime('boss_death.wav', [55, 58.27, 82.5, 110], 2.5)
    print('Two original synthesised themes and twelve cues built.')


if __name__ == '__main__':
    main()
