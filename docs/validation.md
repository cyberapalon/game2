# Проверки по стадиям проекта

Все команды ниже выполняются из корня репозитория после
`source /workspace/.godot-cloud/env.sh`. У длительных процессов используй
конечный timeout. Проверяй код завершения **и** лог: `SCRIPT ERROR`,
`Parse Error` и строки `ERROR:` делают шаг неуспешным даже при exit 0.
При pipe в `tee` включай `set -o pipefail`, иначе можно потерять код Godot.

В начале проверяемого запуска:

```bash
mkdir -p work /workspace/.godot-cloud/build
check_run_id=$(date -u +%Y%m%dT%H%M%S)-$$
```

## Команды текущего проекта

После `source /workspace/.godot-cloud/env.sh`:

```bash
python3 tools/validate.py unit --suite res://tests/player_test.gd
python3 tools/validate.py build
python3 tools/validate.py e2e
python3 tools/validate.py all
```

`all` выполняет перечисленные ниже проверки игрового проекта: пересоздаёт
`.godot/`, проверяет реальный skills loader, все собственные `.gd`, main smoke,
все GdUnit4 suites, три чистых release-экспорта, содержимое Web PCK, Linux smoke
и все три Web E2E. `unit`/`build` сначала выполняют импорт; `e2e` использует текущий
`build/web`. `build` очищает `build/`. Все шаги ограничены timeout, проверяют
exit code и engine errors. GdUnit XML должен быть свежим и непустым,
без failures/errors/skipped; Playwright JSON — без unexpected/skipped/flaky.

Двенадцать GdUnit4 tests покрывают покой на полу, движение/остановку, прыжок/запрет
прыжка в воздухе/приземление, стены, падение с уступа, независимость глубины,
InputMap, сброс ввода при потере фокуса, idle/run, сохранение разворота,
jump/fall/приземление, импорт кадров и прыжок на существующий уступ. Web E2E проверяет WASM/WebGL2,
физические координаты после A/D и стрелок, остановку, Space, удержание Space
до приземления, потерю и возврат фокуса canvas без залипания ввода. Второй
тест проходит маршрут до уступа и правой границы, проверяет посадку и параллакс.
Третий тест проверяет обычный запуск без E2E bridge. Screenshot не заменяет assertions.

Проектная конфигурация `tests/web/playwright.config.cjs` переиспользует
подготовленный Cloud config, задаёт viewport 960×540 и сохраняет отчёты в
`reports/web/`. URL `?e2e=1` включает только чтение фактической физики через
`window.__depthE2E`, без команд для симуляции управления.

Логи: `reports/validation-*`; XML: `reports/gdunit-*`; browser JSON/screenshots:
`reports/web/`; commit/версии/команды/hashes: `build/manifest.json`.
Скриншоты и артефакты не коммитятся. Ручные критерии: читаемость HUD и героя,
ощущение прыжка, скорость, комфорт камеры на реальном устройстве. Windows
runtime и другие браузеры требуют отдельного устройства/прогона.

## Исторический baseline: только конфигурация

Во время правки навыков:

```bash
python3 tools/check_codex_skills.py --output work/skills-discovery.json
git diff --check
```

Скрипт открывает локальный Codex app-server, выполняет `initialize`,
`initialized`, `skills/list` с `forceReload=true` для текущего checkout и
проверяет имена, пути, enabled и ошибки **реального** loader. Обычный каталог
Codex в подготовленной Cloud-среде read-only, поэтому дочерний процесс получает
отдельный временный configuration directory внутри `work/`; настройки
родительского процесса не меняются, credentials не копируются. Скрипт не
начинает thread/model turn и не запускает MCP server. Установки зависимостей
нет. Это проверка обнаружения,
а не доказательство качества ответов или автоматического выбора skill моделью.
Список skills в уже открытом чате может обновиться только с новой сессией.

Перед завершением конфигурационной задачи дополнительно:

```bash
python3 -m json.tool docs/toolchain-lock.json > /dev/null
python3 /workspace/.godot-cloud/validate.py
git diff --check
git status --short
```

`validate.py` создаёт техническую Control-сцену вне checkout. Он проверяет
импорт/скрипты, 2 теста GdUnit4, три release-экспорта, Linux headless run и
WebGL/мышиный ввод через Playwright Chromium. Клавиатура будущей игры этим
probe не проверяется. Результаты и логи:
`/workspace/.godot-cloud/validation/results.json` и соседние файлы.
Это полный набор для **инфраструктуры**, не тесты «Глубины».

## Проверки игрового проекта

В проекте существуют `project.godot` с main scene, свои `.gd`,
подключён закреплённый GdUnit4, есть `tests/` и три пресета в
`export_presets.cfg`.

Для маленькой итерации сначала импорт, затем затронутый скрипт:

```bash
timeout 180 godot --headless --editor --path . --import
# Пример пути; подставь существующий затронутый скрипт.
timeout 60 godot --headless --path . --check-only --script res://game/player/player.gd
```

Затем связанная suite:

```bash
timeout 120 godot --headless --path . \
  --script res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a res://tests/player_test.gd \
  -rd "reports/targeted-$check_run_id"
```

У 6.2.2 параметры runner идут **без** разделителя `--`. `-a` принимает
suite или каталог; `-rd` должен быть относительным. Проверь новый
`results.xml` внутри указанного каталога: tests > 0, failures/errors = 0;
skipped явно объясняются. Не используй отчёт предыдущего запуска.
Не вызывай GdUnit4 из `.godot-cloud` как будто он уже установлен в игру.

Для изменения ввода/UI/анимаций добавь связанные Web E2E после экспорта.
Проектные tests уже находятся в `tests/player_test.gd` и `tests/web/`.

## Полный набор перед завершением игровой задачи

1. `python3 tools/check_codex_skills.py`, просмотр diff и `git diff --check`.
2. `python3 /workspace/.godot-cloud/check_project.py .`: импорт и проверка
   **всех** собственных `.gd`, включая тесты. Helper исключает addons/cache/
   build/reports, требует хотя бы один `.gd`, проверяет и логи, и exit code.
3. Весь каталог GdUnit4: предыдущая команда runner с `-a res://tests` и
   новым `-rd "reports/full-$check_run_id"`. Если нужно пройти все тесты даже
   после первого failure, используй поддерживаемый `-c`.
4. `timeout 60 godot --headless --path . --quit-after 60`: main-scene smoke.
   Он проверяет загрузку и engine errors, но не успешное прохождение игры.
5. Чистый release Web export и все существующие проектные Web E2E.
6. Windows/Linux export — если эти пресеты введены в проект или затронут
   соответствующий pipeline. Linux runtime smoke после его экспорта;
   Windows runtime проверяется отдельно на Windows.
7. В отчёте перечисли применимость, результаты и ручные проверки управления.
   Отсутствующий проект/тест/preset — «не применимо» или блокер задачи,
   не успешный результат. Игра не готова по одному инфраструктурному probe.

## Release Web и браузер

```bash
check_build_dir=$(mktemp -d /workspace/.godot-cloud/build/check-XXXXXXXX)
mkdir -p "$check_build_dir/web"
timeout 240 godot --headless --path . --export-release Web "$check_build_dir/web/index.html"
GODOT_WEB_DIR="$check_build_dir/web" GODOT_E2E_DIR="$PWD/tests/web" \
  timeout 120 playwright test --config /workspace/.godot-cloud/playwright.config.cjs
```

Export preset `Web` должен использовать
`gl_compatibility`, без threads и GDExtensions. Конфигурация Playwright сама
управляет loopback-сервером 8765; не запускай второй сервер одновременно.
Сервер отдаёт `application/wasm` и COOP/COEP. Для single-thread Web эти isolation
headers не обязательны, но подготовленный сервер их добавляет.

Проектные `.spec.cjs` импортируют подготовленный runner:

```javascript
const { test, expect } = require('/workspace/.godot-cloud/tools/browser/node_modules/@playwright/test');
```

Это конкретный Cloud path, не переносимая npm-конфигурация. При переносе
pipeline введи project-level package.json/package-lock отдельным изменением,
а не устанавливай второй экземпляр Playwright в текущем окружении.

E2E должны проверять canvas, отсутствие page/engine errors, загрузку ресурсов
и конкретное изменение состояния после ввода. Скриншот сравнивай/просматривай
на согласованном viewport; обновление golden не должно маскировать регрессию.
Базовый образец инфраструктуры:
`/workspace/.godot-cloud/validation/e2e/environment.spec.cjs`.

## Дополнительные native-пресеты

В проекте настроены пресеты Windows и Linux:

```bash
mkdir -p "$check_build_dir/windows" "$check_build_dir/linux"
timeout 240 godot --headless --path . --export-release Windows "$check_build_dir/windows/game.exe"
timeout 240 godot --headless --path . --export-release Linux "$check_build_dir/linux/game.x86_64"
chmod +x "$check_build_dir/linux/game.x86_64"
timeout 60 "$check_build_dir/linux/game.x86_64" --headless --quit-after 60
find "$check_build_dir" -type f -exec sha256sum {} + > "work/build-sha256-$check_run_id.txt"
```

Windows на Linux: `application/modify_resources=false`, `codesign/enable=false`.
Wine, rcedit, подпись и запуск на Windows не входят в этот workflow.
Для отчёта также сохрани `git rev-parse HEAD`, `godot --version`, preset/options
и сведения о локальных изменениях, если сборка сделана не из чистого commit.
