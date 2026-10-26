#!/usr/bin/env python3
"""Extract retained AI PNGs into Godot resources; never draw replacement art.

Requires the pinned ImageMagick. Sources stay intact, and every derivative is
listed with SHA-256 in assets/generation_manifest.json. Run from any directory.
"""
from pathlib import Path
import hashlib
import json
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
TEMP = ROOT / 'work/art-build'


def magick(*args: object) -> str:
    command = list(map(str, args))
    if command[-1].endswith('.png'):
        # Stable derivative bytes; signed original metadata stays in sources.
        command[-1:-1] = ['-strip']
    return subprocess.check_output(['magick', *command], text=True).strip()


def dimensions(path: Path) -> tuple[int, int]:
    return struct.unpack('>II', path.read_bytes()[16:24])


def cell(path: Path, column: int, row: int, columns: int, rows: int) -> tuple[int, int, int, int]:
    width, height = dimensions(path)
    x, end_x = width * column // columns, width * (column + 1) // columns
    y, end_y = height * row // rows, height * (row + 1) // rows
    return x, y, end_x - x, end_y - y


def geometry(box: tuple[int, int, int, int]) -> str:
    x, y, width, height = box
    return f'{width}x{height}+{x}+{y}'


def bounds(path: Path, box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    result = magick(path, '-crop', geometry(box), '+repage', '-alpha', 'extract',
                    '-threshold', '12%', '-format', '%@', 'info:')
    match = re.fullmatch(r'(\d+)x(\d+)\+(\d+)\+(\d+)', result)
    if not match or not int(match[1]) or not int(match[2]):
        raise ValueError(f'Empty or invalid alpha bounds: {path} {box}: {result}')
    width, height, x, y = map(int, match.groups())
    return x, y, width, height


def frames_resource(atlas: Path, clips: list[tuple[str, list[int], float, bool]],
                    columns: int, cell_size: int, output: Path) -> None:
    count = sum(len(indices) for _, indices, _, _ in clips)
    text = [f'[gd_resource type="SpriteFrames" load_steps={count + 2} format=3]',
            f'[ext_resource type="Texture2D" path="res://{atlas.relative_to(ROOT)}" id="1"]']
    animations = []
    for name, indices, speed, loop in clips:
        frame_ids = []
        for number, index in enumerate(indices):
            key = f'{name}_{number}'
            x, y = index % columns * cell_size, index // columns * cell_size
            text.append(f'[sub_resource type="AtlasTexture" id="{key}"]\n'
                        'atlas = ExtResource("1")\n'
                        f'region = Rect2({x}, {y}, {cell_size}, {cell_size})\n'
                        'filter_clip = true')
            frame_ids.append(f'{{"duration": 1.0, "texture": SubResource("{key}")}}')
        animations.append('{"frames": [' + ', '.join(frame_ids) + '], '
                          f'"loop": {str(loop).lower()}, "name": &"{name}", "speed": {speed}}}')
    text.append('[resource]\nanimations = [' + ',\n'.join(animations) + ']\n')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text('\n\n'.join(text))


def character() -> None:
    source = ASSETS / 'source/wanderer.png'
    boxes = [cell(source, i % 4, i // 4, 4, 5) for i in range(20)]
    occupied = [bounds(source, box) for box in boxes]
    # One scale for every pose; only translate to the common foot baseline.
    factor = 100.0 / max(box[3] for box in occupied)
    frames = []
    for index, (box, alpha_box) in enumerate(zip(boxes, occupied)):
        _, _, width, _ = box
        _, ay, _, ah = alpha_box
        # The painted torso is slightly right of the geometric cell center.
        dx = 64 - round(width * factor * 0.55)
        dy = 108 - round((ay + ah) * factor)
        output = TEMP / f'wanderer-{index:02}.png'
        magick('-size', '128x128', 'canvas:none', '(', source, '-crop', geometry(box),
               '+repage', '-resize', f'{factor * 100:.8f}%', ')', '-geometry', f'{dx:+}{dy:+}',
               '-compose', 'Over', '-composite', output)
        frames.append(output)
    rows = []
    for row in range(5):
        output = TEMP / f'wanderer-row-{row}.png'
        magick(*frames[row * 4:(row + 1) * 4], '+append', output)
        rows.append(output)
    atlas = ASSETS / 'characters/wanderer_atlas.png'
    atlas.parent.mkdir(parents=True, exist_ok=True)
    magick(*rows, '-append', atlas)
    frames_resource(atlas, [
        ('idle', list(range(4)), 5.0, True),
        ('run', list(range(4, 12)), 16.0, True),
        ('jump', list(range(12, 16)), 12.0, False),
        ('fall', list(range(16, 20)), 10.0, False),
    ], 4, 128, ROOT / 'game/player/player_frames.tres')


def environment() -> None:
    source = ASSETS / 'source/terrain.png'
    destination = ASSETS / 'environment'
    destination.mkdir(parents=True, exist_ok=True)
    rows = []
    for row in range(2):
        tiles = []
        for column in range(4):
            x, y, width, height = cell(source, column, row, 4, 4)
            # Inspection found the solid cap around 20% down each source cell.
            # Remove the presentation padding before aligning to collision y.
            inset = round(height * 0.20) if row == 0 else 0
            output = TEMP / f'tile-{column}-{row}.png'
            magick(source, '-crop', geometry((x, y + inset, width, height - inset)),
                   '+repage', '-resize', '64x64!', output)
            tiles.append(output)
        output = TEMP / f'terrain-row-{row}.png'
        magick(*tiles, '+append', output)
        rows.append(output)
    atlas = destination / 'terrain_atlas.png'
    magick(*rows, '-append', atlas)
    tiles = '\n'.join(f'{column}:{row}/0 = 0' for row in range(2) for column in range(4))
    (destination / 'terrain_tileset.tres').write_text(
        '[gd_resource type="TileSet" load_steps=3 format=3]\n\n'
        '[ext_resource type="Texture2D" path="res://assets/environment/terrain_atlas.png" id="1"]\n\n'
        '[sub_resource type="TileSetAtlasSource" id="Atlas"]\n'
        'texture = ExtResource("1")\ntexture_region_size = Vector2i(64, 64)\n' + tiles +
        '\n\n[resource]\ntile_size = Vector2i(64, 64)\nsources/0 = SubResource("Atlas")\n')
    names = ['fern', 'mushrooms', 'hanging_roots', 'utility_post',
             'culvert', 'sap_light', 'sleepers', 'slab']
    for index, name in enumerate(names):
        box = cell(source, index % 4, index // 4 + 2, 4, 4)
        magick(source, '-crop', geometry(box), '+repage', '-resize', '256x256!',
               destination / f'{name}.png')


def effects() -> None:
    source = ASSETS / 'source/effects.png'
    destination = ASSETS / 'vfx'
    destination.mkdir(parents=True, exist_ok=True)
    # The generator placed the first row's baseline just below its nominal
    # quarter. Use inspected row boundaries, then translate dust to y=108.
    atlas = destination / 'effects_atlas.png'
    width, height = dimensions(source)
    boxes = []
    for row in range(2):
        top = 0 if row == 0 else round(height * 0.27)
        bottom = round(height * (0.27 if row == 0 else 0.50))
        for column in range(4):
            x, _, cell_width, _ = cell(source, column, row, 4, 4)
            boxes.append((x, top, cell_width, bottom - top))
    occupied = [bounds(source, box) for box in boxes]
    factor = 90.0 / max(box[3] for box in occupied)
    rows = []
    for row in range(2):
        frames = []
        for column in range(4):
            index = row * 4 + column
            box, alpha_box = boxes[index], occupied[index]
            dx = 64 - round(box[2] * factor / 2)
            dy = 108 - round((alpha_box[1] + alpha_box[3]) * factor)
            output = TEMP / f'dust-{index}.png'
            magick('-size', '128x128', 'canvas:none', '(', source, '-crop', geometry(box),
                   '+repage', '-resize', f'{factor * 100:.8f}%', ')', '-geometry', f'{dx:+}{dy:+}',
                   '-compose', 'Over', '-composite', output)
            frames.append(output)
        output = TEMP / f'dust-row-{row}.png'
        magick(*frames, '+append', output)
        rows.append(output)
    magick(*rows, '-append', atlas)
    frames_resource(atlas, [
        ('land', [0, 1, 2, 3], 12.0, False),
        ('step', [4, 5, 6, 7], 14.0, False),
    ], 4, 128, destination / 'dust_frames.tres')
    magick(source, '-crop', geometry(cell(source, 1, 2, 4, 4)), '+repage',
           destination / 'mist.png')
    magick(source, '-crop', geometry(cell(source, 1, 3, 4, 4)), '+repage',
           '-trim', '+repage', '-resize', '16x16', '-background', 'none',
           '-gravity', 'center', '-extent', '20x20', destination / 'ash.png')


def continuous_ground() -> None:
    source = ASSETS / 'source/ground.png'
    width, height = dimensions(source)
    # Inspected source: the continuous pale walkable lip is at y=251/724,
    # not the nominal 10% in the prompt. Crop the full-width art, no tiling.
    top = round(height * 251 / 724)
    crop_height = round(width * 140 / 1600)
    magick(source, '-crop', geometry((0, top, width, crop_height)), '+repage',
           '-resize', '1600x140!', ASSETS / 'environment/ground.png')
    # A single retained painted slab supplies the existing 180x78 ledge.
    slab = ASSETS / 'environment/slab.png'
    width, height = dimensions(slab)
    alpha = subprocess.check_output(['magick', str(slab), '-alpha', 'extract',
                                     '-depth', '8', 'gray:-'])
    top = next(y for y in range(height)
               if sum(v > 220 for v in alpha[y * width:(y + 1) * width]) / width >= 0.80)
    _, ay, _, ah = bounds(slab, (0, 0, width, height))
    magick(slab, '-crop', geometry((4, top, width - 8, ay + ah - top)), '+repage',
           '-resize', '180x78!', ASSETS / 'environment/rubble.png')


def manifest() -> None:
    inputs = [*sorted((ASSETS / 'source').glob('*.png')),
              *sorted((ASSETS / 'backgrounds').glob('*.png')),
              ASSETS / 'reference/ash_and_porcelain.png']
    derivatives = [*sorted((ASSETS / 'characters').glob('*.png')),
                   *sorted((ASSETS / 'environment').glob('*')),
                   *sorted((ASSETS / 'vfx').glob('*')),
                   ROOT / 'game/player/player_frames.tres']
    def describe(path: Path) -> dict:
        data = path.read_bytes()
        result = {'path': str(path.relative_to(ROOT)), 'bytes': len(data),
                  'sha256': hashlib.sha256(data).hexdigest()}
        if path.suffix == '.png':
            result['dimensions'] = list(dimensions(path))
        return result
    result = {'style': 'Ash and Porcelain', 'generator': 'Built-in ChatGPT image generator',
              'reference': 'User-selected concept 1; original AI image',
              'inputs': [describe(p) for p in inputs],
              'derivatives': [describe(p) for p in derivatives if p.suffix != '.import'],
              'integration': 'ImageMagick mechanical crop, resize, translation and atlas packing only'}
    (ASSETS / 'generation_manifest.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    TEMP.mkdir(parents=True, exist_ok=True)
    (ROOT / 'work/.gdignore').touch()
    character()
    environment()
    effects()
    continuous_ground()
    manifest()
    print('Art resources extracted; retained sources are unchanged.')
