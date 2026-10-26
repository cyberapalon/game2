# Инструменты и облачное окружение

Состояние проверяется для `/workspace/game2` 26 октября 2026 года.
До этой настройки репозиторий содержал только `PRD.md`, commit
`fc47decd87c30d98972de1660eab580829fa23f3`. Инициализация проекта выполнена
следующим этапом; текущие команды — в [README.md](../README.md).

## Что доступно

| Инструмент | Зафиксированная / наблюдаемая версия | Назначение и границы |
| --- | --- | --- |
| Cloud OS | Debian 13.6, Linux x86_64 | Текущий runtime; прежний ARM64-ориентир PRD обновлён |
| Godot standard | `4.6.3.stable.official.7d41c59c4` | Импорт, GDScript, headless editor, экспорт; без .NET |
| Export templates | `4.6.3.stable` | Web, Linux x86_64, Windows x86_64 debug/release; точное совпадение с движком |
| GdUnit4 | `6.2.2`, commit `0127a55f4543dfc24746f6e5c7ba6f94105d51f2` | Addon подключён в проект из закреплённого архива; исключён из release |
| Playwright Test | `1.62.1` | Web E2E; установленный package-lock фиксирует transitive dependencies |
| Chromium | `154.0.8037.57`, `/usr/bin/chromium` | Системный browser, проверяется через executablePath; не bundled Chromium Playwright |
| Node / npm | `24.19.0` / `11.9.0` | Browser tooling; также удовлетворяет Node ≥22 будущего MCP |
| Python | `3.12.14` | Cloud helpers и проверка обнаружения skills; только стандартная библиотека |
| ImageMagick | `7.1.1-43` | Анализ размеров, alpha и кадров 2D-ассетов; ничего не генерируется в этой задаче |
| FFmpeg | `7.1.5-0+deb13u1` | Анализ анимации/кадров; дополнительный editor не требуется |
| Codex CLI | `0.163.0` (наблюдаемая версия) | `app-server skills/list` проверяет реальный loader; это не требование заморозить managed Codex навсегда |
| Repository skills | revision в Git | Четыре локальных навыка, без Python/npm-пакетов; отбор описан в `skills.md` |
| Godot MCP Toolkit / server | кандидат `1.1.0` / `1.1.0` | Не установлен и не активирован; совместимость и план в `godot-mcp.md` |

Машиночитаемые pins, URL и hashes — в [toolchain-lock.json](toolchain-lock.json).
Движок и шаблоны происходят из [официального релиза Godot](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable).
GdUnit4 закреплён по [v6.2.2](https://github.com/MikeSchulze/gdUnit4/tree/v6.2.2),
не по текущему master. Новые пакеты при этой настройке не установлены.

## Начало каждой задачи

```bash
cd /workspace/game2
source /workspace/.godot-cloud/env.sh
godot --version
git status --short --branch
```

`env.sh` настраивает writable XDG-каталоги, `GODOT_BIN` и PATH для Godot и
Playwright. Не наследуй ожидания о запущенном сервере из предыдущей задачи.
Templates: `/workspace/.godot-cloud/data/godot/export_templates/4.6.3.stable`.
GdUnit4 source: `/workspace/.godot-cloud/tools/gdUnit4-6.2.2/addons/gdUnit4`.
Browser lock: `/workspace/.godot-cloud/tools/browser/package-lock.json`.

Prepared environment владеет `/workspace/.godot-cloud/install.sh`, `env.sh`,
`check_project.py`, `validate.py`, `serve_web.py` и `playwright.config.cjs`.
Их снимок и hashes перечислены в lock-файле, чтобы обнаруживать изменения.
Для восстановления **этой же подготовленной базовой среды** доступно:

```bash
bash /workspace/.godot-cloud/install.sh
```

В текущей задаче переустановка не требуется. Этот скрипт проверяет базовые
версии, hashes архивов и запускает probe; он не универсален для другой ОС.
Один clone репозитория на произвольную машину не воспроизводит managed image:
нужны сохранённая Cloud-конфигурация и её подготовленные helpers.
Восстановление опубликованного snapshot подтверждено в задаче инициализации:
hashes, версии и полный infrastructure probe прошли без переустановки.
Если helpers отсутствуют, сначала восстанови окружение; не заменяй их командами
из случайного community installer. Для переноса на другой образ нужна отдельная
задача на installer/CI, с теми же pins и проверками.

## Сеть и ограничения

- `/etc/codex/network-policy.json`: version 1, HTTP policy `unrestricted`,
  VPN не настроен, TCP grants пусты. Сохраняй proxy/CA и TLS verification.
  При инициализации control plane сообщил connected/running, policy state
  `enforced`. Чтение GitHub/npm проверено фактическими
  HTTPS-запросами; секреты для этой настройки не требовались.
- Headless Godot использует dummy rendering. Скриншоты и ввод проверяются в
  Web Chromium. WebGL идёт через SwiftShader/ANGLE: функциональное покрытие,
  не оценка реальной GPU-производительности.
- Системный Chromium отличается от bundled Playwright browser. Эта пара
  проверяется E2E; после изменения любой версии повтори проверку. Подготовка
  среды зафиксировала 403 у Playwright CDN; скачивать другой browser не нужно.
- Web: Compatibility, без threads/GDExtensions. Аудио, Safari/Firefox,
  мобильный ввод и performance на устройстве игрока пока отдельно не проверены.
  Цель MVP — клавиатура. Первое включение звука требует реального user gesture
  в браузере; это нужно проверить при реализации аудио.
- Windows PE экспортируется на Linux без Wine/rcedit, resource modification
  и подписи; исполнение Windows здесь не проверяется.
- GdUnit4 headless допускает логические тесты с `--ignoreHeadlessMode`;
  это не доказательство реальной доставки InputEvents.

## Правила воспроизводимости

Меняй pins отдельным осмысленным изменением: источник → checksum/integrity →
минимальная проверка → полный pipeline. Не используй `latest` или глобальные
пакеты без lock. Для будущих browser dependencies сохраняй package-lock и
применяй `npm ci`; для Godot используй архивы и templates одной версии.

После инициализации коммить `project.godot`, `export_presets.cfg`, собственные
`.gd`/`.uid`, сцены, исходные ассеты и импортные sidecars. Сборку проверяй из
чистого output dir и заново импортированных исходников. Отчёт о сборке должен
содержать source commit, platform, tool versions, preset/options и SHA-256
выходных файлов. Проверенный workflow воспроизводим по входам и шагам;
побайтовая идентичность бинарников пока не заявляется.

Команды: [validation.md](validation.md). Последний отчёт этой настройки:
[setup-report.md](setup-report.md).
