#!/usr/bin/env python3
"""Encode actual Web E2E recording frames with the pinned system FFmpeg."""
from pathlib import Path
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'work/route-review'


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for recording in (ROOT / 'reports/web/artifacts').rglob('*-recording.json'):
        data = json.loads(recording.read_text())
        name = data['name']
        directory = recording.parent
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                        '-f', 'concat', '-safe', '0', '-i', str(directory/f'{name}.concat'),
                        '-fps_mode', 'vfr', '-c:v', 'libx264', '-preset', 'fast',
                        '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                        str(OUTPUT/f'{name}.mp4')], check=True)
        # Sample each rendered pose interval across the whole recording for
        # frame-by-frame inspection. Crop around the real, observed hero.
        frames, samples = data['frames'], data['samples']
        if not samples:
            continue
        crops = []
        count = len(frames)
        for i in range(count):
            frame = frames[round(i*(len(frames)-1)/max(1,count-1))]
            sample = min(samples, key=lambda s: abs(s['time']-frame['timestamp']))
            x = max(0,min(840,round(sample['screen_x'])-60))
            y = max(0,min(420,round(sample['screen_y'])-65))
            target = OUTPUT/f'{name}-pose-{i:02}.png'
            subprocess.run(['magick', str(directory/frame['file']), '-crop', f'120x120+{x}+{y}',
                            '+repage', '-strip', str(target)], check=True)
            crops.append(str(target))
        # Inspect EVERY captured frame, paginated at native pixels. No
        # invented in-betweens, omitted poses, or animation frame interpolation.
        for page, start in enumerate(range(0,len(crops),60),1):
            subprocess.run(['magick','montage', *crops[start:start+60], '-tile', '10x',
                            '-geometry', '120x120+2+2', '-background', '#141e29',
                            str(OUTPUT/f'{name}-poses-{page:02}.png')],check=True)
        if name == 'jumps':
            for kind in ['short','full']:
                candidates = [s for s in samples if s.get('jump_kind')==kind]
                apex = min(candidates,key=lambda s:s['y'])
                frame = min(frames,key=lambda f:abs(f['timestamp']-apex['time']))
                subprocess.run(['magick',str(directory/frame['file']),'-strip',
                                str(OUTPUT/f'{kind}-jump.png')],check=True)
    # Retain the actual full-route screenshots and measured motion evidence.
    desired = {'surface-with-npc.png':'surface-with-npc.png','roots-landing.png':'landing.png',
               'roots-junction.png':'junction.png','roots-hollow.png':'hollow.png',
               'roots-seal.png':'seal.png','closed-passage.png':'closed-passage.png',
               'secret.png':'keepsake.png','mine-entrance.png':'mine-entrance.png',
               'quality-metrics.json':'quality-metrics.json'}
    for filename,destination in desired.items():
        matches=list((ROOT/'reports/web/artifacts').rglob(filename))
        if matches:
            shutil.copy2(matches[-1],OUTPUT/destination)
    print('Review media encoded from real browser frames:',OUTPUT)


if __name__=='__main__':
    main()
