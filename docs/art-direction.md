# Фаза 2: «Пепельный прилив»

Оригинальная рисованная поверхность Земли: стёртый бетон, остатки железной
дороги, разрушенная радиообсерватория и холодная воздушная перспектива.
Серо-синие и землистые оттенки, тёплый просвет в облаках и один янтарный
фонарь. Hollow Knight используется только как ориентир меланхолии;
его графика, персонажи и узнаваемые формы масок не используются.

Герой — маленький странник с асимметричной слоистой керамической маской,
одной боковой прорезью, трещиной и потёртым синим плащом. Охристый шарф,
светлая маска и светлый край ткани отделяют силуэт от руин. Маска без рогов,
силуэт и рисунки созданы для этого проекта.

## Источники и воспроизведение

Все новые ассеты созданы в этой задаче для `cyberapalon/game2`; сторонние
ассеты, stock-изображения и платные asset-сервисы не подключались.
Новых лицензионных ограничений со стороны автора программной SVG-графики нет;
использование вместе с проектом разрешено. Панорама — результат встроенного
генератора изображений ChatGPT; отдельный API или ключ не использовался.

| Ресурс | Источник и формат | Импорт / использование |
| --- | --- | --- |
| `world/surface/art/panorama.png` | Встроенная генерация, исходный PNG **2172×724**, без редактирования | Непрозрачный фон, линейная фильтрация, затемнение через modulate; около 1600×540 в мире |
| `game/player/art/*.svg` | Оригинальные кривые и градиенты, `tools/generate_surface_art.py` | RGBA, **128×128**, scale 0.5, pivot (64,64), стопы (64,108); прозрачные поля |
| `earth.svg` / `rubble.svg` | Тот же детерминированный генератор | **1600×140** / **180×78** (коллизия уступа 180×24), верхние левые pivots; край пола y=420, уступа y=342 |
| `ruins.svg` / `foreground.svg` | Оригинальные SVG, штриховка и сколы | **1800×540**, прозрачный фон; отдельные Parallax2D |
| `mist.svg` / `mote.svg` | Оригинальные SVG с прозрачными градиентами | **1800×180** / **16×16**, без дорогих lights и shaders |

Воспроизведение SVG и `player_frames.tres` из корня:

```bash
python3 tools/generate_surface_art.py
```

Генератор использует только Python stdlib и фиксированный seed 71; PNG
панорамы не перезаписывает. SVG являются редактируемыми исходниками и
импортируются штатным Godot SVG importer. Импортные `.import` сохраняются.
Нет atlas bleeding: каждый кадр — отдельная текстура с прозрачными полями.
Для анализа можно выполнить `magick identify world/surface/art/panorama.png`.

## Анимации и планы

`AnimatedSprite2D` + `player_frames.tres`: idle — 6 кадров / 6 FPS,
run — 8 / 12 FPS, jump и fall — по 2 / 6 FPS, все loop.
Одинаковый canvas и pivot; ноги, плащ и шарф меняют позу.
Положительная/отрицательная вертикальная скорость выбирает fall/jump;
после приземления выбирается idle или run. `flip_h` следует направлению
движения и сохраняется в покое. Единственный владелец движения тела —
`player.gd`, `_physics_process`; анимации не меняют transform/velocity/коллизии.

Parallax2D: панорама 0.48, близкие руины 0.85, передний план 1.08;
вертикальный масштаб прокрутки 1, чтобы прыжок не отрывал рисунок пола
от коллизий. Передний план ниже игровой дорожки. Дымка медленно дрейфует;
28 полупрозрачных частиц пепла работают через CPUParticles2D.
HUD — отдельный CanvasLayer, фиксированная глубина комнаты 0.00 км.

## Prompt панорамы

Запрошен широкий исходник 3072×1024; генератор вернул 2172×724, пропорция 3:1.
Точный текст запроса:

> Create an original production-quality hand-painted 2D side-scrolling game BACKGROUND asset, wide panoramic landscape 3072x1024 or widest possible landscape. NO pixel art, NO characters, NO typography, NO interface, NO watermarks. Art direction: 'Ash tide' ruined surface of EARTH after an ancient catastrophe. Sublime melancholy, beautiful eerie silence. Muted slate-blue and weathered earthy gray, dusty teal mist, very sparse amber glimmers. Ink contours, layered gouache washes and etched architectural detail, subtle paper tooth. A huge collapsed circular radio observatory structure towards the RIGHT third, recognizably human ruined concrete residential towers with broken windows on left, crushed elevated railway arches, bent antennae, enormous pale clouded sky occupying upper half, pale faint light shafts. Lower half is layers of receding rubble hills and atmospheric ground mist, disappearing into a dark desaturated slate-blue lower edge. Side-on orthographic theatrical scenery, traversable gameplay floor will be added separately along y=80% so DO NOT draw any obvious playable platforms. Make the middle lower region calm and luminous mist, for a small ivory-mask character to read. Foreground is NOT present, no big black silhouettes close to viewer. Moody, sophisticated illustrative cinematic composition, neither realistic 3D render nor flat geometric vector, absolutely original buildings and environment.
