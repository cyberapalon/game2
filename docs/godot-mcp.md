# Godot MCP Toolkit: совместимость и отложенное подключение

Исследование от 26 октября 2026 года. Проекта `project.godot` в репозитории
нет. Плагин, MCP server, `.mcp.json` и активная `.codex/config.toml` не добавлены.
CLI Godot + GdUnit4 + Playwright покрывают текущий headless workflow.

## Какой именно Toolkit

Есть разные независимые проекты с одинаковым названием:

| Проект | Архитектура и требования | Решение |
| --- | --- | --- |
| [NPGameDev/godot-mcp-toolkit](https://github.com/NPGameDev/godot-mcp-toolkit) | Asset Library addon; Node stdio bridge → localhost WebSocket editor plugin; Godot ≥4.2, Node ≥22 | Основной кандидат: Toolkit 1.1.0 + server 1.1.0 |
| [DuskHound/godot-mcp-toolkit](https://github.com/DuskHound/godot-mcp-toolkit) | README v3.2.1: Node server → spawned headless Godot operations script; Godot ≥4.4, Node ≥18 | Альтернатива изучена по README; не установлена и не проверена runtime |

Основной кандидат связан с [Godot Asset Library entry 5375](https://godotengine.org/asset-library/asset/5375).
Это community integration, не официальный MCP Godot Foundation. Не смешивай
имена npm-пакетов, addon directories и инструкции двух проектов.

Зафиксированные входы, не `latest`:

- Toolkit **1.1.0**, commit `c22ddb4be5f45c1e01b86866356935bbd8643dd9`.
  [Release ZIP](https://github.com/NPGameDev/godot-mcp-toolkit/releases/tag/v1.1.0),
  SHA-256 `3370a7ff44d61ecd5519ab44ccd866d68644c4b099de1e85e5fad913dbdd12f8`.
- `@npgamedev/godot-mcp-server` **1.1.0**, commit
  `3ac62a06a988bc1312229aa828190ed6121cb7de`.
  npm SHA-512 integrity: `sha512-QAx/BFKV8d3dO55wHw0KKdaceEv7KwlgNXWq5cyKsDxsODX7WbwFzZeLaeCt23zfjYMbtDXtIlNXfaLUqMSBaw==`.
- Node 24.19.0 уже удовлетворяет `>=22`. В пакете server runtime dependencies:
  `@modelcontextprotocol/sdk` 1.32.1, `ws` 8.21.0, `zod` 4.6.7. Их transitive
  dependencies ещё не устанавливались и не проверялись аудитом.

ZIP и npm tarball скачаны в игнорируемый `work/research/` и сверены с
GitHub release digest / npm dist integrity. Проверены безопасные archive paths,
версия в `plugin.cfg`, metadata server и отсутствие его preinstall/install/
postinstall scripts. Это проверка целостности, **не аудит безопасности всего
кода**. Никакой код скачанных пакетов не запускался, зависимости не установлены.

## Что следует из источников, а что проверено здесь

Источник автора — [compatibility guide на закреплённом commit](https://github.com/NPGameDev/godot-mcp-toolkit/blob/c22ddb4be5f45c1e01b86866356935bbd8643dd9/addons/godot_mcp_toolkit/docs/compatibility.md).
Там headless audit перечисляет Godot 4.2.0–4.7.0 **на Windows**, в том числе
**4.6.2**, но не 4.6.3 и не наш Linux Codex Cloud.

| Возможность | Вывод для Godot 4.6.3 / Cloud |
| --- | --- |
| `godot --headless --editor` + addon | Заявлено автором; 4.6.3 попадает в поддерживаемый диапазон. На этой машине MCP-связка ещё не запускалась |
| Script/resource/project tools, scene/node inspection | Заявлены работающими без дисплея; разумный кандидат для будущего read-only probe |
| `scene_close` | Нужен Godot ≥4.5; версия 4.6.3 подходит по требованию |
| `editor_screenshot`, `runtime_screenshot`, `input_simulate`, `game_start` | Без GUI не работают или возвращают `HEADLESS_UNSUPPORTED`; для игры используй CLI и Web E2E |
| Runtime state/animation/game-context execute | Требуют работающего runtime channel; не обещаем их работоспособность в текущем headless workflow |
| Reload scripts | У автора описаны headless-ограничения переинициализации узлов; проверять `script_check`, при необходимости перезапускать editor |
| Codex CLI stdio MCP | Клиент поддерживает TOML MCP config; upstream отмечает Codex recipe как documented, not yet verified |
| Инструменты в активной Codex Cloud-сессии | Наличие CLI и локального server не доказывает регистрацию инструментов у управляющего Cloud agent. Этот шаг надо проверить отдельно в поддерживаемой конфигурации клиента |

Источники: [server package](https://github.com/NPGameDev/godot-mcp-server/blob/3ac62a06a988bc1312229aa828190ed6121cb7de/package.json),
[client guide](https://github.com/NPGameDev/godot-mcp-server/blob/3ac62a06a988bc1312229aa828190ed6121cb7de/docs/mcp-clients.md),
[официальный Codex MCP](https://developers.openai.com/codex/mcp/).
Codex использует TOML, а не Claude-style `.mcp.json`; проектная конфигурация
загружается только в доверенном проекте. Не меняй глобальную конфигурацию или
trust settings автоматически. Здесь ни один MCP call к editor не выполнен.

## Проверенный по источникам план следующего шага

План применяется **после отдельной инициализации Godot-проекта**, если задача
требует MCP. Установка ещё не выполнена; весь end-to-end результат нужно будет
подтвердить на Godot 4.6.3 в данном Cloud. Если клиент Cloud не поддерживает
нужную регистрацию, останови MCP-часть, оставь CLI pipeline рабочим.

1. Убедись, что `project.godot`, main scene, импорт, GdUnit4 и Web export уже
   проходят проверки. Сначала работай в одноразовой копии проекта в `work/`
   без secrets; не испытывай редакторные мутации на единственной рабочей копии.
2. Повторно сверь закреплённый ZIP по SHA-256 из lock, проверь changelog и
   advisory выбранной версии. Распакуй только `addons/godot_mcp_toolkit` в
   disposable project. Не копируй examples, CI, чужие skills и node_modules.
   Включи addon штатным механизмом Godot; для автоматизации используй
   проверенный `EditorInterface.set_plugin_enabled`, затем импорт и parser
   checks. Изменения `project.godot` и добавленный runtime autoload проверяются
   отдельно. Плагин никогда не нужен в репозитории без проекта.
3. Server установи локально вне game checkout, например в
   `/workspace/.godot-cloud/optional/godot-mcp-1.1.0`. Создай минимальный manifest
   с **точной** dependency `@npgamedev/godot-mcp-server: 1.1.0`; сначала
   `npm install --package-lock-only --ignore-scripts`, проверь lock, package
   origins/integrity и `npm audit --omit=dev`, затем
   `npm ci --ignore-scripts --omit=dev`. Сохрани lock и checksum с отчётом.
   Не используй global install, cold `npx -y` или floating versions. При
   существенных advisory не обновляй молча — пересмотри выбранный pin.
4. Editor и MCP server должны жить в **одной VM/network namespace**, видеть
   один project path и одинаковый XDG/user-data context для token/registry.
   WebSocket слушает только `127.0.0.1`. Не открывай 0.0.0.0, tunnel или
   внешний endpoint для обхода Cloud/client ограничений.
5. Для первой проверки отключи автоматический update check настройкой
   `mcp_toolkit/updates/check_for_updates=false` и runtime channel через
   `GODOT_MCP_RUNTIME=0`. Запусти `godot --headless --editor --path <copy>`
   с логом в `work/`, сохрани PID и гарантируй остановку процесса. Это
   постоянный editor; `--quit`/`--import` завершают процесс и соединяться потом
   будет не с чем. Для обычных test runners также используй runtime=0,
   если addon подключён.
6. Начни с read-only server. Пример **будущего**, не активированного здесь
   TOML для Codex CLI; path проекта должен указывать на проверяемую копию:

   ```toml
   [mcp_servers.godot-mcp-toolkit]
   command = "node"
   args = ["/workspace/.godot-cloud/optional/godot-mcp-1.1.0/node_modules/@npgamedev/godot-mcp-server/dist/index.js"]
   startup_timeout_sec = 30

   [mcp_servers.godot-mcp-toolkit.env]
   GODOT_MCP_PROJECT_PATH = "/workspace/game2/work/mcp-project"
   GODOT_MCP_READ_ONLY = "1"
   GODOT_MCP_RUNTIME = "0"
   XDG_DATA_HOME = "/workspace/.godot-cloud/data"
   XDG_CONFIG_HOME = "/workspace/.godot-cloud/config"
   XDG_CACHE_HOME = "/workspace/.godot-cloud/cache"
   ```

   `codex mcp list` подтверждает конфигурацию, но не editor connection.
   Отдельно выполни MCP `initialize`/`tools/list` через поддерживаемый клиент,
   проверь handshake версии/auth и отсутствие mutating tools в read-only.
   При lazy tool groups используй `discover_tools`, затем повтори tools/list;
   клиент должен обработать `tools/list_changed` или переподключиться.
7. Read-only acceptance: запрос project settings возвращает именно disposable
   project; чтение script и inspection сцены дают ожидаемые данные без writes;
   editor log не содержит parser/runtime errors. Отдельно проверь ожидаемый
   отказ у GUI tool. Зафиксируй tool list, ответы, версию Godot/server/addon и
   timeout/error; токен и содержимое приватных файлов в отчёт не включай.
8. Если нужны мутации, проверяй их отдельным этапом на disposable scene:
   создать → сохранить → открыть заново → проверить diff → удалить fixture.
   Перед реальным внедрением проверь exports: автор описывает, что при
   **binary-token script export** могут остаться orphan `.gdc`. Добавь
   соответствующие addon/extension paths в exclude filter или выбери Text
   export mode; проверь фактическое содержимое PCK и отсутствие auth/config.
   Не обещай автоматическую полную очистку на основании общего README.
9. Останови editor/server, убедись в отсутствии оставшихся процессов. Удали
   disposable copy. Переноси addon/проверенную client config в настоящий проект
   только в рамках задачи на подключение. Rollback: штатно disable addon
   (для headless через EditorInterface), проверить удаление runtime autoload,
   затем удалить addon/config; не оставлять dangling autoload в export.

## Почему сейчас нет live MCP probe

Без `project.godot`, активированного addon и token/registry server не может
подтвердить editor tools. Создание проекта и подключение редакторного плагина
на этой стадии были бы преждевременны. Поэтому сейчас проверены источники,
требования, версии и целостность установочных артефактов; end-to-end тест
отложен с явными acceptance criteria. Ошибки будущего MCP не блокируют
`godot --headless`, GdUnit4 или browser tests.
