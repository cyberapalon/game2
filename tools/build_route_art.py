#!/usr/bin/env python3
"""Mechanical extraction of retained AI paintings; no drawn replacement art.

Inspected source rectangles and anatomical pivots are intentionally explicit.
The image generator did not honor equal cells exactly. All originals remain
unchanged. ImageMagick crops/resizes; animation uses these raster parts in Godot.
"""
from pathlib import Path
import hashlib
import math
import json
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
SOURCE = ASSETS / 'source/route'
OUT = ASSETS / 'route'


def magick(*args: object) -> str:
    values = list(map(str, args))
    if values[-1].endswith('.png'):
        values[-1:-1] = ['-strip']
    return subprocess.check_output(['magick', *values], text=True).strip()


def crop(source: Path, box: tuple[int, int, int, int], output: Path) -> None:
    x, y, width, height = box
    output.parent.mkdir(parents=True, exist_ok=True)
    magick(source, '-crop', f'{width}x{height}+{x}+{y}', '+repage', output)


def dimensions(path: Path) -> tuple[int, int]:
    return struct.unpack('>II', path.read_bytes()[16:24])


def normalized_prop(source: Path, box: tuple[int, int, int, int], name: str,
                    size: tuple[int, int], baseline: int) -> None:
    temp = ROOT / 'work/route-art'
    temp.mkdir(parents=True, exist_ok=True)
    piece = temp / f'{name}.png'
    crop(source, box, piece)
    # Bounds include a two-pixel border to retain painted antialiasing.
    trimmed = temp / f'{name}-trim.png'
    magick(piece, '-trim', '+repage', trimmed)
    width, height = size
    fitted = temp / f'{name}-fit.png'
    magick(trimmed, '-resize', f'{width-4}x{baseline-3}', fitted)
    fw, fh = dimensions(fitted)
    dx, dy = (width - fw) // 2, baseline - fh
    magick('-size', f'{width}x{height}', 'canvas:none', fitted, '-geometry', f'+{dx}+{dy}',
           '-compose', 'Over', '-composite', OUT / f'{name}.png')


def hero() -> None:
    source = SOURCE / 'hero_parts.png'
    # Source is 1254x1254. Rectangles are inspected object bounds, not an
    # assumed grid; the blade crosses the nominal first-row boundary.
    parts = {
        'body': ((30, 8, 370, 440), (240, 398), 0.094, 0.0),
        'cloak': ((430, 150, 405, 275), (789, 194), 0.044, 0.0),
        'scarf': ((835, 150, 400, 270), (1190, 194), 0.040, 0.0),
        'front_thigh': ((130, 445, 170, 360), (210, 493), 16.0/262.15, -0.0343),
        'front_shin': ((545, 445, 150, 360), (624, 497), 16.0/259.05, 0.0193),
        'front_boot': ((875, 565, 340, 240), (960, 610), 0.040, 0.0),
        'back_thigh': ((130, 830, 175, 375), (214, 880), 16.0/280.06, -0.0214),
        'back_shin': ((545, 830, 150, 375), (620, 881), 16.0/281.01, -0.0071),
        'back_boot': ((875, 955, 340, 250), (960, 998), 0.040, 0.0),
    }
    manifest = {}
    scene = ['[gd_scene load_steps=11 format=3]',
             '[ext_resource type="Script" path="res://game/player/wanderer_visual.gd" id="script"]']
    for name, (box, pivot, scale, angle) in parts.items():
        path = OUT / 'hero' / f'{name}.png'
        crop(source, box, path)
        manifest[name] = {'source_box': box, 'pivot': [pivot[0]-box[0], pivot[1]-box[1]],
                          'scale': scale, 'axis_correction_radians': angle}
        if name.endswith('_boot'):
            bounds = magick(path, '-alpha', 'extract', '-threshold', '15%', '-format', '%@', 'info:')
            match = re.fullmatch(r'(\d+)x(\d+)\+(\d+)\+(\d+)', bounds)
            assert match, bounds
            bottom = int(match[4]) + int(match[2]) - 1
            manifest[name]['sole_offset'] = (bottom-manifest[name]['pivot'][1])*scale
        scene.append(f'[ext_resource type="Texture2D" path="res://{path.relative_to(ROOT)}" id="{name}"]')
    scene.append('[node name="Visual" type="Node2D"]\nscript = ExtResource("script")\n'
                 f'front_sole_offset = {manifest["front_boot"]["sole_offset"]}\n'
                 f'back_sole_offset = {manifest["back_boot"]["sole_offset"]}')
    scene.append('[node name="Mirror" type="Node2D" parent="."]')
    # Back limb is behind the fixed torso; front limb is in front of the back
    # limb but both upper joints disappear under the painted coat.
    for side in ['Back', 'Front']:
        for segment in ['Thigh', 'Shin', 'Boot']:
            name = f'{side.lower()}_{segment.lower()}'
            data = manifest[name]
            px, py = data['pivot']
            scale = data['scale']
            angle = data['axis_correction_radians']
            dx = (-px*math.cos(angle)+py*math.sin(angle))*scale
            dy = (-px*math.sin(angle)-py*math.cos(angle))*scale
            scene.append(f'[node name="{side}{segment}" type="Node2D" parent="Mirror"]')
            scene.append(f'[node name="Paint" type="Sprite2D" parent="Mirror/{side}{segment}"]\n'
                         f'texture = ExtResource("{name}")\ncentered = false\ntexture_filter = 2\n'
                         f'position = Vector2({dx}, {dy})\nrotation = {angle}\n'
                         f'scale = Vector2({scale}, {scale})')
    for node, name in [('Cloak', 'cloak'), ('Body', 'body'), ('Scarf', 'scarf')]:
        data = manifest[name]
        px, py = data['pivot']
        scale = data['scale']
        scene.append(f'[node name="{node}" type="Node2D" parent="Mirror"]')
        scene.append(f'[node name="Paint" type="Sprite2D" parent="Mirror/{node}"]\n'
                     f'texture = ExtResource("{name}")\ncentered = false\ntexture_filter = 2\n'
                     f'position = Vector2({-px*scale}, {-py*scale})\n'
                     f'scale = Vector2({scale}, {scale})')
    (ROOT / 'game/player/wanderer_visual.tscn').write_text('\n\n'.join(scene)+'\n')
    (OUT / 'hero/parts.json').write_text(json.dumps(manifest, indent=2)+'\n')


def props() -> None:
    source = SOURCE / 'route_props.png'
    # Generator returned a 1774x887 irregular atlas; keep all actual cutouts.
    for name, box, size, baseline in [
        ('watcher', (15, 4, 375, 545), (160, 180), 164),
        ('shaft', (390, 4, 499, 540), (240, 280), 258),
        ('portal', (891, 20, 501, 525), (120, 160), 148),
        ('sealed_gate', (1394, 0, 380, 545), (240, 400), 400),
        ('keepsake', (45, 570, 285, 317), (56, 56), 54),
        ('hanging_roots', (1000, 545, 320, 342), (256, 300), 298),
        ('fern', (1335, 570, 425, 317), (256, 180), 178),
    ]:
        normalized_prop(source, box, name, size, baseline)
    # One uninterrupted painted platform; crop its inspected flat top and
    # front face, avoiding neighboring cutouts and transparent presentation pad.
    crop(source, (380, 634, 574, 222), OUT / 'platform-crop.png')
    magick(OUT / 'platform-crop.png', '-resize', '160x100!', OUT / 'platform.png')


def environment() -> None:
    for room in ['landing', 'junction', 'hollow', 'seal']:
        magick(SOURCE / f'{room}_depth.png', '-resize', '1280x540^', '-gravity', 'center',
               '-extent', '1280x540', OUT / f'{room}_depth.png')
    magick(SOURCE / 'roots_near.png', '-resize', '1280x540!', OUT / 'roots_near.png')
    source = SOURCE / 'roots_soil.png'
    width, height = dimensions(source)
    alpha = subprocess.check_output(['magick', str(source), '-alpha', 'extract', '-depth', '8', 'gray:-'])
    top = next(y for y in range(height) if sum(v > 220 for v in alpha[y*width:(y+1)*width])/width > 0.95)
    crop_height = round(width*90/1280)
    magick(source, '-crop', f'{width}x{crop_height}+0+{top}', '+repage', '-resize',
           '1280x90!', OUT / 'ground.png')
    # Reuse the approved painted foreground, kept well below the walkable edge.
    magick(ASSETS / 'backgrounds/foreground.png', '-resize', '1280x540!', OUT / 'foreground.png')


def manifest() -> None:
    def describe(path: Path) -> dict:
        data = path.read_bytes()
        d = {'path': str(path.relative_to(ROOT)), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        if path.suffix == '.png':
            d['dimensions'] = list(dimensions(path))
        return d
    inputs = [*sorted(SOURCE.glob('*.png')), ASSETS/'reference/ash_and_porcelain.png',
              ASSETS/'backgrounds/foreground.png']
    outputs = sorted(p for p in OUT.rglob('*') if p.is_file() and p.suffix in ['.png', '.json'])
    outputs.append(ROOT / 'game/player/wanderer_visual.tscn')
    (ASSETS / 'route_generation_manifest.json').write_text(json.dumps({
        'generator': 'Built-in ChatGPT image generator',
        'reference': 'assets/reference/ash_and_porcelain.png',
        'preparation': 'Inspected source rectangles, ImageMagick crop/resize/translation only',
        'inputs': [describe(p) for p in inputs], 'derivatives': [describe(p) for p in outputs],
    }, indent=2)+'\n')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    (ROOT/'work').mkdir(exist_ok=True)
    (ROOT/'work/.gdignore').touch()
    hero()
    props()
    environment()
    manifest()
    print('Route paintings and articulated character parts extracted; originals untouched.')
