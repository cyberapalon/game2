# Отчёт о настройке Codex

26 октября 2026 года · baseline `fc47decd87c30d98972de1660eab580829fa23f3`.

## Изменения

- PRD уточнён под фактические Codex Cloud / Debian x86_64 / Godot 4.6.3,
  headless workflow и Web-first MVP.
- `AGENTS.md`: архитектура сцен, типизированный GDScript, маленькие итерации,
  целевые тесты в ходе реализации, полный применимый набор перед завершением,
  фиксированные версии и сборки из чистых входов.
- Четыре repository skills: GDScript, 2D gameplay, 2D art/animation, testing.
  Инструкции опираются на официальные источники 4.6; community recipes
  рассмотрены, несовместимый animation API отброшен.
- Документированы pins, hashes, границы Cloud, команды проверок и план MCP.
  Новые зависимости, игровые сцены, механики и editor addons не добавлены.

## Выполненные проверки

| Проверка | Результат |
| --- | --- |
| `python3 tools/check_codex_skills.py` | Codex CLI 0.163.0: 4 skills, scope repo, enabled=true, errors=[] |
| Python compilation и JSON parse | Успешно |
| Markdown relative links, Bash fence syntax, TOML example | Проверены локально |
| Godot ClassDB probe 4.6.3 | `AnimatedSprite2D.advance` отсутствует; `AnimationPlayer.advance`, `set_frame_and_progress`, `CharacterBody2D.move_and_slide`, `TileMapLayer` подтверждены |
| Godot/templates/GdUnit4 archive digests | Совпали с закреплёнными SHA-512/SHA-256 |
| 9 подготовленных helpers и browser lockfiles | SHA-256 совпали с repository lock |
| MCP Toolkit ZIP / server npm tarball | SHA-256 и SHA-512 integrity совпали; пакетный код не запускался |
| `python3 /workspace/.godot-cloud/validate.py` | Полная проверка инфраструктуры успешна |
| GdUnit4 technical suites | 2 tests, 0 failures/errors/skipped |
| Release export технической сцены | Web, Linux x86_64, Windows x86_64 |
| Linux release execution | Успешный headless smoke |
| Playwright Chromium | 1 passed: WASM, WebGL2, HTTP headers, mouse click, screenshot, no console/page errors |
| `git diff --check` | Успешно |

Свидетельства: [skills discovery](verification/skills-discovery.json),
[environment results](verification/environment-results.json).
Полные логи, свежий GdUnit XML и screenshot остаются вне checkout:
`/workspace/.godot-cloud/validation/`. Эти JSON — снимок выполненной проверки,
не CI badge и не замена повторному запуску команд.

## Ограничения

Проект игры ещё отсутствует. Игровые unit/scene/E2E, клавиатурное управление
игрой и ручная оценка её отзывчивости — **не применимо** на этой стадии.
Windows runtime не запускался; software WebGL не проверяет GPU-performance.
Аудио и другие браузеры не проверялись.

Для NPGameDev Godot MCP Toolkit 1.1.0 + server 1.1.0 подтверждены входные
артефакты и заявленная upstream headless-совместимость; **end-to-end на Godot
4.6.3 / Codex Cloud не подтверждён**. Плагин не установлен ввиду отсутствия
проекта. [План](godot-mcp.md) содержит prerequisites, read-only probe,
проверку client registration, export caveat и rollback. MCP остаётся
необязательным. Восстановление Cloud snapshot в новой задаче не проверялось.
