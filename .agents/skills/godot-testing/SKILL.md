---
name: godot-testing
description: Use to choose and run targeted or final checks for this Godot 4.6.3 project, including GdUnit4 6.2.2 logic and scene suites, parser/import checks, reproducible CLI exports, and Playwright Web input or visual checks in headless Codex Cloud. Also applies to configuration-only validation before project creation.
---

# Тестирование в Cloud

Единственный runbook с командами — `docs/validation.md`; версии и ограничения —
`docs/toolchain.md`. Не вводи второй framework рядом с GdUnit4.

1. Определи стадию: без `project.godot` проверяй конфигурацию и технический
   probe среды. Не запускай game-checker на пустом репозитории и не выдавай
   инфраструктурные тесты за покрытие игры.
2. Для изменения GDScript: импорт ресурсов, `--check-only --script` для
   затронутого скрипта, затем ближайшая suite. Ошибки могут появиться в логе
   даже при exit 0; проверяй оба источника результата.
3. Логику проверяй unit-тестом; жизненный цикл, сигналы, коллизии и комнаты —
   небольшой scene suite. Используй публичный контракт, свежие fixtures,
   фиксированный RNG seed и явное освобождение узлов. Для physics жди
   `physics_frame`, для дерева — `process_frame`, с конечным timeout.
4. GdUnit4 6.2.2 находится в окружении, но addon ещё не установлен в игру.
   Его подключение относится к отдельной инициализации проекта. Командной
   строке нужен `--ignoreHeadlessMode`; аргументы runner передаются без `--`,
   каталог `-rd` задаётся относительно проекта. Прочитай свежий XML и проверь
   ненулевое число тестов, failures/errors и неожиданные skipped.
5. Для ввода/фокуса, HUD и визуальных переходов экспортируй Web и запускай
   Playwright с установленным системным Chromium. Проверяй canvas/WebGL,
   загрузку WASM, console/page errors и ожидаемую реакцию на реальные клавиши.
   Сам факт создания screenshot или HTTP 200 не подтверждает поведение.
6. Во время реализации запускай связанные suites и E2E, не весь pipeline
   после каждой правки. Перед завершением задачи выполни все применимые
   проверки из runbook. Документируй отсутствующий preset/test, не помечай
   его пройденным и не создавай фиктивный тест ради зелёного отчёта.
7. Экспорт выполняй в новый/пустой output dir, не меняя входы во время сборки.
   Запиши commit, версии, preset/options и hashes. Windows export на Linux
   не равен запуску на Windows; software WebGL не измеряет GPU-performance.
8. Если проверка падает, сначала сузь причину: свой код, ресурс, версия,
   среда или необязательный MCP. Не обновляй движок/зависимости вслепую.
   Повтори провалившуюся целевую проверку после исправления, затем полный
   применимый набор перед завершением.

Официальные источники:

- [Godot CLI](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html).
- [Web export](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html).
- [GdUnit4 v6.2.2](https://github.com/MikeSchulze/gdUnit4/tree/v6.2.2),
  [документация GdUnit4](https://mikeschulze.github.io/gdUnit4/latest/).
  Документацию `latest` сверяй с установленным runner 6.2.2.
- [Playwright CLI](https://playwright.dev/docs/test-cli),
  [browser configuration](https://playwright.dev/docs/browsers).
