#!/usr/bin/env python3
"""Extract inspected AI-painted frames. Never draws or invents artwork."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/combat'
SOURCE = ROOT / 'assets/source/combat'


def run(*args):
    subprocess.run(['magick', *map(str, args)], check=True)


def main():
    OUT.mkdir(exist_ok=True)
    manifest = {'origin': 'Built-in ChatGPT image generation; original Ash and Porcelain references only', 'assets': {}}
    # The generated grids were inspected at native resolution. Keep one scale
    # per character; alpha-trimming never changes the size of individual poses.
    for name, rows, scale, canvas, baselines in [
        ('kornevik', ['idle', 'move', 'attack', 'hurt', 'death'], .34, (128, 128), [274, 535, 832, 1096, 1350]),
        ('sporon', ['idle', 'move', 'attack', 'hurt', 'death'], .34, (128, 128), [274, 550, 837, 1120, 1382]),
        ('heart', ['idle', 'slam', 'storm', 'hurt', 'death'], 1.02, (400, 360), [284, 560, 840, 1122, 1383]),
        ('hero', ['attack', 'hurt', 'death'], .20, (128, 100), [366, 717, 1034]),
    ]:
        source = SOURCE / (name + '.png')
        width, height = map(int, subprocess.check_output(['magick', 'identify', '-format', '%w %h', str(source)], text=True).split())
        resources = []
        clips = []
        for row, clip in enumerate(rows):
            frames = []
            y0 = round(row * height / len(rows))
            y1 = round((row + 1) * height / len(rows))
            for col in range(4):
                x0, x1 = round(col * width / 4), round((col + 1) * width / 4)
                dest = OUT / f'{name}_{clip}_{col}.png'
                # Each cropped cell is uniformly scaled into a fixed canvas,
                # ground pivot (canvas.x/2, canvas.y-8), not individually fitted.
                tile_w, tile_h = round((x1 - x0) * scale), round((y1 - y0) * scale)
                left = round(canvas[0] / 2 - (width / 8) * scale)
                top = round(canvas[1] - 8 - (baselines[row] - y0) * scale)
                run(source, '-crop', f'{x1-x0}x{y1-y0}+{x0}+{y0}', '+repage',
                    '-resize', f'{tile_w}x{tile_h}!', '-background', 'none',
                    '-gravity', 'NorthWest', '-splice', f'{max(left, 0)}x{max(top, 0)}',
                    '-extent', f'{canvas[0]}x{canvas[1]}', '-strip', dest)
                ident = f'f{row}_{col}'
                resources.append(f'[ext_resource type="Texture2D" path="res://assets/combat/{dest.name}" id="{ident}"]')
                frames.append('{"duration": 1.0, "texture": ExtResource("' + ident + '")}')
            fps = 8 if clip in ('idle', 'move') else (12 if clip == 'attack' else 5)
            clips.append('{"frames": [' + ', '.join(frames) + '], "loop": ' + str(clip in ('idle', 'move')).lower() + f', "name": &"{clip}", "speed": {fps}.0' + '}')
        frames_path = OUT / (name + '_frames.tres')
        frames_path.write_text('[gd_resource type="SpriteFrames" format=3]\n\n' + '\n'.join(resources) + '\n\n[resource]\nanimations = [' + ',\n'.join(clips) + ']\n')
        manifest['assets'][name] = {'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'grid': [4, len(rows)], 'canvas': canvas, 'pivot': [canvas[0]/2, canvas[1]-8], 'scale': scale, 'baselines': baselines}
    # The replacement slash sheet has separated, irregularly spaced figures.
    # Inspected alpha components: 431x446+46+147, 565x441+575+154,
    # 561x436+1163+159, 370x449+1744+146. These explicit cuts keep the
    # complete blade arcs; slicing a nominal regular grid would clip them.
    source = SOURCE / 'hero_attack.png'
    bounds = [0, 543, 1153, 1734, 2172]
    anchors = [282, 826, 1370, 1933]
    for index in range(4):
        left, right = bounds[index:index+2]
        width = round((right-left) * .125)
        offset = round(64 - (anchors[index] - left) * .125)
        run(source, '-crop', f'{right-left}x724+{left}+0', '+repage',
            '-resize', f'{width}x91!', '-background', 'none', '-gravity', 'NorthWest',
            '-splice', f'{offset}x18', '-extent', '128x100', '-strip',
            OUT / f'hero_attack_{index}.png')
    manifest['assets']['hero_attack'] = {'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'bounds': bounds, 'anchors': anchors, 'scale': .125, 'baseline': 595, 'pivot': [64, 92]}
    source = SOURCE / 'ending.png'
    run(source, '-resize', '1536x864!', '-strip', OUT / 'ending.png')
    manifest['assets']['ending'] = {'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'purpose': 'Non-playable final still; hint only, not another biome'}
    manifest['derivatives_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.iterdir()) if p.suffix in ('.png', '.tres')}
    (ROOT / 'assets/combat_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
