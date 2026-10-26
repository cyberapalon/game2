#!/usr/bin/env python3
"""Rebuild original SVG art and SpriteFrames using only the standard library.

The generated panorama is a separate image-generation source; see art-direction.md.
"""
import math
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[1]
HERO = ROOT / 'game/player/art'
WORLD = ROOT / 'world/surface/art'


def svg(path, width, height, body):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
                    f'height="{height}" viewBox="0 0 {width} {height}">{body}</svg>\n')


def hero(clip, frame, count):
    airborne = clip in ('jump', 'fall')
    phase = (frame + (0.25 if airborne else 0)) * math.tau / count
    stride = math.sin(phase) if clip == 'run' else 0
    bob = abs(math.cos(phase)) * 2 if clip == 'run' else math.sin(phase) * 1.4
    wind = {'run': 10, 'jump': 13, 'fall': 4, 'idle': 2}[clip]
    wind += math.sin(phase) * 3 + math.cos(phase) * 1.5
    # Fixed canvas and grounded feet. Cloth, mask, arms and legs have drawn poses;
    # these coordinates never alter the CharacterBody2D or its collider.
    legs = ''
    for side in (-1, 1):
        x = 62 + side * 8
        end_x = x + side * stride * 16
        knee_lift = 12 if clip == 'jump' else 3
        end_y = 104 - (max(0, -side * stride) * 10 if not airborne else knee_lift)
        if airborne:
            end_x += side * 9
        legs += f'<path d="M{x} 83 Q{x + side * 5} 94 {end_x} {end_y} l8 2" fill="none" stroke="#141f28" stroke-width="9" stroke-linecap="round"/><path d="M{end_x - 2} {end_y - 3} l8 2" stroke="#9aa8a6" stroke-width="2"/>'
    cloak = f'M53 49 Q69 44 79 57 Q81 78 91 91 L79 87 L77 100 L65 94 L56 101 L49 93 L{28-wind} 99 Q{43-wind} 76 47 58Z'
    body = f'''<defs>
<linearGradient id="cloth" x2=".85" y2="1"><stop stop-color="#77888a"/><stop offset=".42" stop-color="#435c65"/><stop offset="1" stop-color="#263845"/></linearGradient>
<linearGradient id="mask" x2=".9" y2="1"><stop stop-color="#f6efce"/><stop offset=".55" stop-color="#c9cbb9"/><stop offset="1" stop-color="#7c999b"/></linearGradient>
</defs>{legs}<g transform="translate(0 {bob:.2f})">
<path d="{cloak}" fill="url(#cloth)" stroke="#14232e" stroke-width="3" stroke-linejoin="round"/>
<path d="M53 54 Q49 76 {35-wind} 93 M62 58 Q55 81 55 94 M70 62 L73 89" fill="none" stroke="#9ba9a0" stroke-opacity=".48" stroke-width="1.5"/>
<path d="M49 54 Q65 46 79 56 L82 65 Q66 57 48 63Z" fill="#9c7956" stroke="#24333a" stroke-width="2"/>
<path d="M49 57 Q{33-wind} 62 {24-wind} {55+math.sin(phase)*6} L{28-wind} 63 Q39 72 56 62" fill="#a58962" stroke="#23313a" stroke-width="2"/>
<path d="M59 20 Q76 14 83 31 L87 43 L76 55 Q64 57 53 46 L48 34 Q48 23 59 20Z" fill="url(#mask)" stroke="#223540" stroke-width="3"/>
<path d="M52 31 Q60 19 73 23 M53 36 Q63 27 79 29 M56 42 Q64 35 80 34" fill="none" stroke="#fbf2d6" stroke-opacity=".55" stroke-width="1.5"/>
<path d="M65 22 L64 32 L70 36 L67 45 L73 53" fill="none" stroke="#61777b" stroke-width="1.6"/>
<path d="M72 37 L83 34 L80 41 L73 43Z" fill="#132b35"/>
<path d="M75 38 L80 37" stroke="#e7ce91" stroke-width="1.5"/>
<path d="M55 24 L50 33 L53 43" fill="none" stroke="#dfcba6" stroke-width="2"/>
<circle cx="72" cy="59" r="3" fill="#f0cc80"/><path d="M72 61 L69 70" stroke="#d4b278"/>
</g>'''
    svg(HERO / f'{clip}_{frame:02}.svg', 128, 128, body)


def main():
    clips = [('idle', 6, 6), ('run', 8, 12), ('jump', 2, 6), ('fall', 2, 6)]
    resources, animations = [], []
    for clip, count, fps in clips:
        frames = []
        for frame in range(count):
            hero(clip, frame, count)
            rid = f'{clip}_{frame}'
            resources.append(f'[ext_resource type="Texture2D" path="res://game/player/art/{clip}_{frame:02}.svg" id="{rid}"]')
            frames.append('{"duration": 1.0, "texture": ExtResource("' + rid + '")}')
        animations.append('{"frames": [' + ', '.join(frames) + f'], "loop": true, "name": &"{clip}", "speed": {fps}.0' + '}')
    (HERO.parent / 'player_frames.tres').write_text(
        f'[gd_resource type="SpriteFrames" load_steps={len(resources)+1} format=3]\n\n'
        + '\n'.join(resources) + '\n\n[resource]\nanimations = [\n'
        + ',\n'.join(animations) + '\n]\n')
    rng = random.Random(71)
    ground = '''<defs><linearGradient id="earth" x2="0" y2="1"><stop stop-color="#36454a"/><stop offset=".26" stop-color="#202f37"/><stop offset="1" stop-color="#0d1923"/></linearGradient></defs>
<path d="M0 0 H1600 V140 H0Z" fill="url(#earth)"/>
<path d="M0 1 H1600 M0 5 H1600" stroke="#a2aa96" stroke-opacity=".6"/>
'''
    for x in sorted(rng.sample(range(8, 1592), 34)):
        y = rng.randrange(7, 26)
        ground += f'<path d="M{x} 3 q-5 {y//2} 3 {y} l-8 12 l13 18 M{x+3} {y+3} l19 4" fill="none" stroke="#101e28" stroke-width="1.2"/>'
    for _ in range(160):
        x, y = rng.randrange(1600), rng.randrange(4, 32)
        ground += f'<path d="M{x} {y} q4 -4 9 -1 l-2 3 l-7 1Z" fill="{rng.choice(["#687773", "#36454a", "#1e3039"])}" stroke="#122631" stroke-width=".5"/>'
    for _ in range(65):
        x, y = rng.randrange(1600), rng.randrange(30, 130)
        ground += f'<path d="M{x} {y} q20 -8 48 0 q-18 4 -43 2" fill="#53605a" opacity=".07"/>'
    for _ in range(600):
        x, y = rng.randrange(1600), rng.randrange(6, 136)
        ground += f'<path d="M{x} {y} l{rng.randrange(2,9)} -1" stroke="{rng.choice(["#718079", "#111e27", "#455451"])}" stroke-opacity=".5"/>'
    svg(WORLD / 'earth.svg', 1600, 140, ground)
    rubble = '<path d="M4 18 H176 V78 H155 C153 48 123 34 90 34 C56 34 27 48 25 78 H4Z" fill="#273a42" stroke="#526165" stroke-width=".8"/><path d="M10 28 L13 73 M169 29 L166 75 M28 36 Q90 12 150 36" fill="none" stroke="#1b2e38" stroke-width="3"/>'
    rubble += '<path d="M0 0 H180 L176 20 L143 24 L121 17 L95 23 L60 19 L31 24 L3 18Z" fill="#4a5859" stroke="#182933" stroke-width="2"/><path d="M0 1 H180 M6 5 L90 6 L114 4 L176 5" stroke="#c1baa0" fill="none"/>'
    for x in (28, 69, 113, 155):
        rubble += f'<path d="M{x} 2 l-3 9 l7 10 M{x-3} 11 l-18 2" fill="none" stroke="#23363e" stroke-width="2"/>'
    svg(WORLD / 'rubble.svg', 180, 78, rubble)
    # Architectural midground: broken rail piers, cable and hand-etched cracks.
    ruins = '<defs><linearGradient id="concrete" x1="0" x2="1" y2=".2"><stop stop-color="#1d313a"/><stop offset=".38" stop-color="#45575a"/><stop offset=".7" stop-color="#2d4249"/><stop offset="1" stop-color="#192e38"/></linearGradient></defs>'
    for x, height in [(80, 180), (580, 115), (1260, 224), (1600, 150)]:
        y = 420-height
        ruins += f'<path d="M{x} 420 L{x+3} {y+49} L{x+8} {y+33} L{x+6} {y+20} L{x+19} {y+16} L{x+21} {y+4} L{x+32} {y+10} L{x+37} {y+3} L{x+39} {y+20} L{x+56} {y+26} L{x+52} {y+69} L{x+49} 420Z" fill="url(#concrete)" stroke="#72807a" stroke-width=".8"/>'
        ruins += f'<path d="M{x+6} {y+46} l18 9 l-7 28 l9 17 l-4 41 M{x+47} {y+80} l-15 13 l8 9 M{x+10} {y+140} l16 11 l-5 30" fill="none" stroke="#172c37" stroke-width="1.6"/>'
        ruins += f'<path d="M{x+20} {y+17} q-9 -23 2 -31 M{x+32} {y+10} l3 -25 q9 -12 12 2 l-3 29 M{x+46} {y+22} l14 -17" fill="none" stroke="#415056" stroke-width="1.5"/>'
        for _ in range(100):
            px, py = x+rng.randrange(8, 48), y+rng.randrange(30, height)
            length = rng.randrange(2, 8)
            ruins += f'<path d="M{px} {py} l{length} -1" stroke="{rng.choice(["#8a9184", "#142b37", "#69776e"])}" stroke-width=".6" opacity=".38"/>'
        for _ in range(12):
            px, py = x+rng.randrange(8, 42), y+rng.randrange(30, height)
            ruins += f'<path d="M{px} {py} l4 -3 l5 2 l-5 7Z" fill="#142c38" opacity=".5"/>'
    ruins += '<path d="M625 335 q10 16 18 1 M637 333 v19" fill="none" stroke="#718079" stroke-width="1.3"/><path d="M634 351 l7 -1 l1 9 l-9 1Z" fill="#d0aa65" stroke="#3e4b46"/><path d="M635 352 v5" stroke="#f4db9b"/>'
    ruins += '<path d="M110 244 Q340 337 604 314 M609 314 Q918 389 1290 210" fill="none" stroke="#34494e" stroke-width="1.5"/>'
    for x in (140, 688, 1194, 1490):
        ruins += f'<path d="M{x-35} 420 l5 -16 l17 -8 l15 12 l24 -4 l9 16Z" fill="#2d4147" stroke="#526266"/>'
    svg(WORLD / 'ruins.svg', 1800, 540, ruins)
    foreground = ''
    for x in (20, 176, 510, 835, 1210, 1520, 1700):
        for _ in range(9):
            tip_x, tip_y = x+rng.randrange(-35,36), rng.randrange(450, 490)
            foreground += f'<path d="M{x} 540 Q{x-8} 494 {tip_x} {tip_y}" fill="none" stroke="#0d1c26" stroke-width="{rng.randrange(2,5)}"/>'
        foreground += f'<path d="M{x-55} 540 l18 -22 l29 -8 l24 9 l24 21Z" fill="#0d1c26"/>'
    svg(WORLD / 'foreground.svg', 1800, 540, foreground)
    svg(WORLD / 'mist.svg', 1800, 180, '''<defs><radialGradient id="fog"><stop stop-color="#b8cdc6" stop-opacity=".12"/><stop offset="1" stop-color="#b8cdc6" stop-opacity="0"/></radialGradient></defs><ellipse cx="470" cy="100" rx="470" ry="70" fill="url(#fog)"/><ellipse cx="1240" cy="90" rx="550" ry="75" fill="url(#fog)"/>''')
    svg(WORLD / 'mote.svg', 16, 16, '<defs><radialGradient id="m"><stop stop-color="#f8deb0" stop-opacity=".8"/><stop offset="1" stop-color="#f8deb0" stop-opacity="0"/></radialGradient></defs><circle cx="8" cy="8" r="8" fill="url(#m)"/>')


if __name__ == '__main__':
    main()
