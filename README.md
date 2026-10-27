# Глубина

Законченный первый эпизод оригинального 2D action-platformer из [PRD](PRD.md).
Godot **4.6.3 standard**, GDScript, Compatibility; single-thread Web без GDExtensions.

Пролог на поверхности → шахта → ручная сеть «Корней» с развилкой и находкой →
два вида врагов и два очага памяти → босс «Сердце Корней» с двумя фазами →
Dash → разорванный свод → финальный спуск до **1.86 км** и экран завершения.
Есть здоровье, неуязвимость, смерть/возрождение, музыка, пауза и перезапуск.
Движение, устойчивый рисованный герой и переменный прыжок из PR #6 сохранены.
Весь маршрут и новые анимации используют оригинальные AI-PNG «Пепел и фарфор».

[Результаты и ограничения](docs/episode-one-report.md) ·
[Видео и скриншоты для приёмки](https://chatgpt.com/space/page_f5f265bc18e881918a3a913614c8c441).
Цель первого знакомства — 10–15 минут; человеческий замер длительности ещё нужен.

## Играть в браузере

**[Открыть «Глубину» в браузере](https://cyberapalon.github.io/game2/)**.
По этому адресу опубликован main. Версия текущего PR появится после его отдельного слияния и успешного deployment.

После обновления `main` GitHub Actions самостоятельно собирает и публикует
Web-версию. Также доступен ручной запуск workflow **Build and publish Web game**.
Устанавливать Godot/Python или скачивать архив для игры на Pages не требуется.
Настройка, версии и диагностика: [GitHub Pages](docs/pages.md).

Щёлкни по игре. **A/D или ←/→** — движение, **Пробел** — прыжок,
**J/X** — атака, **E** — действие, **Esc** — пауза, **M** — звук.
После босса **Shift** даёт рывок; над финальной пропастью нужен прыжок с рывком.
Короткое нажатие Space — прыжок около 50 px, удержание — около 93 px;
есть coyote time и jump buffer по 0.1 s.
Начни с пути вправо; у NPC и входов появляется подсказка. На развилке
можно подняться по уступам в верхнюю нору или продолжить вправо.
Секрет сохраняется только до перезагрузки страницы; инвентаря/сохранений нет.

## Запуск в подготовленном Codex Cloud

Нужна опубликованная среда, описанная в [toolchain](docs/toolchain.md).
Команды выполняются из корня `game2`; зависимости не устанавливаются:

```bash
source /workspace/.godot-cloud/env.sh
godot --version
godot --editor --path . --import --headless
godot --path .
```

Последняя команда предназначена для машины с дисплеем. В headless Cloud
играть нужно через Web-сборку в браузере:

```bash
source /workspace/.godot-cloud/env.sh
python3 tools/validate.py build
python3 /workspace/.godot-cloud/serve_web.py "$PWD/build/web"
```

Открой `http://127.0.0.1:8765/index.html` в браузере с доступом к этому
loopback-порту. Удалённый Cloud-порт сам по себе не является публичной ссылкой;
для игры вне Cloud используется GitHub Pages (ссылка и настройка выше). Из исходников можно
перенести каталог `build/web` и запустить HTTP-сервер локально; `file://` не подходит.
Щёлкни по игре для фокуса. **A/D или ←/→** — движение, **Пробел** — прыжок
с земли; отпускание направления останавливает героя. Глубина не меняется
от прыжков на поверхности. В редакторе — запуск главной сцены через F6/F5
после открытия `world/surface/surface.tscn` / проекта.

## Проверки и сборки

```bash
source /workspace/.godot-cloud/env.sh
# Целевые игровые тесты (с импортом).
python3 tools/validate.py unit --suite res://tests/player_test.gd
# Web, Windows x86_64, Linux x86_64; чистый build/, manifest и Linux smoke.
python3 tools/validate.py build
# Реальные клавиши в Chromium; использует текущую Web-сборку.
python3 tools/validate.py e2e
# Перед PR: чистый импорт, skills, все .gd, GdUnit4, smoke, три экспорта, E2E.
python3 tools/validate.py all
```

`build/manifest.json` фиксирует исходный commit, состояние checkout, версию,
команды, hash пресетов и SHA-256 артефактов. `build` очищает только `build/`,
`check`/`all` пересоздают `.godot/`; исходники не удаляются.
Логи и свежий XML GdUnit4 лежат в `reports/validation-*` и `reports/gdunit-*`.
Playwright сохраняет JSON, `idle.png`, `run.png`, `jump.png`, `surface.png`,
`rubble.png`, `ruins.png` и координаты из реальной
физики в `reports/web/`. Ошибки в engine log, пустой XML и пропущенные тесты
считаются провалом. Полный runbook: [validation](docs/validation.md).

Выходы: `build/web/index.html`, `build/windows/depth.exe`,
`build/linux/depth.x86_64`. Windows export не подтверждает запуск на Windows.
Для запуска Linux: `./build/linux/depth.x86_64` на машине с дисплеем.

## Структура и границы

- `game/player/` — контроллер движения и боя; `game/combat/`, `game/enemies/`, `game/boss/` — настройки, враги и босс.
- `world/surface/` — поверхность и координатор маршрута; один игрок и смена комнат.
- `world/roots/` — четыре комнаты Корней и короткий финальный участок; `world/rooms/` — контракт комнаты.
- `world/interactions/` — триггеры и короткий линейный диалог.
- `ui/` — отображение глубины и подсказки управления.
- `tests/` — GdUnit4 и Web E2E; `tools/` — команды валидации.
- `addons/gdUnit4/` — неизменённый upstream GdUnit4 6.2.2, лицензия MIT.
- [План MVP](tasks/plan.md) и [список задач](tasks/todo.md).

Слои коллизий: **1 — World**, **2 — Player**, **4 — Enemies** (бит 3).
Герой сталкивается с миром; Strike Area видит врагов, вражеские атаки — героя.
Тело босса имеет World + Enemies (5), чтобы перекрывать дорогу до гибели.
Экспорты включают главную сцену и её зависимости, без addon и тестов;
содержимое Web PCK проверяется отдельно. Настройки движения —
`game/player/player_settings.tres`, единицы — пиксели и секунды.

E2E использует только `page.keyboard`, наблюдая за фактическими координатами
через read-only `window.__depthE2E`, включаемый только URL `?e2e=1`.
В обычном запуске этот объект не создаётся; интерфейса для управления через
JavaScript нет. Снимки и отсутствие ошибок не заменяют проверку координат.

Вручную ещё нужно оценить читаемость персонажа и HUD, ощущение прыжка,
скорость и комфорт движения камеры на реальном устройстве. Chromium в Cloud
использует software WebGL: это функциональная проверка, не GPU-бенчмарк.
Windows runtime, Safari/Firefox и мобильные устройства не проверены.
Остальные биомы, сохранения между запусками, мультиплеер и процедурная генерация не входят в эпизод.

## Управление в фазе 2

`PlayerSettings` сохраняет скорость **240 px/s**, gravity **1400 px/s²**;
jump_speed равна **500 px/s**. При 60 Hz высота прыжка выросла
примерно с 79 до 94 px: уступ высотой 78 px теперь имеет запас около 16 px.
Полёт с возвращением на пол длится около 0.73 s. Разгон/торможение остаются
мгновенными; коллизии сохранены. Добавлены переменная высота прыжка,
coyote time и jump buffer по 0.1 s.

Для проверки: пройди вправо, прыгни на край бетонного обломка, остановись,
развернись и спрыгни обратно. В Web E2E этот маршрут выполняется реальными
клавишами. Отчёт фазы: [phase-2-report](docs/phase-2-report.md).

## Проверка маршрута фазы 3

```bash
source /workspace/.godot-cloud/env.sh
python3 tools/validate.py unit --suite res://tests/route_test.gd
# После экспорта: только полный маршрут в браузере.
GODOT_WEB_DIR="$PWD/build/web" playwright test --config tests/web/playwright.config.cjs route.spec.cjs
# Единственный полный прогон перед PR:
python3 tools/validate.py all
# Упаковка уже проверенных результатов, без повторной сборки:
python3 tools/package_web.py
```

Карта и результат проверок: [phase-3-report](docs/phase-3-report.md).

## Художественная ревизия Пепел и фарфор

Полные AI-исходники и prompts сохранены; механическое извлечение —
`tools/build_art_resources.py`. Происхождение: [ASSET_PROVENANCE](ASSET_PROVENANCE.md).
Отчёт: [art-revision-report](docs/art-revision-report.md).
Маршрут фазы 3 и публикация GitHub Pages из main сохранены. Подземные
сцены, NPC, входы, находка и закрытый проход полностью переведены на PNG.
Герой использует одну устойчивую составную иллюстрацию; бег привязан
к пройденному расстоянию. Отчёт доработки: [route-art-review](docs/route-art-review.md).
