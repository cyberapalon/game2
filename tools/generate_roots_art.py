#!/usr/bin/env python3
"""Original etched SVG scenery. Explicit room compositions, no runtime generation."""
from pathlib import Path
import math
import random

ROOT = Path(__file__).resolve().parents[1]
if (ROOT / 'assets/source/route/route_props.png').exists():
    raise SystemExit('Historical SVG generator is archived. Use tools/build_route_art.py; active rooms must retain PNG artwork.')
ART = ROOT / 'world/roots/art'
ART.mkdir(parents=True, exist_ok=True)

DEFS = '''<defs>
<linearGradient id="air" x2="0.2" y2="1"><stop stop-color="#121f24"/><stop offset=".6" stop-color="#263a3b"/><stop offset="1" stop-color="#142627"/></linearGradient>
<linearGradient id="soil" x2="0" y2="1"><stop stop-color="#626354"/><stop offset=".12" stop-color="#3d443b"/><stop offset="1" stop-color="#171f21"/></linearGradient>
<linearGradient id="wood" x1="0" x2="1" y2=".7"><stop stop-color="#323a32"/><stop offset=".4" stop-color="#74705a"/><stop offset=".55" stop-color="#5b6050"/><stop offset="1" stop-color="#27332e"/></linearGradient>
<radialGradient id="glow"><stop stop-color="#b4d9b6" stop-opacity=".28"/><stop offset="1" stop-color="#789d8c" stop-opacity="0"/></radialGradient>
<linearGradient id="haze" x2="0" y2="1"><stop stop-color="#88a79a" stop-opacity="0"/><stop offset=".65" stop-color="#88a79a" stop-opacity=".12"/><stop offset="1" stop-color="#88a79a" stop-opacity="0"/></linearGradient>
</defs>'''

def write(name, w, h, body):
    (ART / f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{DEFS}{body}</svg>\n')

def path(d, fill='none', stroke='#1a2928', width=1, extra=''):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" {extra}/>'

COMPOSITIONS = {
 'landing': [(80,-50,170,270,320,490), (640,-90,400,150,520,470), (1220,-70,1000,220,1090,470)],
 'junction': [(170,-60,420,100,600,480), (950,-40,800,180,600,480), (1250,-60,1060,210,1120,470)],
 'hollow': [(80,-80,120,290,340,460), (1120,-40,1030,170,1180,480), (650,-100,540,60,820,170)],
 'seal': [(110,-90,380,190,660,480), (650,-100,700,270,660,480), (1180,-70,960,200,660,480)],
}
for idx, (name, roots) in enumerate(COMPOSITIONS.items()):
    rng = random.Random(310 + idx)
    parts = ['<path fill="url(#air)" d="M0 0H1280V540H0Z"/>']
    # Hand-placed receding cavern openings and strata.
    for x,y,rx,ry in [(210,280,190,230),(630,260,240,210),(1060,310,180,250)]:
        parts.append(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#182b2e"/>')
        parts.append(f'<ellipse cx="{x+30}" cy="{y+40}" rx="{rx*.7}" ry="{ry*.8}" fill="#213638"/>')
    for i in range(34):
        y = i*15
        parts.append(path(f'M0 {y} Q320 {y+45} 600 {y-15} T1280 {y+20}', stroke='#7b8973', extra='opacity=".065"'))
    for x in [230,600,1030]:
        parts.append(f'<ellipse cx="{x}" cy="330" rx="220" ry="210" fill="url(#glow)"/>')
    for x,y,cx,cy,ex,ey in roots:
        d = f'M{x} {y} Q{cx} {cy} {ex} {ey}'
        parts.append(path(d, stroke='#122221', width=82))
        parts.append(path(d, stroke='url(#wood)', width=68))
        for k in range(-22,26,7):
            parts.append(path(f'M{x+k} {y} Q{cx+k-9} {cy} {ex+k} {ey}', stroke='#c4b38a' if k<0 else '#182925', width=1.2, extra='opacity=".28"'))
        parts.append(path(f'M{cx} {cy} Q{cx-95} {cy+30} {cx-130} {cy+150}', stroke='#4b5746', width=10))
        parts.append(path(f'M{cx+8} {cy+10} Q{cx+100} {cy+15} {cx+120} {cy+90}', stroke='#56624c', width=7))
    parts.append(path('M0 0H1280V55Q1180 25 1060 64T800 40T550 65T320 35T0 80Z', '#152522'))
    for i in range(65):
        x = rng.randrange(1280); y = rng.randrange(24,95); length = rng.randrange(25,140)
        parts.append(path(f'M{x} {y} q-12 {length*.6} 5 {length}', stroke='#68705a', extra='opacity=".25"'))
    if name == 'landing':
        parts.append('<path d="M108 0H220L205 220 165 310 126 200Z" fill="#83978c" opacity=".13"/>')
        for y in range(10,225,23):
            parts.append(path(f'M150 {y}h34', stroke='#796f52', width=4))
        parts.append(path('M150 0V245M184 0V245',stroke='#494b3d',width=5))
    parts.append('<path d="M0 290H1280V470H0Z" fill="url(#haze)"/>')
    for i in range(115):
        x,y = rng.randrange(1280),rng.randrange(80,445)
        parts.append(f'<circle cx="{x}" cy="{y}" r="{rng.choice([.5,.7,1.1])}" fill="#b4baa0" opacity=".2"/>')
    write(name,1280,540,''.join(parts))
    front = [path('M0 460H1280V540H0Z','url(#soil)')]
    for i in range(160):
        x=rng.randrange(1280); y=rng.randrange(466,540)
        front.append(path(f'M{x} {y}l{rng.randrange(3,22)} -2',stroke='#a19972',extra='opacity=".14"'))
    for i in range(85):
        x=rng.randrange(1280); h=rng.randrange(5,25)
        front.append(path(f'M{x} 462q-5 -{h} -11 -{h+3}M{x} 462q3 -{h+6} 10 -{h+8}',stroke='#697d5a',width=1.4))
    for x in [320,760,1100]:
        front.append(f'<ellipse cx="{x}" cy="439" rx="55" ry="40" fill="url(#glow)"/>')
        for dx,h in [(-16,12),(0,22),(17,15)]:
            front.append(path(f'M{x+dx} 460v-{h}',stroke='#6d9481',width=2))
            front.append(f'<ellipse cx="{x+dx}" cy="{460-h}" rx="9" ry="3" fill="#b9c7a0"/>')
    write(name+'_front',1280,540,''.join(front))

write('platform',160,100,path('M0 1Q30 9 60 2T160 4V100H0Z','url(#soil)')+''.join(path(f'M{i} 4q-10 30 3 70',stroke='#b0a17a',extra='opacity=".16"') for i in range(5,160,14)))
write('portal',120,160,path('M12 158V76C12 3 108 3 108 76V158Z','#101f20','#606753',10)+path('M24 156V78C24 22 96 22 96 78V156','#09171c','#293d37',6)+path('M10 152q26-20 43 4M77 153q15-15 35-5',stroke='#828064',width=6))
write('shaft',240,280,path('M13 254L25 91 52 45 180 35 220 99 231 254Z','#34413e','#14272a',6)+path('M51 254V104Q118 33 189 104V254Z','#09171d','#7f7c67',12)+path('M26 70L196 48M18 86L217 62',stroke='#4e554b',width=10)+path('M104 121V259M139 121V259',stroke='#7f7152',width=4)+''.join(path(f'M103 {y}h36',stroke='#85775b',width=3) for y in range(130,265,21))+path('M8 262H234',stroke='#99947b',width=9)+path('M46 72l21-24M163 46l-13 21M209 101l-21 18',stroke='#abb19b',width=2))
write('npc',160,180,path('M30 164Q30 107 58 68L96 66Q128 105 129 164Z','#3b4948','#16282b',4)+path('M54 89Q75 101 103 87L119 153 84 143 57 162 39 156Z','#54605a')+path('M61 77L53 42Q79 8 108 43L98 78 77 87Z','#8e927f','#243a3d',4)+path('M65 48l29 7M68 65l18 3',stroke='#344744',width=3)+path('M43 110L22 169M19 168l9-6',stroke='#8d8164',width=5)+path('M110 115l22 7 6 33',stroke='#918263',width=3)+'<ellipse cx="137" cy="153" rx="22" ry="25" fill="url(#glow)"/><path d="M131 142h12v17h-12z" fill="#cfb57b"/>')
write('sealed_gate',240,400,path('M17 400V110Q115-60 222 110V400Z','#142326','#5c6654',16)+''.join(path(f'M{60+i*30} 70Q{30+i*35} 210 {65+i*30} 398',stroke='url(#wood)',width=28) for i in range(5))+path('M35 210Q115 290 211 188M37 310Q117 235 218 330',stroke='#7b7b5e',width=19)+path('M28 389H228',stroke='#9a9574',width=8))
write('keepsake',56,56,'<circle cx="28" cy="28" r="28" fill="url(#glow)"/>'+path('M13 35L25 11 43 32 29 45Z','#b5bfa2','#e1d7ad',2)+path('M20 32l14-10M24 37l12-9',stroke='#647c71',width=2))
print('Original roots SVG assets written')
