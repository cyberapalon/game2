# Игра в GitHub Pages

Опубликованная игра: https://cyberapalon.github.io/game2/.
Открывается сама игра, без скачивания ZIP, установки Godot или локального сервера.
Щёлкните по canvas: A/D или стрелки — движение, Space — прыжок, E — взаимодействие.

## Автоматическая сборка

`.github/workflows/pages.yml` собирает Web при push в `main`, проверяет сборку
в pull requests и допускает ручной запуск через Actions → Build and publish Web game
→ Run workflow. Публикация выполняется только для `main`.

Godot standard и export templates берутся из `docs/toolchain-lock.json`:
**4.6.3**, SHA-512 каждого официального архива проверяется до запуска.
Скрипт `tools/build_web_ci.py` использует только Python stdlib; prepared Cloud
не нужен. Hosted runner — `ubuntu-24.04`, исходное Cloud-окружение не меняется.
Шаблоны устанавливаются в отдельный XDG-каталог; из архива извлекается только
необходимый `web_nothreads_release.zip`. Выполняются импорт, чистый Web-экспорт
и проверка PCK на наличие всех комнат и отсутствие addons/tests.

Готовые файлы передаются через официальный Pages artifact и deploy-pages;
готовые сборки не коммитятся в исходный Git. Версии GitHub Actions закреплены
полными commit SHA. Разрешения публикации: `pages: write`, `id-token: write`;
checkout имеет только `contents: read`. Дополнительный PAT не требуется.
`build-info.json` опубликованной сборки содержит source commit, версию движка
и SHA-256 экспортированных файлов. `.nojekyll` отключает обработку Jekyll.
Однопоточный Web не требует COOP/COEP, которых GitHub Pages не выставляет.

## Первое включение Pages

В репозитории: Settings → Pages → Build and deployment → Source → **GitHub Actions**.
Это однократная настройка GitHub. Если сайт ещё не включён, configure-pages
не может самостоятельно создать его с обычным `GITHUB_TOKEN`.
При первоначальном включении GitHub API вернул HTTP 403
`Resource not accessible by integration`. Владелец однократно выбрал GitHub Actions
в настройках Pages; после этого повтор только job публикации прошёл успешно.
[Первая публикация](https://github.com/cyberapalon/game2/actions/runs/40401282144/attempts/2)
использовала уже собранный artifact, без повторной сборки.

## Проверка без GitHub

```bash
python3 tools/build_web_ci.py --tool-dir work/pages-toolchain --output-dir build/pages
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/pages
```

Для подготовленного Cloud можно не скачивать архивы повторно:
`--archive-dir /workspace/.godot-cloud/downloads`. SHA-512 проверяется и у
существующих архивов. Вся установка остаётся в `--tool-dir`.

Локальная проверка публикации выполняется на обычном Python HTTP-сервере
из подпапки `/game2/`, без COOP/COEP: полный Web-маршрут реальными клавишами,
все четыре комнаты, секрет, закрытый проход и возвращение на поверхность.
Это проверка совместимости раздачи со статическим Pages; доступность реального
URL проверяется отдельно после включения сайта и успешного deploy.

Команда повторения проверки в подготовленном Cloud (после `source /workspace/.godot-cloud/env.sh`):

```bash
python3 tools/build_web_ci.py --archive-dir /workspace/.godot-cloud/downloads --tool-dir work/pages-toolchain --output-dir build/pages-preview/game2
GODOT_WEB_DIR="$PWD/build/pages-preview" playwright test --config tests/web/pages.config.cjs
```

Первый статический прогон обнаружил 404 при запросе корневого `/favicon.ico`.
Экспорт для Pages теперь указывает относительный `./index.png`, поэтому браузер
использует иконку из подпапки игры. Обычный Godot Web-пресет не меняется.

Проверка после исправления иконки прошла: **1/1 полный Web-маршрут**,
без unexpected/skipped/flaky; импорт, SHA-512, Web-экспорт и PCK также прошли.

## Проверка опубликованной версии

Первая опубликованная версия: source commit
`0024f61742a0fb25f613df9e2c79051eb423b7ee`, Godot 4.6.3. HTTPS-запросы к HTML,
JavaScript, WASM, PCK, worklets и иконке получили 200; SHA-256 всех восьми
файлов совпали с опубликованным `build-info.json`. Полный маршрут реальными
клавишами дополнительно проверен на скачанных с Pages файлах, раздаваемых
из `/game2/` без COOP/COEP. Прямой браузерный HTTPS-прогон из Cloud ограничен
доверием Chromium к сертификату прокси; HTTP-проверки выполняют обычную
проверку TLS и контрольных сумм без отключения проверки сертификатов.
