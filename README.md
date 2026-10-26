# Глубина

Первый запускаемый каркас оригинального 2D-платформера из [PRD](PRD.md).
Godot **4.6.3 standard**, GDScript, Compatibility; Web — single-thread,
без GDExtensions. Это технический этап, а не готовое MVP.

На поверхности есть пол, ограничители комнаты, небольшой уступ из обломков,
персонаж с коллизией, следующая за ним камера и глубина **0.00 км**.
Доступны только движение и прыжок. Все формы временные, звука и анимаций нет.

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
публикация/туннель в этот этап не входят. Можно перенести каталог `build/web`
на локальную машину и запустить HTTP-сервер там; `file://` не подходит.
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
Playwright сохраняет JSON, `surface.png`, `jump.png` и координаты из реальной
физики в `reports/web/`. Ошибки в engine log, пустой XML и пропущенные тесты
считаются провалом. Полный runbook: [validation](docs/validation.md).

Выходы: `build/web/index.html`, `build/windows/depth.exe`,
`build/linux/depth.x86_64`. Windows export не подтверждает запуск на Windows.
Для запуска Linux: `./build/linux/depth.x86_64` на машине с дисплеем.

## Структура и границы

- `game/player/` — сцена, контроллер и неизменяемые настройки движения.
- `world/surface/` — комната, окружение и камера; владеет глубиной поверхности.
- `ui/` — отображение глубины и подсказки управления.
- `tests/` — GdUnit4 и Web E2E; `tools/` — команды валидации.
- `addons/gdUnit4/` — неизменённый upstream GdUnit4 6.2.2, лицензия MIT.
- [План MVP](tasks/plan.md) и [список задач](tasks/todo.md).

Слои коллизий: **1 — World** (пол, уступ, границы), **2 — Player**.
Маска мира — 2, маска героя — 1; лишних слоёв нет.
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
Windows runtime, Safari/Firefox, мобильные устройства и звук не проверены.
Врагов, боя, NPC, сюжетных сцен и подземных биомов на этом этапе нет.
